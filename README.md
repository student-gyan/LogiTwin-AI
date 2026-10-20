# LogiTwin-AI

A supply-chain digital-twin project with a Spring Boot API, MySQL database, static web UI, and Python AI services.

## Included services

- `backend-java/`: Spring Boot 3.3 / Java 21 API and frontend served from `/`
- `database/`: MySQL 8 schema, views, seed data, prediction procedure, and audit trigger
- `frontend/`: static frontend source for local development
- `ai-python/`: FastAPI route optimization, demand forecasting, and delivery prediction

## Fastest local start with Docker

Requirements: Docker Desktop or Docker Engine with Compose.

```bash
cp .env.example .env
# Edit .env and set real values for MYSQL_ROOT_PASSWORD and JWT_SECRET
docker compose up --build
```

Open <http://localhost:8080/login.html>.

The database is initialized automatically the first time the MySQL volume is created. To reset the demo database completely:

```bash
docker compose down -v
docker compose up --build
```

The destructive SQL reset is intended for development only. Use migrations for production data.

## Demo accounts

The seed SQL creates demo accounts with password `demo`:

| Role | Email |
|---|---|
| Admin | `admin@northstar.example` |
| Manager | `manager@northstar.example` |
| Delivery Driver | `driver@northstar.example` |

Change these accounts and passwords before deployment. The demo-password fallback exists only for seeded development accounts whose `password_hash` is intentionally `NULL`.

## Run without Docker

### Database

Install MySQL 8.0+ and run:

```bash
mysql -u root -p < database/logi_twin_complete.sql
```

Set the backend environment variables:

```bash
export DB_URL='jdbc:mysql://localhost:3306/logi_twin_ai?serverTimezone=UTC&useSSL=false&allowPublicKeyRetrieval=true'
export DB_USER='root'
export DB_PASSWORD='your-password'
export JWT_SECRET='a-random-secret-at-least-32-characters-long'
export CORS_ORIGINS='http://localhost:8080,http://localhost:5500'
```

### Spring Boot backend

Requirements: Java 21 and Maven 3.9+.

```bash
cd backend-java
mvn test
mvn spring-boot:run
```

The UI and API are served from `http://localhost:8080`. Health endpoints:

- `GET /api/health`
- `GET /actuator/health`

### Static frontend only

```bash
cd frontend
python3 -m http.server 5500
```

Set `CORS_ORIGINS=http://localhost:5500,http://localhost:8080` in the backend environment.

### Python AI service

```bash
cd ai-python
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
export DATABASE_URL='mysql+pymysql://root:your-password@localhost:3306/logi_twin_ai'
uvicorn app.main:app --reload --port 8000
```

Endpoints:

- `GET /health`
- `POST /api/ai/routes/optimize`
- `GET /api/ai/forecast?sku=SKU-001&horizon_days=14`
- `GET /api/ai/delivery/{shipment_id}`

## Java API endpoints

- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/dashboard/summary`
- `GET /api/shipments/priority`
- `GET /api/shipments/{shipmentCode}`
- `GET /api/inventory/health`
- `POST /api/delivery/predict`
- `POST /api/disruptions` (admin or manager only)
- `GET /api/health`

All endpoints except authentication, static files, and health checks require a JWT. The frontend automatically attaches the JWT after login and redirects to the login page when the token expires.

## Important implementation notes

- The active-shipment SQL view exposes `origin_city` and `destination_city`, matching the Java DTO query.
- Java delivery prediction filters disruptions by selected route or shipment origin/destination hubs, matching the Python implementation and stored procedure.
- Route optimization returns both `ordered_stops` and `unassigned_stops`; it never silently drops capacity-overflow stops.
- CORS is read from `CORS_ORIGINS`; wildcard origins are not enabled.
- Secrets are environment variables and are not committed.
- The frontend is served from Spring Boot static resources and is also retained as a standalone `frontend/` directory.

## Tests and checks

```bash
cd backend-java && mvn test
cd ../ai-python && pytest -q
cd ../frontend && for file in js/*.js; do node --check "$file"; done
```

For a release check, run the full Docker stack, log in through the browser, load the dashboard, inventory page, and delivery prediction page, and verify the API responses against the MySQL data.
