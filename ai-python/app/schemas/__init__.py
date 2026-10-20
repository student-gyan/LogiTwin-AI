from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field


Priority = Literal["standard", "high", "critical"]


class RouteStop(BaseModel):
    shipment_code: str = Field(min_length=1, max_length=40)
    city: str = Field(min_length=1, max_length=100)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    units: int = Field(gt=0)
    priority: Priority = "standard"


class RoutePlanRequest(BaseModel):
    vehicle_capacity: int = Field(gt=0)
    start_latitude: float = Field(ge=-90, le=90)
    start_longitude: float = Field(ge=-180, le=180)
    stops: list[RouteStop] = Field(min_length=1)


class RoutePlan(BaseModel):
    ordered_stops: list[RouteStop]
    unassigned_stops: list[RouteStop]
    total_distance_km: float
    total_units: int
    capacity_used_percent: float
    optimization_method: str


class ForecastPoint(BaseModel):
    sku: str
    item_name: str
    city: str
    forecast_date: date
    predicted_units: float
    lower_bound_units: float
    upper_bound_units: float
    confidence_percent: float
    model: str


class DeliveryPrediction(BaseModel):
    shipment_id: int
    shipment_code: str
    exact_delivery_at: datetime
    transit_hours: float
    disruption_delay_hours: float
    confidence_percent: float
    route_name: str
    evidence: dict


class DisruptionImpact(BaseModel):
    disruption_title: str
    delay_hours: float
    affected_orders: int
    impacted_shipments: int
    estimated_delivery_delay_hours: float
    impacted_cities: list[str]
    recommendation: str
