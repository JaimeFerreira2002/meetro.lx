"""Configuration via environment variables (or a .env file next to server/)."""

from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="ML_", env_file=".env", extra="ignore")

    base_url: str = "https://api.metrolisboa.pt:8243/estadoServicoML/1.0.1"
    token_url: str = "https://api.metrolisboa.pt:8243/token"

    # Credentials — same options as the spike. Prefer the pre-encoded Basic blob.
    basic_auth: str = ""       # ML_BASIC_AUTH = base64(consumerKey:consumerSecret)
    consumer_key: str = ""     # ML_CONSUMER_KEY
    consumer_secret: str = ""  # ML_CONSUMER_SECRET
    access_token: str = ""     # ML_ACCESS_TOKEN (static; expires ~1h)

    # The gateway cert is valid but some trust stores lack the issuer; see spike notes.
    insecure_tls: bool = True

    lines: tuple[str, ...] = ("Amarela", "Azul", "Verde", "Vermelha")
    poll_interval_seconds: float = 12.0
    stream_interval_seconds: float = 1.5

    # Default segment travel time (s) before one is learned from the feed.
    default_segment_seconds: float = 100.0


settings = Settings()
