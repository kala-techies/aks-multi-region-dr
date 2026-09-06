from fastapi import Header, HTTPException, status

from resilientops.config import settings


def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
    """Shared-secret gate for write endpoints. Read endpoints stay public,
    same as a real status page (anyone can view incidents; only the
    operations team can open/update one)."""
    if x_api_key != settings.api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid or missing API key")
