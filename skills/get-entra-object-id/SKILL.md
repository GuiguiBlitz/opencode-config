---
name: get-entra-object-id
description: >
  Use this skill when you need to resolve an Entra ID (Azure AD) user Object ID
  from an email address / UPN. Triggers on phrases like "get object id for",
  "resolve UPN", "find entra id for", "what is the object id of", "look up user id",
  "get entra object id". Requires CLIENT_ID, CLIENT_SECRET, and TENANT_ID
  environment variables to be set.
version: 1.0.0
compatibility: [agents.md/v1, opencode, claude-code]
authors: [azure-agent]
---

# Get Entra Object ID for a User

Resolve an Entra ID (Azure AD) user Object ID from a UPN / email address using
the Azure CLI authenticated as a Service Principal.

---

## Prerequisites

The following environment variables must be set:

| Variable | Description |
|---|---|
| `CLIENT_ID` | Service principal / app registration client ID |
| `CLIENT_SECRET` | Client secret |
| `TENANT_ID` | Entra ID tenant ID |

The SPN must have **`User.Read.All`** (application permission) in Microsoft
Graph, or at minimum be able to call `az ad user show`.

---

## Steps

### 1. Authenticate with Azure CLI

```bash
az login --service-principal \
  -u $CLIENT_ID \
  -p $CLIENT_SECRET \
  --tenant $TENANT_ID \
  --output none
```

### 2. Resolve the UPN to an Object ID

```bash
az ad user show --id <upn_or_email> --query id -o tsv
```

**Example:**

```bash
az ad user show --id user@example.com --query id -o tsv
# Output: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 3. Use the Object ID

Pass the returned UUID to any downstream command that requires an Entra Object
ID — for example `fab acl set`:

```bash
fab acl set "My Workspace.Workspace" -I <object-id> -R admin -f
```

---

## Notes

- The returned value is a UUID (e.g. `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
- If the UPN is not found, `az ad user show` exits non-zero and returns an
  error — check spelling and confirm the user exists in the tenant.
- Guest / external accounts (suffix `-ext@<tenant>.com`) are fully supported as
  long as the SPN has `User.Read.All`.
- Frequently used Object IDs are cached in `.user-ids.md` at the workspace
  root — check there first before making an API call.
