#!/usr/bin/env bash
# fab-auth.sh — Authenticate the fab CLI as a service principal
#
# Usage:
#   bash fab-auth.sh
#
# Required environment variables (at least one credential set must be present):
#
#   AZURE_CLIENT_ID      / CLIENT_ID      — service principal app ID
#   AZURE_CLIENT_SECRET  / CLIENT_SECRET  — client secret
#   AZURE_TENANT_ID      / TENANT_ID      — Entra ID tenant ID
#
# Both the AZURE_* prefix (generic Azure convention) and the unprefixed form
# (used in ADO variable groups) are accepted. AZURE_* takes priority.
#
# Exit codes:
#   0 — authenticated successfully
#   1 — missing credentials or auth failure

set -uo pipefail

# ── resolve credentials (AZURE_* preferred, fall back to unprefixed) ──────────

CLIENT_ID="${AZURE_CLIENT_ID:-${CLIENT_ID:-}}"
CLIENT_SECRET="${AZURE_CLIENT_SECRET:-${CLIENT_SECRET:-}}"
TENANT_ID="${AZURE_TENANT_ID:-${TENANT_ID:-}}"

# ── validate ──────────────────────────────────────────────────────────────────

MISSING=()
[[ -z "$CLIENT_ID"     ]] && MISSING+=("AZURE_CLIENT_ID")
[[ -z "$CLIENT_SECRET" ]] && MISSING+=("AZURE_CLIENT_SECRET")
[[ -z "$TENANT_ID"     ]] && MISSING+=("AZURE_TENANT_ID")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "fab-auth: missing required environment variables: ${MISSING[*]}" >&2
  echo "Set them before calling this script:" >&2
  echo "  export AZURE_CLIENT_ID=<app-id>" >&2
  echo "  export AZURE_CLIENT_SECRET=<secret>" >&2
  echo "  export AZURE_TENANT_ID=<tenant-id>" >&2
  exit 1
fi

# ── configure fab CLI mode ────────────────────────────────────────────────────

fab config set mode command_line
fab config set encryption_fallback_enabled true

# ── authenticate ──────────────────────────────────────────────────────────────

fab auth login \
  -u "$CLIENT_ID" \
  -p "$CLIENT_SECRET" \
  --tenant "$TENANT_ID"
