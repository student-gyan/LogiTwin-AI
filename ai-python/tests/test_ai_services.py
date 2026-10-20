from app.core.config import Settings
from app.schemas import RoutePlanRequest, RouteStop
from app.services.routing import RouteOptimizationService


def test_route_optimizer_prioritizes_critical_stops_within_capacity():
    request = RoutePlanRequest(
        vehicle_capacity=100,
        start_latitude=19.076,
        start_longitude=72.8777,
        stops=[
            RouteStop(
                shipment_code="STD-1", city="Pune", latitude=18.5204,
                longitude=73.8567, units=60, priority="standard"
            ),
            RouteStop(
                shipment_code="CRIT-1", city="Nashik", latitude=20.011,
                longitude=73.79, units=40, priority="critical"
            ),
        ],
    )
    result = RouteOptimizationService().optimize(request)
    assert result.total_units == 100
    assert result.ordered_stops[0].shipment_code == "CRIT-1"
    assert result.capacity_used_percent == 100.0


def test_settings_split_cors_origins():
    settings = Settings(cors_origins="http://one,http://two")
    assert settings.cors_origin_list == ["http://one", "http://two"]
