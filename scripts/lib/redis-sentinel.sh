#!/usr/bin/env bash
# =============================================================================
# REDI — Redis Sentinel helpers (source from deploy scripts)
# =============================================================================

redis_sentinel_master_addr() {
  local sentinel_host="${1:-127.0.0.1}"
  local sentinel_port="${2:-26379}"
  local password="${3:-${REDIS_PASSWORD:-}}"
  local auth=()
  [[ -n "${password}" ]] && auth=(-a "${password}")

  local out=""
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'redi-redis-sentinel'; then
    for host in 127.0.0.1 "${NODE_MESH_IP:-}"; do
      [[ -n "${host}" ]] || continue
      out="$(docker exec redi-redis-sentinel redis-cli -h "${host}" -p "${sentinel_port}" "${auth[@]}" \
        sentinel get-master-addr-by-name redi-master 2>/dev/null || true)"
      [[ -n "${out}" ]] && break
    done
    if [[ -z "${out}" ]]; then
      out="$(docker exec redi-redis-sentinel grep -E '^sentinel monitor redi-master ' /data/sentinel.conf 2>/dev/null \
        | awk '{print $4"\n"$5}' || true)"
    fi
  else
    out="$(redis-cli -h "${sentinel_host}" -p "${sentinel_port}" "${auth[@]}" \
      sentinel get-master-addr-by-name redi-master 2>/dev/null || true)"
  fi

  local ip port
  ip="$(echo "${out}" | sed -n '1p' | tr -d '[:space:]')"
  port="$(echo "${out}" | sed -n '2p' | tr -d '[:space:]')"
  [[ -n "${ip}" && -n "${port}" ]] || return 1
  printf '%s\n%s\n' "${ip}" "${port}"
}

redis_sentinel_master_ip() {
  redis_sentinel_master_addr "$@" | sed -n '1p'
}

# Bridge HAProxy uses local redis when this node is Sentinel master; otherwise mesh IP.
redis_haproxy_backend_addr() {
  local master_ip="${1:-}"
  local master_port="${2:-6379}"
  local local_mesh="${NODE_MESH_IP:-}"

  if [[ -z "${local_mesh}" ]] && command -v get_tailscale_ip >/dev/null 2>&1; then
    local_mesh="$(get_tailscale_ip 2>/dev/null || true)"
  fi

  if [[ -n "${local_mesh}" && "${master_ip}" == "${local_mesh}" ]]; then
    printf '%s\n%s\n' "redi-redis" "${master_port}"
  else
    printf '%s\n%s\n' "${master_ip}" "${master_port}"
  fi
}
