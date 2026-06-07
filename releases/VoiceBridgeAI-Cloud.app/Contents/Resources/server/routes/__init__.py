"""HTTP and WebSocket route registration."""

from __future__ import annotations

from fastapi import FastAPI

from routes import cloud, engine, health, models_local, ws


def register_routes(app: FastAPI) -> None:
    app.include_router(health.router)
    app.include_router(models_local.router)
    app.include_router(cloud.router)
    app.include_router(engine.router)
    app.include_router(ws.router)
