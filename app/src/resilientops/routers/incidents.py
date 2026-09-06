from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from resilientops import models, schemas
from resilientops.auth import require_api_key
from resilientops.database import get_db
from resilientops.models import utcnow

router = APIRouter(tags=["incidents"])


@router.post(
    "/services/{service_id}/incidents",
    response_model=schemas.IncidentOut,
    status_code=201,
    dependencies=[Depends(require_api_key)],
)
def create_incident(service_id: int, payload: schemas.IncidentCreate, db: Session = Depends(get_db)):
    service = db.get(models.Service, service_id)
    if service is None:
        raise HTTPException(status_code=404, detail="service not found")

    incident = models.Incident(service_id=service_id, title=payload.title, severity=payload.severity)
    db.add(incident)
    db.flush()  # assign incident.id before attaching the opening timeline entry
    db.add(
        models.IncidentUpdate(
            incident_id=incident.id,
            message=f"Incident opened: {payload.title}",
            status_at_time=incident.status,
        )
    )
    db.commit()
    db.refresh(incident)
    return incident


@router.get("/incidents", response_model=list[schemas.IncidentOut])
def list_incidents(
    status: models.IncidentStatus | None = None,
    severity: models.Severity | None = None,
    service_id: int | None = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    query = db.query(models.Incident)
    if status is not None:
        query = query.filter(models.Incident.status == status)
    if severity is not None:
        query = query.filter(models.Incident.severity == severity)
    if service_id is not None:
        query = query.filter(models.Incident.service_id == service_id)
    return query.order_by(models.Incident.id.desc()).offset(skip).limit(limit).all()


@router.get("/incidents/{incident_id}", response_model=schemas.IncidentOut)
def get_incident(incident_id: int, db: Session = Depends(get_db)):
    incident = db.get(models.Incident, incident_id)
    if incident is None:
        raise HTTPException(status_code=404, detail="incident not found")
    return incident


@router.patch(
    "/incidents/{incident_id}", response_model=schemas.IncidentOut, dependencies=[Depends(require_api_key)]
)
def patch_incident(incident_id: int, payload: schemas.IncidentPatch, db: Session = Depends(get_db)):
    incident = db.get(models.Incident, incident_id)
    if incident is None:
        raise HTTPException(status_code=404, detail="incident not found")

    if payload.severity is not None:
        incident.severity = payload.severity

    if payload.status is not None and payload.status != incident.status:
        incident.status = payload.status
        if payload.status == models.IncidentStatus.resolved:
            incident.resolved_at = utcnow()
        db.add(
            models.IncidentUpdate(
                incident_id=incident.id,
                message=f"Status changed to {payload.status.value}",
                status_at_time=payload.status,
            )
        )

    db.commit()
    db.refresh(incident)
    return incident


@router.post(
    "/incidents/{incident_id}/updates",
    response_model=schemas.IncidentUpdateOut,
    status_code=201,
    dependencies=[Depends(require_api_key)],
)
def add_incident_update(incident_id: int, payload: schemas.IncidentUpdateCreate, db: Session = Depends(get_db)):
    incident = db.get(models.Incident, incident_id)
    if incident is None:
        raise HTTPException(status_code=404, detail="incident not found")

    update = models.IncidentUpdate(
        incident_id=incident_id, message=payload.message, status_at_time=incident.status
    )
    db.add(update)
    db.commit()
    db.refresh(update)
    return update


@router.get("/incidents/{incident_id}/updates", response_model=list[schemas.IncidentUpdateOut])
def list_incident_updates(incident_id: int, db: Session = Depends(get_db)):
    incident = db.get(models.Incident, incident_id)
    if incident is None:
        raise HTTPException(status_code=404, detail="incident not found")
    return incident.updates
