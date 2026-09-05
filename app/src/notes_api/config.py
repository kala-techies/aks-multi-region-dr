from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration, sourced entirely from environment variables.

    DATABASE_URL defaults to a local SQLite file so the app runs with zero
    setup outside a container; production/POC deployments must set it to the
    PostgreSQL Flexible Server connection string via a Kubernetes Secret.
    """

    model_config = SettingsConfigDict(env_prefix="", extra="ignore")

    database_url: str = "sqlite:///./notes.db"
    app_name: str = "notes-api"
    region: str = "unspecified"


settings = Settings()
