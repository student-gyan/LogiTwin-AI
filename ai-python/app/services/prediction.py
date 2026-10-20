import json
import math
from datetime import datetime, timedelta, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.schemas import DeliveryPrediction, DisruptionImpact


class PredictionService:
    def predict_delivery(self, db: Session, shipment_id: int) -> DeliveryPrediction:
        shipment = db.execute(text("""
            SELECT s.id, s.shipment_code, s.dispatch_at, s.selected_route_id,
                   r.route_name, r.normal_transit_hours + r.buffer_hours AS transit,
                   r.reliability_score
            FROM shipments s
            JOIN routes r ON r.id = s.selected_route_id
            WHERE s.id = :shipment_id
        """), {"shipment_id": shipment_id}).mappings().first()
        if not shipment:
            raise ValueError("Shipment not found")

        delay_row = db.execute(text("""
            SELECT COALESCE(SUM(delay_hours), 0) AS delay_hours
            FROM disruptions
            JOIN shipments s ON s.id = :shipment_id
            WHERE status = 'active'
              AND starts_at <= DATE_ADD(:dispatch_at, INTERVAL 30 DAY)
              AND (ends_at IS NULL OR ends_at >= :dispatch_at)
              AND (
                affected_route_id = :route_id
                OR affected_hub_id IN (s.origin_hub_id, s.destination_hub_id)
              )
        """), {
            "shipment_id": shipment_id,
            "dispatch_at": shipment["dispatch_at"],
            "route_id": shipment["selected_route_id"],
        }).mappings().one()
        delay = float(delay_row["delay_hours"] or 0)
        transit = float(shipment["transit"])
        reliability = float(shipment["reliability_score"])
        exact_delivery = shipment["dispatch_at"] + timedelta(
            hours=math.ceil(transit + delay)
        )
        confidence = max(50.0, min(99.9, reliability - delay * 0.4))
        evidence = {
            "route_transit_hours": transit,
            "active_disruption_delay_hours": delay,
            "calculation": "route transit + active disruption delay",
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }
        return DeliveryPrediction(
            shipment_id=shipment_id,
            shipment_code=shipment["shipment_code"],
            exact_delivery_at=exact_delivery,
            transit_hours=transit,
            disruption_delay_hours=delay,
            confidence_percent=round(confidence, 2),
            route_name=shipment["route_name"],
            evidence=evidence,
        )

    def disruption_impact(self, db: Session, disruption_id: int) -> DisruptionImpact:
        disruption = db.execute(text("""
            SELECT id, title, delay_hours, affected_orders
            FROM disruptions WHERE id = :id
        """), {"id": disruption_id}).mappings().first()
        if not disruption:
            raise ValueError("Disruption not found")
        impacted = db.execute(text("""
            SELECT COUNT(*) AS shipment_count,
                   GROUP_CONCAT(DISTINCT h.city ORDER BY h.city SEPARATOR ', ') AS cities
            FROM shipments s
            JOIN hubs h ON h.id = s.destination_hub_id
            WHERE s.status IN ('planned', 'in_transit', 'delayed')
              AND s.selected_route_id IN (
                SELECT affected_route_id FROM disruptions WHERE id = :id
              )
        """), {"id": disruption_id}).mappings().one()
        cities = [item for item in (impacted["cities"] or "").split(", ") if item]
        recommendation = (
            "Divert critical loads through the lowest-loss alternate route and "
            "reserve safety stock at impacted destinations."
        )
        return DisruptionImpact(
            disruption_title=disruption["title"],
            delay_hours=float(disruption["delay_hours"]),
            affected_orders=int(disruption["affected_orders"]),
            impacted_shipments=int(impacted["shipment_count"] or 0),
            estimated_delivery_delay_hours=float(disruption["delay_hours"]),
            impacted_cities=cities,
            recommendation=recommendation,
        )
