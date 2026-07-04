#!/usr/bin/env python3
"""RAS v1.0 — Read-only infrastructure validation. No modifications."""
import subprocess
import sys
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
PRECHECK = REPO / "scripts" / "deploy" / "precheck-remote.sh"


def load_yaml(path):
    with open(path) as f:
        return yaml.safe_load(f)


def get_password(secrets_keys, ref):
    for s in secrets_keys.get("secrets", []):
        if s.get("id") == ref:
            return s.get("value", "")
    return ""


def ssh_run(host, port, user, password, remote_cmd, input_data=None):
    cmd = [
        "sshpass", "-e", "ssh",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=15",
        "-p", str(port),
        f"{user}@{host}",
        remote_cmd,
    ]
    env = {**subprocess.os.environ, "SSHPASS": password}
    r = subprocess.run(
        cmd,
        input=input_data,
        capture_output=True,
        text=True,
        env=env,
        timeout=60,
    )
    return r.returncode == 0, (r.stdout or "") + (r.stderr or "")


def main():
    inv = load_yaml(INVENTORY)
    srv = load_yaml(SECRETS_SRV)
    keys = load_yaml(SECRETS_KEYS)
    precheck = PRECHECK.read_text()

    inv_by_secret = {s["secrets_ref"]: s for s in inv["servers"] if s.get("secrets_ref")}
    srv_by_id = {s["id"]: s for s in srv["servers"]}

    results = []
    for node_id, conn in srv_by_id.items():
        inv_node = inv_by_secret.get(node_id, {})
        expected_hn = inv_node.get("hostname", node_id)
        password = get_password(keys, conn.get("password_ref", ""))
        host, port, user = conn["public_ip"], conn["ssh_port"], conn["username"]

        entry = {
            "id": node_id,
            "expected_hostname": expected_hn,
            "role": inv_node.get("role_ref", ""),
            "site": inv_node.get("site", ""),
            "endpoint": f"{user}@{host}:{port}",
            "reachable": False,
            "auth": False,
            "hostname_match": False,
            "observed_hostname": "",
            "precheck": "",
            "containers": "",
        }

        ok, out = ssh_run(host, port, user, password, "echo AUTH_OK")
        entry["reachable"] = ok
        if "AUTH_OK" in out:
            entry["auth"] = True

        if entry["auth"]:
            if user == "root":
                remote = "bash -s"
                ok2, pre = ssh_run(host, port, user, password, remote, precheck)
            else:
                remote = f"{{ echo '{password}'; cat; }} | sudo -S bash -s"
                ok2, pre = ssh_run(host, port, user, password, remote, precheck)
            
            # Remove any sudo prompts from output lines
            cleaned_lines = []
            for line in pre.splitlines():
                cleaned_line = line.replace("[sudo] password for devapp:", "").strip()
                if not cleaned_line or cleaned_line.startswith("[sudo] password for"):
                    continue
                cleaned_lines.append(cleaned_line)

            entry["precheck"] = "\n".join(cleaned_lines)

            for line in cleaned_lines:
                if line.startswith("=== HOSTNAME ==="):
                    continue
                if "===" in line and "HOSTNAME" not in line:
                    break
                if line.strip() and "===" not in line:
                    entry["observed_hostname"] = line.strip()
                    break
            if not entry["observed_hostname"]:
                for i, line in enumerate(cleaned_lines):
                    if line.strip() == "=== HOSTNAME ===" and i + 1 < len(cleaned_lines):
                        entry["observed_hostname"] = cleaned_lines[i + 1].strip()
                        break

            entry["hostname_match"] = entry["observed_hostname"] == expected_hn

            if user == "root":
                _, cout = ssh_run(host, port, user, password,
                    "docker ps -a --format '{{.Names}}|{{.Status}}|{{.Ports}}' 2>/dev/null; echo DONE")
            else:
                _, cout = ssh_run(host, port, user, password,
                    f"echo '{password}' | sudo -S docker ps -a --format '{{{{.Names}}}}|{{{{.Status}}}}|{{{{.Ports}}}}' 2>/dev/null; echo DONE")
            entry["containers"] = cout.strip()

        results.append(entry)
        print(f"\n{'='*60}\nNODE:{node_id}\n{'='*60}")
        print(f"ENDPOINT:{entry['endpoint']}")
        print(f"REACHABLE:{'PASS' if entry['reachable'] else 'FAIL'}")
        print(f"AUTH:{'PASS' if entry['auth'] else 'FAIL'}")
        print(f"HOSTNAME_EXPECTED:{expected_hn}")
        print(f"HOSTNAME_OBSERVED:{entry['observed_hostname']}")
        print(f"HOSTNAME_MATCH:{'PASS' if entry['hostname_match'] else 'FAIL'}")
        if entry["precheck"]:
            print(entry["precheck"][:3000])

    # Inter-node TCP from jkt
    print(f"\n{'='*60}\nINTER-NODE CONNECTIVITY\n{'='*60}")
    jkt = srv_by_id.get("redi-jkt-01")
    if jkt:
        pw = get_password(keys, jkt["password_ref"])
        for nid, c in srv_by_id.items():
            if nid == "redi-jkt-01":
                continue
            _, out = ssh_run(jkt["public_ip"], jkt["ssh_port"], jkt["username"], pw,
                f"nc -zv -w 3 {c['public_ip']} {c['ssh_port']} 2>&1")
            print(f"jkt -> {nid} ({c['public_ip']}:{c['ssh_port']}): {out.strip()}")

    # Write machine-readable summary for report
    summary_path = REPO / "reports" / "validation-raw.txt"
    summary_path.parent.mkdir(exist_ok=True)
    with open(summary_path, "w") as f:
        for e in results:
            f.write(yaml.dump(e, default_flow_style=False))
            f.write("---\n")
    return results


if __name__ == "__main__":
    main()
