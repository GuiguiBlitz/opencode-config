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

### Scenario 5: No dedicated subcommand exists

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
