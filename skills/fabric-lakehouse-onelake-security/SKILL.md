---
name: fabric-lakehouse-onelake-security
description: >
  Use this skill for any task involving OneLake data access roles (DAR) on
  Fabric lakehouses: checking whether OneLake security is enabled, reading
  existing roles, adding groups or users to DefaultReader or custom roles,
  creating roles from scratch, and understanding why Viewer-role users cannot
  read shortcut data. Triggers on phrases like "onelake security", "data access
  roles", "viewer can't read shortcuts", "grant lakehouse access", "DefaultReader",
  "ReadAll role", "shortcut permissions", "manage lakehouse access".
version: 1.0.0
compatibility: [agents.md/v1, opencode, claude-code]
authors: [azure-agent]
---

# Fabric Lakehouse — OneLake Security (Data Access Roles)

## Background

OneLake security is Fabric's data-plane RBAC for lakehouses. It controls who
can read data **at the OneLake storage layer**, independently of workspace roles.
It is distinct from workspace ACLs (Admin / Member / Contributor / Viewer).

### Key rule: Viewer ≠ ReadAll

| Workspace role | ReadAll (OneLake storage) |
|---|---|
| Admin, Member, Contributor | Automatic |
| **Viewer** | **No** — blocked unless explicitly granted via a OneLake data access role |

This means: **internal OneLake shortcuts use passthrough identity**. When a user
in a downstream workspace reads data through a shortcut, Fabric evaluates their
permissions on the *source* lakehouse. If they are Viewer on the source workspace
and no OneLake data access role covers them, the shortcut read fails.

**Fix**: add the user/group to a OneLake data access role (`DefaultReader` or
a custom `ReadAll` role) on the source lakehouse.

---

## Concepts

- **DefaultReader** — stock role present on all lakehouses where OneLake security
  has been enabled. Grants `Read` on all paths (`*`). Uses `fabricItemMembers`
  with `itemAccess: ["ReadAll"]` to automatically include all `ReadAll` holders
  (Contributor+). Viewer-role users are **not** included unless explicitly added
  to `microsoftEntraMembers`.
- **Custom roles** (e.g. `ReadAll`, `ReadWriteAll`) — manually created roles with
  explicit `microsoftEntraMembers`. Some lakehouses use these instead of
  `DefaultReader`.
- **UniversalSecurityFeatureDisabledForWorkspace** — the OneLake security runtime
  feature has not been activated on this workspace/lakehouse. Must be enabled via
  the Fabric portal (Manage OneLake security button) by an Admin or Member. The
  API cannot activate it unless the caller has Admin/Member role.

---

## Granting / upgrading workspace roles

Use `fab acl set` — it both grants and upgrades roles in place (no need to
check for an existing assignment first):

```bash
fab acl set "<Workspace Display Name>.Workspace" -I <entra-object-id> -R admin -f
# roles: admin | member | contributor | viewer
```

To grant via the REST API instead (e.g. when the workspace name is unknown):

```bash
# Add new assignment
fab api workspaces/<ws-id>/roleAssignments -X post \
  -H "content-type=application/json" \
  -i '{"principal": {"id": "<oid>", "type": "User"}, "role": "Admin"}'

# Upgrade existing assignment (get <ra-id> from GET roleAssignments first)
fab api workspaces/<ws-id>/roleAssignments/<ra-id> -X patch \
  -H "content-type=application/json" \
  -i '{"principal": {"id": "<oid>", "type": "User"}, "role": "Admin"}'
```

Note: the REST body uses `"principal"` (singular), not `"principals"`.

---

## Authentication

Always authenticate before any `fab` command:

```bash
export AZURE_CLIENT_ID=$CLIENT_ID
export AZURE_CLIENT_SECRET=$CLIENT_SECRET
export AZURE_TENANT_ID=$TENANT_ID
bash /home/guigui/agents/skills/fab-cli/scripts/fab-auth.sh
```

---

## Step 1 — Check if OneLake security is enabled on a lakehouse

```bash
fab api workspaces/<ws-id>/items/<lh-id>/dataAccessRoles --output_format json
```

**Interpret the response:**

| Response | Meaning |
|---|---|
| `status_code: 200`, `value: [...]` | OneLake security enabled; roles listed |
| `status_code: 200`, `value: []` | Enabled but no roles defined |
| `status_code: 400`, `errorCode: UniversalSecurityFeatureDisabledForWorkspace` | **Not enabled** — must activate via portal first |

Also check `alm.settings.json` via `getDefinition`:

```bash
fab api workspaces/<ws-id>/items/<lh-id>/getDefinition -X post \
  -H "content-type=application/json" --output_format json
```

Decode the `alm.settings.json` part (base64) — look for `"DataAccessRoles": "Enabled"`.

---

## Step 2 — Determine which case applies

| Case | Condition | Action |
|---|---|---|
| **A** | Has `DefaultReader`, group not yet in `microsoftEntraMembers` | Add group to `DefaultReader` |
| **B** | Has no roles at all (or only empty roles) | Create `DefaultReader` from scratch |
| **C** | Has a custom `ReadAll` role (no `DefaultReader`) | Add group to `ReadAll` |
| **Blocked** | `UniversalSecurityFeatureDisabledForWorkspace` | Enable via portal first, then apply Case B |

---

## Step 3 — Apply the change

The endpoint is a **PUT that replaces the full role list**. Always include all
existing roles in the payload — not just the one being modified.

