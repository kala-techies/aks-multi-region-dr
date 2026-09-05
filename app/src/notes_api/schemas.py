from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class NoteCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(default="", max_length=4000)


class NoteUpdate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(default="", max_length=4000)


class NoteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    body: str
    created_at: datetime
    updated_at: datetime
