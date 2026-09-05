from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.orm import Session

from notes_api import models, schemas
from notes_api.config import settings
from notes_api.database import Base, check_db_connection, engine, get_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title=settings.app_name, lifespan=lifespan)


@app.get("/healthz")
def healthz() -> dict:
    """Liveness probe: process is up. Must not depend on the database."""
    return {"status": "ok", "region": settings.region}


@app.get("/readyz")
def readyz() -> dict:
    """Readiness probe: process can actually serve requests (DB reachable)."""
    if not check_db_connection():
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ready", "region": settings.region}


@app.post("/notes", response_model=schemas.NoteOut, status_code=201)
def create_note(note: schemas.NoteCreate, db: Session = Depends(get_db)):
    db_note = models.Note(title=note.title, body=note.body)
    db.add(db_note)
    db.commit()
    db.refresh(db_note)
    return db_note


@app.get("/notes", response_model=list[schemas.NoteOut])
def list_notes(db: Session = Depends(get_db)):
    return db.query(models.Note).order_by(models.Note.id).all()


@app.get("/notes/{note_id}", response_model=schemas.NoteOut)
def get_note(note_id: int, db: Session = Depends(get_db)):
    note = db.get(models.Note, note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="note not found")
    return note


@app.put("/notes/{note_id}", response_model=schemas.NoteOut)
def update_note(note_id: int, payload: schemas.NoteUpdate, db: Session = Depends(get_db)):
    note = db.get(models.Note, note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="note not found")
    note.title = payload.title
    note.body = payload.body
    db.commit()
    db.refresh(note)
    return note


@app.delete("/notes/{note_id}", status_code=204)
def delete_note(note_id: int, db: Session = Depends(get_db)):
    note = db.get(models.Note, note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="note not found")
    db.delete(note)
    db.commit()
    return None
