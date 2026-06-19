---
name: fab-cli
description: >
  Use this skill for any task involving Microsoft Fabric via the fab CLI:
  listing workspaces or items, managing capacities, assigning permissions,
  running jobs, loading tables, importing/exporting items, or calling raw
  Fabric REST endpoints. Triggers on phrases like "list fabric workspaces",
  "run this notebook", "pause the capacity", "grant access to workspace",
  "deploy to fabric", "check job status", "fab cli", "fabric cli".
  Always authenticate before any fab command using the script in this skill.
version: 1.0.0
compatibility: [agents.md/v1, opencode, claude-code, github-copilot, cursor]
authors: [azure-agent]
---

# fab CLI

Microsoft Fabric command-line interface. Covers all Fabric API surfaces:
workspaces, capacities, items, ACLs, jobs, tables, and raw REST endpoints.

---

## Execution Constraints & Guardrails

- **Authenticate first.** Run the auth script before any `fab` command.
  Never skip this step, even if a previous auth appears cached.
- **Use `-f` for scripted mutations.** Any command that modifies state
  (`mkdir`, `rm`, `set`, `acl set`, `acl rm`, `stop`, `start`, etc.) must
  include `-f` to suppress interactive prompts.
- **Prefer `fab` over hand-rolled HTTP.** Only fall back to `fab api` for
  endpoints not covered by a dedicated subcommand.
- **Never delete without confirming scope.** `fab rm -f` is irreversible.
  State the target explicitly to the user before executing.
- **Read-only by default.** Assume read-only intent unless the user
  explicitly requests a mutation.

---

## Step 0 — Authentication (always run first)

Credentials are expected as environment variables:

| Variable | Description |
|---|---|
| `AZURE_CLIENT_ID` | Service principal / app registration client ID |
| `AZURE_CLIENT_SECRET` | Client secret |
| `AZURE_TENANT_ID` | Entra ID tenant ID |

Authenticate by running the auth script:

```bash
bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh
```

The script sets `command_line` mode, enables encryption fallback, and logs in
as a service principal. After running it, check the result with:

```bash
fab auth status
```

If the user has not provided credentials via environment variables, ask for
them before proceeding. Do not hardcode credentials.

---

## Command Reference

### Authentication & Config

```bash
fab auth status                        # check current auth state
fab config ls                          # list all CLI settings
fab config clear-cache                 # clear cached data
```

### Exploration & Navigation

```bash
fab ls                                          # list all workspaces
fab ls -l                                       # detailed (id, type, capacity…)
fab ls -l -a                                    # include hidden (.capacities, .domains, .gateways…)
fab ls <ws>.Workspace                           # list items in a workspace
fab ls <ws>.Workspace -l                        # detailed items list
fab ls <ws>.Workspace -la                       # include hidden items
fab ls .capacities                              # list Fabric capacities
fab ls .capacities -l                           # with SKU / state / region
fab ls <ws>.Workspace -q "[?contains(name,'bronze')]"   # JMESPath filter
fab get <ws>.Workspace -q .                     # full workspace JSON
fab get <ws>.Workspace -q id                    # single property
fab exists <ws>.Workspace                       # exits 0 if exists, 1 if not
fab open <ws>.Workspace                         # open workspace in browser
```

### Workspace Management

```bash
fab mkdir <ws>.Workspace -P capacityname=<cap>  # create workspace on a capacity
fab mkdir <ws>.Workspace -P capacityname=none   # create without capacity
fab set <ws>.Workspace -q displayName -i "New Name" -f
fab set <ws>.Workspace -q description -i "..." -f
fab set <ws>.Workspace -q sparkSettings.environment.runtimeVersion -i 1.2
fab rm <ws>.Workspace -f                        # delete workspace + all items (irreversible)
```

### Capacity Management

```bash
fab get .capacities/<cap>.Capacity              # get capacity details
fab start .capacities/<cap>.Capacity -f         # resume a paused capacity
fab stop .capacities/<cap>.Capacity -f          # pause a capacity
fab set .capacities/<cap>.Capacity -q sku.name -i F8   # resize SKU
fab assign .capacities/<cap>.Capacity -W <ws>.Workspace    # assign to workspace
fab unassign .capacities/<cap>.Capacity -W <ws>.Workspace  # unassign
```

### Workspace ACL / Permissions

