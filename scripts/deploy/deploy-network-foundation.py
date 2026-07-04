#!/usr/bin/env python3
"""RAS v1.0 Stage 1.1 — Tailscale network foundation (LEVEL 1)."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

try:
    import yaml
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "pyyaml"])
    import yaml

REPO = Path(__file__).resolve().parents[2]
INVENTORY = REPO / "inventory" / "servers.example.yaml"
SECRETS_SRV = REPO / "secrets" / "servers.yaml"
SECRETS_KEYS = REPO / "secrets" / "api-keys.yaml"
REDI_REMOTE = "/opt/redi"


def load_yaml(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def secret_value(keys: dict, secret_id: str) -> str:
    for item in keys.get("secrets", []):
        if item.get("id") == secret_id:
            val = item.get("value")
            return "" if val is None else str(val)
    return ""


def tailscale_auth_key(keys: dict) -> str:
    env = os.environ.get("TAILSCALE_AUTH_KEY", "").strip()
    if env and "REPLACE" not in env:
        return env
    val = secret_value(keys, "tailscale-auth-key")
    if val and val.lower() not in ("null", "none", ""):
        return val
    return ""


def ssh_cmd(host: str, port: int, user: str, password: str, remote: str, timeout: int = 120) -> tuple[bool, str]:
    cmd = [
        "sshpass", "-e", "ssh",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=20",
        "-p", str(port),
        f"{user}@{host}",
        remote,
    ]
    env = {**os.environ, "SSHPASS": password}
    proc = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=timeout)
    out = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode == 0, out.strip()


def rsync_repo(host: str, port: int, user: str, password: str) -> tuple[bool, str]:
    ssh_part = f"sshpass -e ssh -o StrictHostKeyChecking=accept-new -p {port}"
    staging = f"/tmp/redi-sync-{int(time.time())}"
    env = {**os.environ, "SSHPASS": password}
    sync = subprocess.run(
        [
            "rsync", "-az", "--delete",
            "--exclude", ".git",
            "--exclude", "secrets/",
            "--exclude", "inventory/servers.env",
            "-e", ssh_part,
            f"{REPO}/",
            f"{user}@{host}:{staging}/",
        ],
        capture_output=True,
        text=True,
        env=env,
        timeout=300,
    )
    if sync.returncode != 0:
        return False, (sync.stdout or "") + (sync.stderr or "")

    if user == "root":
        install = f"mkdir -p {REDI_REMOTE} && rsync -a {staging}/ {REDI_REMOTE}/ && rm -rf {staging}"
    else:
        install = (
            f"echo '{password}' | sudo -S mkdir -p {REDI_REMOTE} && "
            f"echo '{password}' | sudo -S rsync -a {staging}/ {REDI_REMOTE}/ && "
            f"rm -rf {staging}"
        )
    return ssh_cmd(host, port, user, password, install, timeout=180)


def ensure_userspace_if_needed(host: str, port: int, user: str, password: str) -> tuple[bool, str]:
    """Enable userspace networking when /dev/net/tun is unavailable (Proxmox LXC)."""
    check = "test -c /dev/net/tun && echo HAS_TUN || echo NO_TUN"
    if user != "root":
        check = f"echo '{password}' | sudo -S bash -c \"{check}\""
    ok, out = ssh_cmd(host, port, user, password, check, timeout=30)
    if "NO_TUN" not in out:
        return True, "kernel TUN available"

    remote = (
        "mkdir -p /etc/systemd/system/tailscaled.service.d && "
        "cat > /etc/systemd/system/tailscaled.service.d/userspace.conf <<'EOF'\n"
        "[Service]\nExecStart=\n"
        "ExecStart=/usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state "
        "--socket=/run/tailscale/tailscaled.sock --port=41641 --tun=userspace-networking\n"
        "EOF\n"
        "systemctl daemon-reload && systemctl restart tailscaled && sleep 3 && systemctl is-active tailscaled"
    )
    if user != "root":
        remote = f"echo '{password}' | sudo -S bash -c '{remote}'"
    return ssh_cmd(host, port, user, password, remote, timeout=120)


def ensure_tailscale_installed(host: str, port: int, user: str, password: str) -> tuple[bool, str]:
    if user == "root":
        remote = (
            "if command -v tailscale >/dev/null; then "
            "echo ALREADY_INSTALLED; "
            "else curl -fsSL https://tailscale.com/install.sh | sh; fi && "
            "systemctl enable tailscaled && systemctl start tailscaled && "
            "systemctl is-active tailscaled"
        )
    else:
        remote = (
            f"echo '{password}' | sudo -S bash -c '"
            "if command -v tailscale >/dev/null; then echo ALREADY_INSTALLED; "
            "else curl -fsSL https://tailscale.com/install.sh | sh; fi && "
            "systemctl enable tailscaled && systemctl start tailscaled && "
            "systemctl is-active tailscaled'"
        )
    return ssh_cmd(host, port, user, password, remote, timeout=300)


def join_mesh(host: str, port: int, user: str, password: str, auth_key: str, hostname: str) -> tuple[bool, str]:
    # Match configure-tailscale.sh behaviour; do not alter public networking.
    up = (
        f"tailscale up --authkey='{auth_key}' --hostname='{hostname}' "
        "--accept-routes --accept-dns=false --ssh --reset"
    )
    if user == "root":
        remote = f"{up} && tailscale ip -4 && tailscale status"
    else:
        remote = f"echo '{password}' | sudo -S bash -c \"{up} && tailscale ip -4 && tailscale status\""
    return ssh_cmd(host, port, user, password, remote, timeout=180)


def query_tailscale(host: str, port: int, user: str, password: str) -> dict:
    remote = (
        "H=$(hostname -s); "
        "TS_VER=$(tailscale version 2>/dev/null | head -1 || echo NOT_INSTALLED); "
        "TS_IP=$(tailscale ip -4 2>/dev/null || echo ''); "
        "TS_STATUS=$(tailscale status --json 2>/dev/null || echo '{}'); "
        "TD=$(systemctl is-active tailscaled 2>/dev/null || echo inactive); "
        "echo \"HOSTNAME=$H\"; echo \"TS_VER=$TS_VER\"; echo \"TS_IP=$TS_IP\"; "
        "echo \"TAILSCALED=$TD\"; echo \"TS_JSON=$TS_STATUS\""
    )
    if user != "root":
        remote = f"echo '{password}' | sudo -S bash -c '{remote}'"
    ok, out = ssh_cmd(host, port, user, password, remote, timeout=60)
    data = {"ok": ok, "raw": out, "hostname": "", "version": "", "ip": "", "tailscaled": "", "json": {}}
    for line in out.splitlines():
        if line.startswith("HOSTNAME="):
            data["hostname"] = line.split("=", 1)[1]
        elif line.startswith("TS_VER="):
            data["version"] = line.split("=", 1)[1]
        elif line.startswith("TS_IP="):
            data["ip"] = line.split("=", 1)[1]
        elif line.startswith("TAILSCALED="):
            data["tailscaled"] = line.split("=", 1)[1]
        elif line.startswith("TS_JSON="):
            payload = line.split("=", 1)[1]
            try:
                data["json"] = json.loads(payload)
            except json.JSONDecodeError:
                data["json"] = {}
    return data


def mesh_ping(from_node: dict, to_hostname: str, to_ip: str) -> tuple[bool, str]:
    if not to_ip:
        return False, "target has no tailscale IP"
    remote = f"tailscale ping -c 3 --timeout=5s {to_hostname} 2>&1 || tailscale ping -c 3 --timeout=5s {to_ip} 2>&1"
    conn = from_node["conn"]
    if conn["username"] != "root":
        remote = f"echo '{conn['password']}' | sudo -S bash -c \"{remote}\""
    return ssh_cmd(conn["public_ip"], conn["ssh_port"], conn["username"], conn["password"], remote, timeout=45)


def main() -> int:
    inv = load_yaml(INVENTORY)
    srv = load_yaml(SECRETS_SRV)
    keys = load_yaml(SECRETS_KEYS)
    auth_key = tailscale_auth_key(keys)

    inv_by_secret = {s["secrets_ref"]: s for s in inv["servers"] if s.get("secrets_ref")}
    nodes = []
    for conn in srv["servers"]:
        inv_node = inv_by_secret.get(conn["id"], {})
        password = secret_value(keys, conn.get("password_ref", ""))
        nodes.append({
            "id": conn["id"],
            "hostname": inv_node.get("hostname", conn["id"]),
            "role": inv_node.get("role_ref", ""),
            "conn": {
                "public_ip": conn["public_ip"],
                "ssh_port": conn["ssh_port"],
                "username": conn["username"],
                "password": password,
            },
        })

    report = {
        "auth_key_present": bool(auth_key),
        "actions": [],
        "nodes": {},
        "peer_matrix": {},
        "magicdns": {"enabled": False, "reason": "inventory mesh.dns.enabled=false; --accept-dns=false"},
        "exit_nodes": {},
        "warnings": [],
        "errors": [],
    }

    for node in nodes:
        nid = node["id"]
        c = node["conn"]
        report["nodes"][nid] = {"hostname": node["hostname"], "role": node["role"]}

        ok, msg = rsync_repo(c["public_ip"], c["ssh_port"], c["username"], c["password"])
        report["actions"].append({"node": nid, "action": "sync_repo", "ok": ok, "detail": msg[:500]})

        ok, msg = ensure_tailscale_installed(c["public_ip"], c["ssh_port"], c["username"], c["password"])
        report["actions"].append({"node": nid, "action": "ensure_tailscale", "ok": ok, "detail": msg[:500]})
        if not ok:
            report["errors"].append(f"{nid}: tailscale install/start failed")
            continue

        ok, msg = ensure_userspace_if_needed(c["public_ip"], c["ssh_port"], c["username"], c["password"])
        report["actions"].append({"node": nid, "action": "userspace_tun_check", "ok": ok, "detail": msg[:300]})
        if not ok:
            report["errors"].append(f"{nid}: userspace networking setup failed")

    if not auth_key:
        report["errors"].append("tailscale-auth-key missing from secrets/api-keys.yaml and TAILSCALE_AUTH_KEY env")
        print(json.dumps(report, indent=2))
        return 2

    for node in nodes:
        nid = node["id"]
        c = node["conn"]
        ok, msg = join_mesh(c["public_ip"], c["ssh_port"], c["username"], c["password"], auth_key, node["hostname"])
        report["actions"].append({"node": nid, "action": "tailscale_up", "ok": ok, "detail": msg[:800]})
        if not ok:
            report["errors"].append(f"{nid}: tailscale up failed")

    time.sleep(3)

    ts_data = {}
    for node in nodes:
        nid = node["id"]
        c = node["conn"]
        data = query_tailscale(c["public_ip"], c["ssh_port"], c["username"], c["password"])
        ts_data[nid] = data
        backend = data["json"].get("Self", {}) if isinstance(data["json"], dict) else {}
        report["nodes"][nid].update({
            "tailscale_ip": data["ip"],
            "tailscale_version": data["version"],
            "tailscaled": data["tailscaled"],
            "online": backend.get("Online", False) if backend else bool(data["ip"]),
            "exit_node": backend.get("ExitNode", False) if backend else False,
            "exit_node_option": backend.get("ExitNodeOption", False) if backend else False,
            "magic_dns": False,
        })
        report["exit_nodes"][nid] = {
            "is_exit_node": report["nodes"][nid]["exit_node"],
            "exit_node_option": report["nodes"][nid]["exit_node_option"],
        }
        if not data["ip"]:
            report["errors"].append(f"{nid}: no tailscale IP assigned")
        if data["tailscaled"] != "active":
            report["warnings"].append(f"{nid}: tailscaled is {data['tailscaled']}")

    node_ids = [n["id"] for n in nodes]
    for src in nodes:
        report["peer_matrix"][src["id"]] = {}
        for dst in nodes:
            if src["id"] == dst["id"]:
                report["peer_matrix"][src["id"]][dst["id"]] = "self"
                continue
            dst_ip = report["nodes"][dst["id"]].get("tailscale_ip", "")
            ok, msg = mesh_ping(src, report["nodes"][dst["id"]]["hostname"], dst_ip)
            report["peer_matrix"][src["id"]][dst["id"]] = {"ok": ok, "detail": msg[:300]}
            if not ok:
                report["errors"].append(f"ping {src['id']} -> {dst['id']} failed")

    print(json.dumps(report, indent=2))
    return 0 if not report["errors"] else 1


if __name__ == "__main__":
    sys.exit(main())
