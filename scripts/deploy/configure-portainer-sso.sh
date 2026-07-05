#!/usr/bin/env bash
# =============================================================================
# REDI Phase 6 — Configure Authentik SSO for Portainer CE
# Run on redi-mjk-01 only. Preserves local admin authentication.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDI_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root

[[ "$(hostname -s)" == "redi-mjk-01" ]] || { log_error "Run on redi-mjk-01"; exit 1; }

SECRETS_FILE="${REDI_ROOT}/secrets/api-keys.yaml"
PORTAINER_URL="https://100.81.86.37:9443"
ADMIN_PASSWORD="$(grep -A3 'portainer-admin-password' "${SECRETS_FILE}" | awk -F"'" '/value:/ {print $2; exit}')"
[[ -n "${ADMIN_PASSWORD}" ]] || { log_error "Missing portainer-admin-password in ${SECRETS_FILE}"; exit 1; }

log_info "Creating Authentik OAuth provider for Portainer"
PY="${SCRIPT_DIR}/configure-portainer-sso.py"
docker cp "${PY}" redi-authentik-server:/tmp/configure_portainer_sso.py
OUT="$(docker exec redi-authentik-server ak shell -c "exec(open('/tmp/configure_portainer_sso.py').read())" 2>&1 | grep -E '^(provider_ok|app_ok|OIDC_)' || true)"
echo "${OUT}"

OIDC_CLIENT_ID="$(echo "${OUT}" | sed -n 's/^OIDC_CLIENT_ID=//p')"
OIDC_CLIENT_SECRET="$(echo "${OUT}" | sed -n 's/^OIDC_CLIENT_SECRET=//p')"
OIDC_AUTH_URL="$(echo "${OUT}" | sed -n 's/^OIDC_AUTH_URL=//p')"
OIDC_TOKEN_URL="$(echo "${OUT}" | sed -n 's/^OIDC_TOKEN_URL=//p')"
OIDC_USERINFO_URL="$(echo "${OUT}" | sed -n 's/^OIDC_USERINFO_URL=//p')"
OIDC_LOGOUT_URL="$(echo "${OUT}" | sed -n 's/^OIDC_LOGOUT_URL=//p')"
[[ -n "${OIDC_CLIENT_ID}" && -n "${OIDC_CLIENT_SECRET}" ]] || { log_error "Authentik provider setup failed"; exit 1; }

log_info "Applying Portainer OAuth settings"
python3 <<PY
import json, subprocess, sys

admin_password = ${ADMIN_PASSWORD@Q}
portainer_url = ${PORTAINER_URL@Q}

auth = subprocess.check_output([
    "curl", "-sk", "-X", "POST", f"{portainer_url}/api/auth",
    "-H", "Content-Type: application/json",
    "-d", json.dumps({"Username": "admin", "Password": admin_password}),
])
token = json.loads(auth)["jwt"]
settings = json.loads(subprocess.check_output([
    "curl", "-sk", "-H", f"Authorization: Bearer {token}", f"{portainer_url}/api/settings",
]))

settings["AuthenticationMethod"] = 3
settings["OAuthSettings"] = {
    "ClientID": ${OIDC_CLIENT_ID@Q},
    "ClientSecret": ${OIDC_CLIENT_SECRET@Q},
    "AuthorizationURI": ${OIDC_AUTH_URL@Q},
    "AccessTokenURI": ${OIDC_TOKEN_URL@Q},
    "ResourceURI": ${OIDC_USERINFO_URL@Q},
    "RedirectURI": "https://portainer.letsredi.com/",
    "LogoutURI": ${OIDC_LOGOUT_URL@Q},
    "UserIdentifier": "preferred_username",
    "Scopes": "openid email profile",
    "OAuthAutoCreateUsers": True,
    "DefaultTeamID": 0,
    "SSO": True,
    "KubeSecretKey": None,
    "AuthStyle": 0,
}

result = subprocess.check_output([
    "curl", "-sk", "-X", "PUT", f"{portainer_url}/api/settings",
    "-H", f"Authorization: Bearer {token}",
    "-H", "Content-Type: application/json",
    "-d", json.dumps(settings),
])
updated = json.loads(result)
if updated.get("AuthenticationMethod") != 3:
    print("FAIL: AuthenticationMethod not OAuth", file=sys.stderr)
    sys.exit(1)
if not updated.get("OAuthSettings", {}).get("ClientID"):
    print("FAIL: OAuthSettings not applied", file=sys.stderr)
    sys.exit(1)
print("portainer_oauth_ok")
PY

log_info "Portainer SSO configured (local admin preserved)"
