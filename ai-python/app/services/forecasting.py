from datetime import date, timedelta

import numpy as np
import pandas as pd
from sqlalchemy import text
from sqlalchemy.orm import Session
from sklearn.ensemble import RandomForestRegressor

from app.schemas import ForecastPoint


class DemandForecastService:
    """Forecasts daily SKU demand from stored historical movement records.

    The model uses lag demand and rolling averages. With fewer than 8 records,
    it uses the current average demand as a safe baseline instead of pretending
    that a complex model has enough evidence.
    """

    def forecast(self, db: Session, sku: str, horizon_days: int) -> list[ForecastPoint]:
        rows = db.execute(text("""
            SELECT DATE(im.movement_at) AS demand_date,
                   SUM(ABS(im.quantity)) AS units,
                   i.item_name, h.city
            FROM inventory_movements im
            JOIN inventory_items i ON i.id = im.inventory_item_id
            JOIN hubs h ON h.id = i.hub_id
            WHERE i.sku = :sku
              AND im.movement_type IN ('allocation', 'dispatch')
            GROUP BY DATE(im.movement_at), i.item_name, h.city
            ORDER BY demand_date
        """), {"sku": sku}).mappings().all()
        if not rows:
            raise ValueError(f"No movement history found for SKU {sku}")

        frame = pd.DataFrame(rows)
        frame["demand_date"] = pd.to_datetime(frame["demand_date"])
        frame["units"] = frame["units"].astype(float)
        average = float(frame["units"].mean())
        model_name = "rolling-baseline"

        model = None
        history = frame["units"].tolist()
        if len(frame) >= 8:
            frame["lag_1"] = frame["units"].shift(1)
            frame["lag_7"] = frame["units"].shift(7)
            frame["rolling_7"] = frame["units"].rolling(7).mean()
            training = frame.dropna()
            model = RandomForestRegressor(
                n_estimators=80, random_state=42, min_samples_leaf=2
            )
            model.fit(training[["lag_1", "lag_7", "rolling_7"]], training["units"])
            average = float(training["units"].tail(7).mean())
            model_name = "random-forest-lag-features"

        last_date = frame["demand_date"].max().date()
        recent_std = float(frame["units"].tail(14).std() or 0)
        points: list[ForecastPoint] = []
        for step in range(1, horizon_days + 1):
            if model is None:
                predicted = max(0.0, average)
            else:
                lag_1 = history[-1]
                lag_7 = history[-7] if len(history) >= 7 else average
                rolling_7 = float(np.mean(history[-7:]))
                predicted = max(0.0, float(model.predict([[lag_1, lag_7, rolling_7]])[0]))
            history.append(predicted)
            spread = max(recent_std * 1.28, predicted * 0.12)
            points.append(ForecastPoint(
                sku=sku,
                item_name=str(frame.iloc[-1]["item_name"]),
                city=str(frame.iloc[-1]["city"]),
                forecast_date=last_date + timedelta(days=step),
                predicted_units=round(predicted, 2),
                lower_bound_units=round(max(0, predicted - spread), 2),
                upper_bound_units=round(predicted + spread, 2),
                confidence_percent=round(
                    float(np.clip(100 - recent_std / max(average, 1) * 30, 55, 96)), 2
                ),
                model=model_name,
            ))
        return points
