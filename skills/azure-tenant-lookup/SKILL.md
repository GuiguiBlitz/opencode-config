---
name: azure-tenant-lookup
description: >
  Use this skill when asked to find the tenant, organisation, or owner behind
  an Azure storage account (blob, ADLS, or any *.blob.core.windows.net
  endpoint).   Triggers on phrases like "who owns this storage account",
  "which tenant is mystorageaccount in", "find the tenant for", "which
  organisation owns", "what company is behind this Azure resource".
  Executes a fully unauthenticated, public-signal-only lookup — no Azure
  credentials are required.
version: 1.0.0
compatibility: [agents.md/v1, opencode, claude-code, github-copilot, cursor]
authors: [azure-agent]
---

# Azure Tenant Lookup

Resolves the owning Azure AD / Entra ID tenant of any Azure Storage Account
using only public, unauthenticated HTTP signals. No credentials, no `az login`,
no subscription access required.

---

## Capabilities

- Identify the Entra ID tenant UUID from a storage account name.
- Resolve the tenant UUID to a human-readable organisation/company display name.
- Report the tenant's Azure geographic region scope.
- Works on any `*.blob.core.windows.net` endpoint (standard storage, ADLS Gen2,
  static websites, etc.).

---

## Execution Constraints & Guardrails

- **No authentication required or used.** All three signal sources are public.
- **Read-only.** This skill never writes, modifies, or creates any resource.
- **Do not fabricate names.** If `sCompanyDisplayName` is absent or returns
  `"Microsoft Services"` (the fallback for unbranded tenants), report the UUID
  and region only and note the absence of a display name.
- **Verify existence first.** If the initial HEAD probe returns a non-2xx and
  non-4xx status, the storage account does not exist — stop and report this
  clearly before continuing.
- **Single script call.** All HTTP logic is encapsulated in the shell script.
  Do not reproduce the curl commands inline; call the script and read its
  JSON output.

---

## User-Intent Mappings

### Scenario 1: User provides a storage account name

**Example prompts:**
- "Which tenant owns `mystorageaccount`?"
- "Find the organisation behind storage account `mystorageaccount`"
- "Who owns `contosodatalake`?"

**Execution sequence:**

1. Extract the storage account name from the user's message (strip any
   `.blob.core.windows.net` suffix if present).
2. Run the lookup script:
   ```bash
   bash /home/guigui/agents/skills/azure-tenant-lookup/scripts/find-tenant.sh <storage_account_name>
   ```
3. Parse the JSON payload returned on stdout.
4. If `"error"` key is present in the JSON, report the error message verbatim
   and stop.
5. Render results as the Markdown table defined in the **Output Format** section
   below.

### Scenario 2: User provides a full blob URL

**Example prompts:**
- "Who owns `https://mystorageaccount.blob.core.windows.net/mycontainer/file.txt`?"

**Execution sequence:**

1. Extract the hostname prefix (the part before `.blob.core.windows.net`).
2. Proceed identically to Scenario 1 from step 2 onwards.

---

## Output Format

Render a Markdown table with the following columns, sourced from the JSON keys:

| Field | JSON key | Notes |
|---|---|---|
| Storage Account | `storage_account` | As provided |
| Tenant ID | `tenant_id` | UUID |
| Organisation | `tenant_name` | Display name; `—` if unavailable |
| Region | `tenant_region` | e.g. `EU`, `NA`, `AP` |
| Source | `source` | Signal chain used |

**Example rendered output:**

| Field | Value |
|---|---|
| **Storage Account** | `mystorageaccount` |
| **Tenant ID** | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **Organisation** | Contoso Ltd |
| **Region** | EU |
| **Source** | WWW-Authenticate challenge → login branding |

Always append the following disclaimer after the table:

> Source: public unauthenticated signals only. No credentials were used or
> required. Data reflects Azure AD tenant metadata at query time.

---

## Technical Background (for agent reasoning)

The technique exploits two public Azure behaviours:

**Step 1 — WWW-Authenticate Tenant Leak**

Azure Blob Storage returns an HTTP 401 when an invalid Bearer token is
presented. The `WWW-Authenticate` response header contains the full OAuth2
`authorization_uri`, which embeds the tenant UUID in its path:

```
WWW-Authenticate: Bearer authorization_uri=https://login.microsoftonline.com/<TENANT_UUID>/oauth2/authorize resource_id=https://storage.azure.com
```

This is by design (RFC 6750 §3.1) and is not a vulnerability.

**Step 2 — Login Page Branding Endpoint**

Azure AD's hosted login page for a given tenant returns a JSON configuration
block (`$Config`) embedded in the HTML. The field `sCompanyDisplayName`
contains the tenant's registered display name as configured in Entra ID.
The endpoint is:

```
https://login.microsoftonline.com/<TENANT_UUID>/oauth2/authorize
  ?client_id=04b07795-8ddb-461a-bbee-02f9e1bf7b46
  &response_type=code
  &redirect_uri=https://localhost
```

`04b07795-8ddb-461a-bbee-02f9e1bf7b46` is the well-known public client ID of
the Azure CLI — it does not grant any access; it is used only to trigger the
HTML login page render.

---

## Examples

### Input
"Which company owns the storage account `mystorageaccount`?"

### Expected Action Chain
1. Run `bash /home/guigui/agents/skills/azure-tenant-lookup/scripts/find-tenant.sh mystorageaccount`
2. Parse JSON stdout.
3. Render result table with disclaimer.

### Expected Output

| Field | Value |
|---|---|
| **Storage Account** | `mystorageaccount` |
| **Tenant ID** | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **Organisation** | Contoso Ltd |
| **Region** | EU |
| **Source** | WWW-Authenticate challenge → login branding |

> Source: public unauthenticated signals only. No credentials were used or
> required. Data reflects Azure AD tenant metadata at query time.
