"""Configuration for AI Service."""

import os
from typing import List


class Settings:
    """AI Service settings."""
    
    # Service
    service_name: str = "ai-service"
    service_version: str = "1.0.0"
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    # Server
    host: str = os.getenv("HOST", "0.0.0.0")
    port: int = int(os.getenv("PORT", "8011"))
    
    # CORS
    cors_origins: str = os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8001")
    cors_allow_credentials: bool = True
    
    # Groq API (replaces Gemini)
    groq_api_key: str = os.getenv("GROQ_API_KEY", "")
    groq_model: str = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
    
    def get_cors_origins(self) -> List[str]:
        """Parse CORS origins from comma-separated string."""
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()
