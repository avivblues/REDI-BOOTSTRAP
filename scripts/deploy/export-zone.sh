#!/usr/bin/env bash
# =============================================================================
# REDI LAB — Export PowerDNS zone via API
# Usage: export-zone.sh [--env /opt/redi/compose/powerdns/.env] [--zone letsredi.com]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../compose/powerdns/.env"
ZONE_NAME="letsredi.com"
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --zone) ZONE_NAME="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# shellcheck source=/dev/null
source "${ENV_FILE}"

API_BASE="http://${PDNS_TAILSCALE_IP}:${PDNS_WEBSERVER_PORT}/api/v1"
ZONE="${ZONE_NAME}."
OUT="${OUTPUT:-${SCRIPT_DIR}/../../backup/zones/${ZONE_NAME}-$(date +%Y%m%d-%H%M%S).json}"

mkdir -p "$(dirname "${OUT}")"
curl -sf "${API_BASE}/servers/localhost/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -o "${OUT}"

echo "Zone exported to ${OUT}"