```bash
fab acl ls <ws>.Workspace                                   # list all ACL entries
fab acl ls <ws>.Workspace -q "[].[?role=='Admin']"          # filter by role
fab acl set <ws>.Workspace -I <entra-object-id> -R contributor   # grant access
# roles: admin | member | contributor | viewer
fab acl rm <ws>.Workspace -I <entra-object-id> -f          # revoke access
fab acl ls <ws>.Workspace/<lh>.Lakehouse                    # item-level ACL
```

### Item Management (Notebooks, Pipelines, Lakehouses…)

```bash
fab get <ws>.Workspace/<nb>.Notebook -q .       # get item details / definition
fab mkdir <ws>.Workspace/<nb>.Notebook          # create item
fab rm <ws>.Workspace/<nb>.Notebook -f          # soft delete
fab rm <ws>.Workspace/<nb>.Notebook --hard -f   # permanent delete (no recovery)
fab cp <ws1>.Workspace/<nb>.Notebook <ws2>.Workspace   # copy item
fab mv <ws1>.Workspace/<nb>.Notebook <ws2>.Workspace   # move item
fab cp <ws1>.Workspace <ws2>.Workspace -r       # copy all items between workspaces
fab set <ws>.Workspace/<nb>.Notebook -q lakehouse -i <lh-id>     # bind to lakehouse
fab set <ws>.Workspace/<nb>.Notebook -q environment -i <env-id>  # bind to environment
```

### Import / Export (CI/CD, backup, deployment)

```bash
fab export <ws>.Workspace/<nb>.Notebook -o ./backup/       # export single item
fab export <ws>.Workspace -o ./backup/ -a                   # export all exportable items
fab import <ws>.Workspace -i ./backup/<nb>.Notebook         # create or update from definition
fab deploy --config config.yml --target_env dev -f          # deploy from local source
```

Minimal `fab deploy` config:

```yaml
core:
  workspace_id: "<target-workspace-guid>"
  repository_directory: "."
```

### Job Management

```bash
fab job run <ws>.Workspace/<nb>.Notebook                              # run synchronously
fab job run <ws>.Workspace/<nb>.Notebook -P date:string=2024-01-01   # with parameters
fab job run <ws>.Workspace/<nb>.Notebook --timeout 3600              # with timeout (seconds)
fab job start <ws>.Workspace/<pl>.DataPipeline                        # fire-and-forget (async)
fab job run-list <ws>.Workspace/<nb>.Notebook                         # list recent runs
fab job run-status <ws>.Workspace/<nb>.Notebook --id <job-id>         # check status
fab job run-cancel <ws>.Workspace/<nb>.Notebook --id <job-id>         # cancel run
fab job run-sch <ws>.Workspace/<nb>.Notebook --type daily --interval "09:00"
fab job run-sch <ws>.Workspace/<pl>.DataPipeline --type weekly --interval "19:00" --days "Monday,Wednesday"
fab job run-list <ws>.Workspace/<nb>.Notebook --schedule              # list schedules
fab job run-rm <ws>.Workspace/<nb>.Notebook --id <sch-id> -f          # delete a schedule
```

### Table Operations (Lakehouse Delta tables)

```bash
fab table schema <ws>.Workspace/<lh>.Lakehouse/Tables/<table>         # inspect schema
fab table load <ws>.Workspace/<lh>.Lakehouse/Tables/<table> \
  --file data.csv --mode append                                        # load CSV
fab table load <ws>.Workspace/<lh>.Lakehouse/Tables/<table> \
  --file data.parquet --format format=parquet                          # load Parquet
fab table optimize <ws>.Workspace/<lh>.Lakehouse/Tables/<table> --vorder
fab table optimize <ws>.Workspace/<lh>.Lakehouse/Tables/<table> --zorder col1,col2
fab table vacuum <ws>.Workspace/<lh>.Lakehouse/Tables/<table>          # remove old versions (default 7d)
fab table vacuum <ws>.Workspace/<lh>.Lakehouse/Tables/<table> --retain_n_hours 24
```

### Git Integration (workspace ↔ ADO repo)

The git connection API is only accessible via `fab api`. The response is
nested under `.text` in the JSON output — always parse `result.text`, not
`result` directly.

