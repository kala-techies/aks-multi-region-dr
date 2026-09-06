from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration, sourced entirely from environment variables.

    DATABASE_URL defaults to a local SQLite file so the app runs with zero
    setup outside a container; real deployments set it via a Kubernetes
    Secret / Container Instance secure env var to a PostgreSQL DSN.
    """

    model_config = SettingsConfigDict(env_prefix="", extra="ignore")

    database_url: str = "sqlite:///./resilientops.db"
    app_name: str = "resilientops"
    region: str = "unspecified"

    # Shared-secret auth for write endpoints. The default is intentionally
    # an obvious placeholder - real deployments MUST override this via an
    # env var sourced from a Secret, never a committed value.
    api_key: str = "dev-local-only-change-me"

    # Comma-separated list of origins the browser-based frontend tier is
    # served from. "*" (the default) is a POC convenience - see docs/security.md.
    allowed_origins: str = "*"


settings = Settings()
