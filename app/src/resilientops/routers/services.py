from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from resilientops import models, schemas
from resilientops.auth import require_api_key
from resilientops.database import get_db

router = APIRouter(prefix="/services", tags=["services"])


@router.post("", response_model=schemas.ServiceOut, status_code=201, dependencies=[Depends(require_api_key)])
def create_service(payload: schemas.ServiceCreate, db: Session = Depends(get_db)):
    if db.query(models.Service).filter_by(name=payload.name).first():
        raise HTTPException(status_code=409, detail="a service with this name already exists")
    service = models.Service(**payload.model_dump())
    db.add(service)
    db.commit()
    db.refresh(service)
    return service


@router.get("", response_model=list[schemas.ServiceOut])
def list_services(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    return db.query(models.Service).order_by(models.Service.id).offset(skip).limit(limit).all()


@router.get("/{service_id}", response_model=schemas.ServiceOut)
def get_service(service_id: int, db: Session = Depends(get_db)):
    service = db.get(models.Service, service_id)
    if service is None:
        raise HTTPException(status_code=404, detail="service not found")
    return service