```bash
# Get git connection for a single workspace (by ID)
fab api workspaces/<ws-id>/git/connection

# Key fields in the response (.text):
#   gitConnectionState      — ConnectedAndInitialized | NotConnected
#   gitProviderDetails.gitProviderType   — AzureDevOps | GitHub
#   gitProviderDetails.organizationName
#   gitProviderDetails.projectName
#   gitProviderDetails.repositoryName
#   gitProviderDetails.branchName
#   gitProviderDetails.directoryName    — folder within the repo
#   gitSyncDetails.head                 — current commit SHA
#   gitSyncDetails.lastSyncTime         — ISO timestamp, null if never synced
```

**Bulk git status sweep across all workspaces** (use this pattern):

```python
import json, subprocess

# 1. Collect workspace IDs
out = subprocess.run(['fab', 'ls', '-l', '--output_format', 'json'],
                     capture_output=True, text=True)
data = json.loads(out.stdout)
workspaces = [(w['id'], w['name'].replace('.Workspace', ''))
              for w in data['result']['data']]

# 2. Query each workspace's git connection
for ws_id, ws_name in workspaces:
    r = subprocess.run(
        ['fab', 'api', f'workspaces/{ws_id}/git/connection'],
        capture_output=True, text=True)
    obj = json.loads(r.stdout)
    text = obj.get('text') or {}           # NOTE: always use .get('text')
    state = text.get('gitConnectionState', 'unknown')
    git   = text.get('gitProviderDetails') or {}
    sync  = text.get('gitSyncDetails') or {}
    print(ws_name, state,
          git.get('repositoryName'), git.get('branchName'),
          git.get('directoryName'), sync.get('lastSyncTime'))
```

**Connect a workspace to an ADO repo** (POST):

> **Key finding — use `myGitCredentials`, not `gitCredentials`:**
> The payload field name matters critically for SPN callers:
> - `"gitCredentials"` → rejected with `PrincipalTypeNotSupported` (SPN blocked)
> - `"myGitCredentials"` → **accepted by SPN**, routes through the connection correctly
>
> Always use `myGitCredentials` when calling as a Service Principal.
>
> **Pre-requisite:** The target `directoryName` folder **must already exist**
> in the ADO branch. The connect call validates folder existence upfront and
> returns `GitProviderResourceNotFound` if the folder is absent. Create the
> folder in ADO first (e.g. add a `.gitkeep` file via a PR), then call connect.
>
> **Never use `"directoryName": "/"` as a workaround.** Connecting to the repo
> root and then calling `initializeConnection` with `PreferWorkspace` would
> commit workspace items directly into the root of the shared monorepo,
> corrupting the folder structure for all other workspaces. Always use the
> workspace-specific subdirectory (e.g. `/aveva-pi-bronze`).
>
> **`/git/disconnect` also works** with a SPN using the same auth context.

```bash
fab api workspaces/<ws-id>/git/connect -X post \
  -H "content-type=application/json" \
  -i '{
    "gitProviderDetails": {
      "gitProviderType": "AzureDevOps",
      "organizationName": "<ado-org>",
      "projectName": "<ado-project>",
      "repositoryName": "<repo-name>",
      "branchName": "develop",
      "directoryName": "/<folder>"
    },
    "myGitCredentials": {
      "source": "ConfiguredConnection",
      "connectionId": "<fabric-connection-id>"
    }
  }'
```

**Initialize git connection after connecting** (required once after connect):

```bash
fab api workspaces/<ws-id>/git/initializeConnection -X post \
  -H "content-type=application/json" \
  -i '{"initializationStrategy": "PreferWorkspace"}'
# InitializationStrategy options:
#   PreferWorkspace — workspace content wins over repo
#   PreferRemote    — repo content wins over workspace
```

**Disconnect a workspace from git**:

```bash
fab api workspaces/<ws-id>/git/disconnect -X post \
  -H "content-type=application/json" \
  -i '{}'
```

**Get uncommitted changes** (items modified in workspace but not yet committed):

```bash
fab api workspaces/<ws-id>/git/status
# Returns list of items with workspaceChange / remoteChange fields
```

**Update workspace from git** (pull latest from branch):

```bash
fab api workspaces/<ws-id>/git/updateFromGit -X post \
  -H "content-type=application/json" \
  -i '{"remoteCommitHash": "<sha>", "workspaceHead": "<sha>", "conflictResolution": {"conflictResolutionType": "Workspace", "conflictResolutionPolicy": "PreferWorkspace"}}'
```

**Commit workspace changes to git**:

