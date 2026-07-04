#!/usr/bin/env bash
# =============================================================================
# REDI — Redis Sentinel helpers (source from deploy scripts)
# =============================================================================

redis_sentinel_master_addr() {
  local sentinel_host="${1:-127.0.0.1}"
  local sentinel_port="${2:-26379}"
  local password="${3:-}"
  local auth=()
  [[ -n "${password}" ]] && auth=(-a "${password}")

  local out
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'redi-redis-sentinel'; then
    out="$(docker exec redi-redis-sentinel redis-cli -p "${sentinel_port}" "${auth[@]}" \
      sentinel get-master-addr-by-name redi-master 2>/dev/null || true)"
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

# HAProxy on redi-internal cannot reach Tailscale mesh IPs; map to docker DNS when local.
redis_haproxy_backend_addr() {
  local master_ip="${1:-}"
  local master_port="${2:-6379}"
  local mjk_mesh="${MJK_MESH_IP:-100.81.86.37}"
  local jkt_mesh="${JKT_MESH_IP:-100.79.82.92}"

  if [[ "${master_ip}" == "${mjk_mesh}" ]]; then
    printf '%s\n%s\n' "redi-redis" "${master_port}"
  else
    printf '%s\n%s\n' "${master_ip}" "${master_port}"
  fi
}
