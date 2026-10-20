from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.schemas import (
    DeliveryPrediction,
    ForecastPoint,
    RoutePlan,
    RoutePlanRequest,
)
from app.services.forecasting import DemandForecastService
from app.services.prediction import PredictionService
from app.services.routing import RouteOptimizationService


app = FastAPI(
    title="Logi Twin AI",
    description="AI services for supply chain optimization",
    version="1.0.0",
)

route_service = RouteOptimizationService()
forecast_service = DemandForecastService()
prediction_service = PredictionService()

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {
        "message": "Logi Twin AI Python AI Service is running",
        "status": "online",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "python-ai",
    }


@app.post("/api/ai/routes/optimize", response_model=RoutePlan)
def optimize_route(request: RoutePlanRequest):
    try:
        return route_service.optimize(request)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@app.get("/api/ai/forecast", response_model=list[ForecastPoint])
def forecast(
    sku: str = Query(min_length=1),
    horizon_days: int = Query(default=14, ge=1, le=90),
    db: Session = Depends(get_db),
):
    try:
        return forecast_service.forecast(db, sku, horizon_days)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Forecast service failed") from exc


@app.get("/api/ai/delivery/{shipment_id}", response_model=DeliveryPrediction)
def predict_delivery(shipment_id: int, db: Session = Depends(get_db)):
    try:
        return prediction_service.predict_delivery(db, shipment_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Prediction service failed") from exc