```bash
fab api workspaces/<ws-id>/git/commitToGit -X post \
  -H "content-type=application/json" \
  -i '{"mode": "All", "comment": "chore: sync workspace items"}'
```

### Raw REST API (fallback)

```bash
fab api capacities                             # GET /v1/capacities
fab api workspaces                             # GET /v1/workspaces
fab api workspaces -q "value[?name=='MyWS']"  # filter with JMESPath
fab api workspaces/<ws-id>/items              # list items by workspace ID
fab api workspaces/<ws-id>/items -X post \
  -H "content-type=application/json" \
  -i '{"displayName":"MyNotebook","type":"Notebook"}'
fab api <endpoint> -A powerbi                 # Power BI audience
fab api <endpoint> -A storage                 # OneLake storage audience
fab api <endpoint> -A azure                   # Azure Resource Manager audience
```

### Global Flags

| Flag | Purpose |
|---|---|
| `-q <jmespath>` | Filter / project output |
| `-o <path>` | Write output to file or directory |
| `-f` / `--force` | Skip confirmation prompts (required in scripts) |
| `--output_format json` | Force JSON output |

---

## User-Intent Mappings

### Scenario 1: Explore / list workspaces or items

1. Run `bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh`
2. Run the appropriate `fab ls` or `fab get` command.
3. If the user wants to filter by name, use `-q "[?contains(name,'<term>')]"`.

### Scenario 2: Mutate a workspace (create, rename, delete, assign capacity)

1. Run `bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh`
2. State the exact target and operation to the user. Wait for confirmation if
   the operation is destructive (`rm`, `unassign`, `stop`).
3. Run the command with `-f`.

### Scenario 3: Manage ACLs / permissions

1. Run `bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh`
2. Run `fab acl ls <ws>.Workspace` to show current state.
3. Apply `fab acl set` or `fab acl rm` with the Entra object ID and role.

### Scenario 4: Run or schedule a job

1. Run `bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh`
2. Use `fab job run` for synchronous execution (waits for completion, returns
   exit code).
3. Use `fab job start` for async / fire-and-forget.
4. Poll with `fab job run-status` if needed.

### Scenario 5: Inspect or manage workspace git integrations

1. Run `bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh`
2. For a **single workspace**: `fab api workspaces/<ws-id>/git/connection`
   — parse `.text.gitConnectionState`, `.text.gitProviderDetails`, and
   `.text.gitSyncDetails` from the response.
3. For a **bulk sweep across all workspaces**: use `fab ls -l --output_format json`
   to collect all IDs, then loop with `fab api workspaces/<ws-id>/git/connection`
   via a Python script (see the Git Integration section above). The `text` key
   may be `null` for workspaces that have never been connected — guard with
   `obj.get('text') or {}`.
4. To **connect** a workspace as a SPN: use `myGitCredentials` (not
   `gitCredentials`) in the POST body — `gitCredentials` is rejected with
   `PrincipalTypeNotSupported`, `myGitCredentials` is accepted. The target
   folder must already exist in the ADO branch before calling connect.
   **Never connect to `"/"` as a workaround** — initializing from root would
   corrupt the shared monorepo. Once connected, POST to
   `workspaces/<ws-id>/git/initializeConnection` with `PreferWorkspace` or
   `PreferRemote`. Disconnect also works with a SPN.
5. `gitConnectionState: NotConnected` means no repo is linked.
   `ConnectedAndInitialized` means fully wired; check `lastSyncTime` to see
   when it was last synced. A `null` lastSyncTime means connected but never
   synced (items may not have been committed yet).

### Scenario 6: No dedicated subcommand exists

1. Run `bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh`
2. Use `fab api <endpoint>` with appropriate `-X`, `-H`, `-i`, and `-A` flags.
3. Consult the Fabric REST API docs to confirm the endpoint path and payload.

---

## Examples

### List all workspaces with details
```bash
bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh
fab ls -l
```

### Pause a Fabric capacity
```bash
bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh
fab stop .capacities/fcapa1.Capacity -f
```

### Grant contributor access to a workspace
```bash
bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh
fab acl set MyWorkspace.Workspace -I <entra-object-id> -R contributor -f
```

### Run a notebook synchronously with a parameter
```bash
bash $HOME/agents/skills/fab-cli/scripts/fab-auth.sh
fab job run MyWorkspace.Workspace/MyNotebook.Notebook -P date:string=2024-01-01
```
