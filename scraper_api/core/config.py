"""
Configuration settings for GamePrice Scraper API
"""
import os
from typing import Optional
from pydantic import BaseSettings


class Settings(BaseSettings):
    # Supabase
    supabase_url: str = os.getenv("SUPABASE_URL", "")
    supabase_service_key: str = os.getenv("SUPABASE_SERVICE_KEY", "")

    # Gemini AI
    gemini_api_key: Optional[str] = os.getenv("GEMINI_API_KEY")

    # Scraping settings
    max_concurrent_requests: int = 2  # Don't overwhelm stores
    request_timeout: int = 30  # seconds
    max_retries: int = 3

    # Rate limiting (per minute)
    steam_rate_limit: int = 20
    epic_rate_limit: int = 20

    # Cache settings
    cache_ttl_minutes: int = 60  # Cache search results for 1 hour

    # Debug mode
    debug_mode: bool = os.getenv("DEBUG_MODE", "false").lower() == "true"

    class Config:
        env_file = ".env"


settings = Settings()
