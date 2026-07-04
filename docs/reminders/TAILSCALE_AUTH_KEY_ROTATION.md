# Tailscale Auth Key — Rotation Reminder

| Field | Value |
|-------|-------|
| Secret ID | `tailscale-auth-key` |
| Provisioned | 2026-06-29 |
| **Expires / rotate by** | **2026-09-27** (90 days) |
| Location | `secrets/api-keys.yaml` |

## Action required on 2026-09-27

1. Open [Tailscale Admin → Keys](https://login.tailscale.com/admin/settings/keys)
2. Generate a new reusable, pre-authorized auth key
3. Update `secrets/api-keys.yaml` → `tailscale-auth-key.value`
4. Update `rotation_due` to +90 days from provision date
5. Re-run `python3 scripts/deploy/deploy-network-foundation.py` if re-join is needed

> Nodes already joined remain connected after key expiry. The key is only needed for **new** device enrollment.
