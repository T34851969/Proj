from pydantic import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Proj"
    DEBUG: bool = False
    DATABASE_URL: str = "postgresql://postgres:postgres@db:5432/proj"
    REDIS_URL: str = "redis://redis:6379/0"
    MINIO_ENDPOINT: str = "minio:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
