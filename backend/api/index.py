"""Vercel function entrypoint.

Vercel's Python runtime looks for ``api/index.py`` and serves the ASGI
callable it finds there. ``vercel.json`` rewrites every path to this one
function; FastAPI does its own routing inside.

Nothing else should import this module — local runs use ``app.main:app``.
"""

from app.main import app

__all__ = ["app"]