### Case A — Add group to existing `DefaultReader`

```python
import json, subprocess

ws_id  = "<workspace-id>"
lh_id  = "<lakehouse-id>"
TENANT = "<entra-tenant-id>"
GROUP  = "<entra-group-object-id>"

# 1. Fetch current roles
r = subprocess.run(['fab', 'api', f'workspaces/{ws_id}/items/{lh_id}/dataAccessRoles',
                    '--output_format', 'json'], capture_output=True, text=True)
current_roles = json.loads(r.stdout)['result']['data'][0]['text']['value']

# 2. Add group to DefaultReader.microsoftEntraMembers
for role in current_roles:
    if role['name'] == 'DefaultReader':
        entra = role['members'].get('microsoftEntraMembers', [])
        if not any(m['objectId'] == GROUP for m in entra):
            entra.append({"tenantId": TENANT, "objectId": GROUP})
        role['members']['microsoftEntraMembers'] = entra

# 3. PUT full role list
subprocess.run(['fab', 'api', f'workspaces/{ws_id}/items/{lh_id}/dataAccessRoles',
                '-X', 'put', '-H', 'content-type=application/json',
                '-i', json.dumps({"value": current_roles}),
                '--output_format', 'json'], capture_output=True, text=True)
```

### Case B — Create `DefaultReader` from scratch

OneLake security must already be enabled (see Blocked case below if not).

```python
payload = {"value": [{
    "name": "DefaultReader",
    "decisionRules": [{"effect": "Permit", "permission": [
        {"attributeName": "Action", "attributeValueIncludedIn": ["Read"]},
        {"attributeName": "Path",   "attributeValueIncludedIn": ["*"]}
    ]}],
    "members": {
        "microsoftEntraMembers": [{"tenantId": TENANT, "objectId": GROUP}],
        "fabricItemMembers": [
            {"sourcePath": f"{ws_id}/{lh_id}", "itemAccess": ["ReadAll"]}
        ]
    }
}]}

subprocess.run(['fab', 'api', f'workspaces/{ws_id}/items/{lh_id}/dataAccessRoles',
                '-X', 'put', '-H', 'content-type=application/json',
                '-i', json.dumps(payload), '--output_format', 'json'],
               capture_output=True, text=True)
```

### Case C — Add group to existing custom role

Same as Case A but match the custom role name (e.g. `ReadAll`). Preserve all
other roles (e.g. `ReadWriteAll`) unchanged in the PUT payload.

### Blocked — Enable OneLake security first

The `UniversalSecurityFeatureDisabledForWorkspace` error means the feature has
never been activated on this workspace. It requires a user with **Admin or
Member** workspace role to enable it:

1. **Via portal** (required if SPN only has Contributor):
   - Open the lakehouse → ribbon → **Manage OneLake security (preview)**
   - Confirm the prompt — this activates the feature
   - Then re-run the PUT via API

2. **Via `updateDefinition`** (only affects ALM/git tracking, NOT the runtime
   feature — does **not** resolve the 400 error):
   - Decode `alm.settings.json` from `getDefinition`, set `DataAccessRoles` to
     `Enabled`, re-encode as base64, POST to `updateDefinition`
   - This returns HTTP 202 (async) but does NOT enable the runtime security feature

> **Known limitation**: as of June 2026, the runtime OneLake security feature
> cannot be activated programmatically via the Fabric REST API or `fab` CLI by
> a Contributor-role SPN. Admin or Member role on the workspace is required.

---

## Bulk scan pattern

Use this to sweep all lakehouses across multiple workspaces and classify each
by which action is needed:

```python
import json, subprocess

def get_lakehouses(ws_id):
    r = subprocess.run(['fab', 'api', f'workspaces/{ws_id}/items',
                        '--output_format', 'json'], capture_output=True, text=True)
    items = json.loads(r.stdout)['result']['data'][0]['text']['value']
    return [i for i in items if i['type'] == 'Lakehouse']

def get_dar(ws_id, lh_id):
    r = subprocess.run(['fab', 'api',
                        f'workspaces/{ws_id}/items/{lh_id}/dataAccessRoles',
                        '--output_format', 'json'], capture_output=True, text=True)
    obj = json.loads(r.stdout)
    sc  = obj['result']['data'][0].get('status_code')
    val = obj['result']['data'][0].get('text', {})
    if sc == 200:
        return val.get('value', [])
    err = val.get('moreDetails', [{}])[0].get('errorCode', '')
    return f"ERROR:{err}"

GROUP_OID = "<entra-group-object-id>"

workspaces = [("WS Name", "ws-id"), ...]  # populate from fab ls -l

for ws_name, ws_id in workspaces:
    for lh in get_lakehouses(ws_id):
        roles = get_dar(ws_id, lh['id'])
        if isinstance(roles, str):
            case = "BLOCKED (OneLake security not enabled)"
        elif not roles:
            case = "B (no roles — create DefaultReader)"
        elif any(r['name'] == 'DefaultReader' for r in roles):
            has_group = any(
                any(m['objectId'] == GROUP_OID
                    for m in r.get('members', {}).get('microsoftEntraMembers', []))
                for r in roles if r['name'] == 'DefaultReader'
            )
            case = "DONE" if has_group else "A (add group to DefaultReader)"
        else:
            case = "C (custom role — add group there)"
        print(ws_name, lh['displayName'], case)
```
