from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from resilientops.config import settings
from resilientops.database import Base, engine
from resilientops.metrics import MetricsMiddleware
from resilientops.routers import incidents, meta, services


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="ResilientOps",
    description=(
        "Service health & incident tracker - the internal API behind a "
        "public status page. Deployed multi-region as this project's DR "
        "demo workload."
    ),
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(MetricsMiddleware)

_origins = [o.strip() for o in settings.allowed_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(meta.router)
app.include_router(services.router)
app.include_router(incidents.router)


@app.get("/", include_in_schema=False)
def root() -> dict:
    return {"service": settings.app_name, "region": settings.region, "docs": "/docs"}
