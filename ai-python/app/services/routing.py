import math

from app.schemas import RoutePlan, RoutePlanRequest, RouteStop


class RouteOptimizationService:
    """Transparent priority-aware nearest-neighbor route planner."""

    def optimize(self, request: RoutePlanRequest) -> RoutePlan:
        remaining = list(request.stops)
        ordered: list[RouteStop] = []
        total_units = 0
        current_lat = request.start_latitude
        current_lon = request.start_longitude
        total_distance = 0.0

        while remaining:
            feasible = [
                stop for stop in remaining
                if total_units + stop.units <= request.vehicle_capacity
            ]
            if not feasible:
                break
            feasible.sort(key=lambda stop: (
                0 if stop.priority == "critical" else 1 if stop.priority == "high" else 2,
                self.distance(current_lat, current_lon, stop.latitude, stop.longitude),
            ))
            next_stop = feasible[0]
            total_distance += self.distance(
                current_lat, current_lon, next_stop.latitude, next_stop.longitude
            )
            ordered.append(next_stop)
            remaining.remove(next_stop)
            total_units += next_stop.units
            current_lat = next_stop.latitude
            current_lon = next_stop.longitude

        return RoutePlan(
            ordered_stops=ordered,
            unassigned_stops=remaining,
            total_distance_km=round(total_distance, 2),
            total_units=total_units,
            capacity_used_percent=round(total_units / request.vehicle_capacity * 100, 2),
            optimization_method="priority-aware nearest feasible stop",
        )

    @staticmethod
    def distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        radius = 6371.0
        d_lat = math.radians(lat2 - lat1)
        d_lon = math.radians(lon2 - lon1)
        value = (
            math.sin(d_lat / 2) ** 2
            + math.cos(math.radians(lat1))
            * math.cos(math.radians(lat2))
            * math.sin(d_lon / 2) ** 2
        )
        return radius * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value))
