#!/usr/bin/env python3
"""REDI LAB — Landing page + infrastructure status API."""
from __future__ import annotations

import asyncio
import json
import socket
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

CONFIG_DIR = Path("/app/config")
STATIC_DIR = Path("/app/static")

app = FastAPI(title="REDI LAB Status", version="1.0.0")
app.mount("/assets", StaticFiles(directory=STATIC_DIR / "assets"), name="assets")


def _load_json(name: str) -> dict[str, Any]:
    path = CONFIG_DIR / name
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


async def _tcp_check(host: str, port: int, timeout: float) -> tuple[bool, str | None]:
    try:
        conn = asyncio.wait_for(
            asyncio.open_connection(host, port),
            timeout=timeout,
        )
        reader, writer = await conn
        writer.close()
        await writer.wait_closed()
        return True, None
    except Exception as exc:  # noqa: BLE001
        return False, str(exc)


async def _run_check(check: dict[str, Any]) -> dict[str, Any]:
    host = check["host"]
    port = int(check["port"])
    timeout = float(check.get("timeout", 5))
    ok, err = await _tcp_check(host, port, timeout)
    return {
        "name": check["name"],
        "target": f"{host}:{port}",
        "ok": ok,
        "error": err,
    }


async def _probe_node(node: dict[str, Any]) -> dict[str, Any]:
    checks = await asyncio.gather(*[_run_check(c) for c in node.get("checks", [])])
    passed = sum(1 for c in checks if c["ok"])
    total = len(checks)
    if total == 0:
        state = "unknown"
    elif passed == total:
        state = "up"
    elif passed == 0:
        state = "down"
    else:
        state = "degraded"
    return {
        "id": node["id"],
        "role": node["role"],
        "location": node.get("location"),
        "mesh_ip": node.get("mesh_ip"),
        "public_ip": node.get("public_ip"),
        "state": state,
        "checks": checks,
        "summary": f"{passed}/{total} checks passed",
    }


def _failover_view(failover_cfg: dict[str, Any], nodes_by_id: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for key, group in failover_cfg.items():
        primary = group["primary"]
        secondary = group.get("secondary")
        primary_node = nodes_by_id.get(primary["node"], {})
        secondary_node = nodes_by_id.get(secondary["node"], {}) if secondary else None

        primary_up = primary_node.get("state") in ("up", "degraded")
        secondary_up = secondary_node and secondary_node.get("state") in ("up", "degraded")

        if primary_up:
            active = primary["node"]
            active_label = "Primary"
            standby = secondary["node"] if secondary else None
        elif secondary_up and secondary:
            active = secondary["node"]
            active_label = "Failover"
            standby = primary["node"]
        else:
            active = None
            active_label = "Unavailable"
            standby = None

        rows.append({
            "id": key,
            "label": group["label"],
            "primary": primary,
            "secondary": secondary,
            "active_node": active,
            "active_label": active_label,
            "standby_node": standby,
            "primary_state": primary_node.get("state", "unknown"),
            "secondary_state": secondary_node.get("state") if secondary_node else None,
        })
    return rows


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/status")
async def status() -> dict[str, Any]:
    started = time.perf_counter()
    nodes_cfg = _load_json("nodes.json")
    services_cfg = _load_json("services.json")

    probed = await asyncio.gather(*[_probe_node(n) for n in nodes_cfg["nodes"]])
    nodes_by_id = {n["id"]: n for n in probed}
    failover = _failover_view(nodes_cfg["failover"], nodes_by_id)

    up = sum(1 for n in probed if n["state"] == "up")
    degraded = sum(1 for n in probed if n["state"] == "degraded")
    down = sum(1 for n in probed if n["state"] == "down")

    if down == len(probed):
        overall = "critical"
    elif down > 0 or degraded > 0:
        overall = "degraded"
    else:
        overall = "healthy"

    elapsed_ms = round((time.perf_counter() - started) * 1000, 1)

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "probe_ms": elapsed_ms,
        "overall": overall,
        "summary": {"up": up, "degraded": degraded, "down": down, "total": len(probed)},
        "nodes": probed,
        "failover": failover,
        "services": services_cfg,
        "hostname": socket.gethostname(),
    }


@app.get("/api/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
