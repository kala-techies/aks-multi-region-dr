from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from resilientops.models import IncidentStatus, Severity


class ServiceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str = Field(default="", max_length=500)
    owner_team: str = Field(default="", max_length=120)


class ServiceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    owner_team: str
    created_at: datetime


class IncidentCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    severity: Severity = Severity.medium


class IncidentPatch(BaseModel):
    status: IncidentStatus | None = None
    severity: Severity | None = None


class IncidentUpdateCreate(BaseModel):
    message: str = Field(min_length=1, max_length=2000)


class IncidentUpdateOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    message: str
    status_at_time: IncidentStatus
    created_at: datetime


class IncidentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    service_id: int
    title: str
    severity: Severity
    status: IncidentStatus
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None
    updates: list[IncidentUpdateOut] = []


class StatusSummary(BaseModel):
    overall: str
    region: str
    open_incidents: int
    services_count: int
