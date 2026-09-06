from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from resilientops import models, schemas
from resilientops.config import settings
from resilientops.database import check_db_connection, get_db
from resilientops.metrics import render_metrics

router = APIRouter(tags=["meta"])


@router.get("/healthz")
def healthz() -> dict:
    """Liveness probe: process is up. Must not depend on the database."""
    return {"status": "ok", "region": settings.region}


@router.get("/readyz")
def readyz() -> dict:
    """Readiness probe: process can actually serve requests (DB reachable)."""
    if not check_db_connection():
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ready", "region": settings.region}


@router.get("/status", response_model=schemas.StatusSummary)
def status_summary(db: Session = Depends(get_db)):
    """Public, derived system-health summary - the same idea as the banner
    on a real status page (statuspage.io-style), computed from open
    incidents rather than hand-maintained."""
    open_incidents = (
        db.query(models.Incident).filter(models.Incident.status != models.IncidentStatus.resolved).all()
    )
    services_count = db.query(models.Service).count()

    if not open_incidents:
        overall = "operational"
    elif any(i.severity == models.Severity.critical for i in open_incidents):
        overall = "major_outage"
    elif any(i.severity == models.Severity.high for i in open_incidents):
        overall = "partial_outage"
    else:
        overall = "degraded_performance"

    return schemas.StatusSummary(
        overall=overall,
        region=settings.region,
        open_incidents=len(open_incidents),
        services_count=services_count,
    )


@router.get("/metrics")
def metrics():
    from prometheus_client import CONTENT_TYPE_LATEST

    return Response(content=render_metrics(), media_type=CONTENT_TYPE_LATEST)
