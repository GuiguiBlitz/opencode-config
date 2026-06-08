#!/usr/bin/env bash
# find-tenant.sh — Resolve the Entra ID tenant behind an Azure Storage Account
#
# Usage:
#   bash find-tenant.sh <storage_account_name>
#
# Output:
#   JSON on stdout. Keys:
#     storage_account  — name as provided
#     tenant_id        — Azure AD tenant UUID
#     tenant_name      — display name from login branding ("" if unavailable)
#     tenant_region    — region scope from OIDC config ("" if unavailable)
#     source           — human-readable signal chain description
#   On error:
#     { "error": "<message>", "storage_account": "<name>" }
#
# Dependencies: curl, grep, sed  (standard on macOS/Linux)
# No credentials, no az login, no subscription access required.

set -uo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

die() {
  local account="${1:-}"
  local msg="${2:-unknown error}"
  printf '{"error":"%s","storage_account":"%s"}\n' \
    "$(printf '%s' "$msg" | sed 's/"/\\"/g')" \
    "$(printf '%s' "$account" | sed 's/"/\\"/g')"
  exit 1
}

json_string() {
  # Minimal JSON-safe escaping: backslash, double-quote, control chars
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g' \
    | sed 's/"/\\"/g'
}

# ── argument validation ───────────────────────────────────────────────────────

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  printf '{"error":"usage: find-tenant.sh <storage_account_name>","storage_account":""}\n'
  exit 1
fi

# Normalise: strip protocol, then path, then blob hostname suffix
ACCOUNT="${1}"
ACCOUNT="${ACCOUNT#https://}"
ACCOUNT="${ACCOUNT#http://}"
ACCOUNT="${ACCOUNT%%/*}"
ACCOUNT="${ACCOUNT%.blob.core.windows.net}"

BLOB_HOST="${ACCOUNT}.blob.core.windows.net"

# ── step 0: verify the storage account exists ─────────────────────────────────

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 10 \
  "https://${BLOB_HOST}/")

case "$HTTP_STATUS" in
  000)
    die "$ACCOUNT" "storage account '${ACCOUNT}' is unreachable (DNS resolution failed or network timeout)"
    ;;
  404)
    die "$ACCOUNT" "storage account '${ACCOUNT}' does not exist (HTTP 404)"
    ;;
  400|401|403|200|409)
    : # Expected — account exists; continue
    ;;
  *)
    # Any other response still indicates the host resolved; continue with a note
    : ;;
esac

# ── step 1: extract tenant UUID via WWW-Authenticate challenge ────────────────
#
# Azure Blob returns HTTP 401 with:
#   WWW-Authenticate: Bearer authorization_uri=https://login.microsoftonline.com/<UUID>/oauth2/authorize ...
# when an invalid bearer token is presented. The UUID is the tenant ID.

WWW_AUTH=$(curl -s -D - \
  --max-time 10 \
  -H "x-ms-version: 2020-10-02" \
  -H "Authorization: Bearer __invalid__" \
  "https://${BLOB_HOST}/?comp=list" \
  | grep -i "^www-authenticate:" || true)

TENANT_ID=$(printf '%s' "$WWW_AUTH" \
  | grep -oE 'authorization_uri=https://login\.microsoftonline\.com/[0-9a-f-]{36}' \
  | grep -oE '[0-9a-f-]{36}' || true)

if [[ -z "$TENANT_ID" ]]; then
  die "$ACCOUNT" "could not extract tenant ID from WWW-Authenticate header — account may use shared-key auth only or is not a standard blob endpoint"
fi

SOURCE="WWW-Authenticate challenge"

# ── step 2: resolve tenant UUID → company display name ───────────────────────
#
# Azure AD's hosted login page embeds a JSON config block ($Config) in HTML.
# sCompanyDisplayName holds the tenant's registered display name.
# client_id 04b07795-… is the public Azure CLI app — grants no access.

LOGIN_HTML=$(curl -s \
  --max-time 15 \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/authorize\
?client_id=04b07795-8ddb-461a-bbee-02f9e1bf7b46\
&response_type=code\
&redirect_uri=https://localhost" || true)

TENANT_NAME=$(printf '%s' "$LOGIN_HTML" \
  | grep -oE '"sCompanyDisplayName":"[^"]*"' \
  | head -1 \
  | sed 's/"sCompanyDisplayName":"//;s/"//' || true)

# Treat the generic Microsoft fallback as "no display name"
if [[ "$TENANT_NAME" == "Microsoft Services" || -z "$TENANT_NAME" ]]; then
  TENANT_NAME=""
fi

if [[ -n "$TENANT_NAME" ]]; then
  SOURCE="${SOURCE} → login branding"
fi

# ── step 3: tenant region from OIDC discovery document ───────────────────────

OIDC=$(curl -s \
  --max-time 10 \
  "https://login.microsoftonline.com/${TENANT_ID}/v2.0/.well-known/openid-configuration" \
  || true)

TENANT_REGION=$(printf '%s' "$OIDC" \
  | grep -oE '"tenant_region_scope":"[^"]*"' \
  | head -1 \
  | sed 's/"tenant_region_scope":"//;s/"//' || true)

if [[ -n "$TENANT_REGION" ]]; then
  SOURCE="${SOURCE} → OIDC discovery"
fi

# ── output ────────────────────────────────────────────────────────────────────

printf '{\n'
printf '  "storage_account": "%s",\n' "$(json_string "$ACCOUNT")"
printf '  "tenant_id": "%s",\n'       "$(json_string "$TENANT_ID")"
printf '  "tenant_name": "%s",\n'     "$(json_string "$TENANT_NAME")"
printf '  "tenant_region": "%s",\n'   "$(json_string "$TENANT_REGION")"
printf '  "source": "%s"\n'           "$(json_string "$SOURCE")"
printf '}\n'
