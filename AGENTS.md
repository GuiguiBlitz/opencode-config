# OpenCode Config — Maintenance Guide

This repo tracks two things:

- **`skills/`** — agent skills loaded by OpenCode at runtime
- **`opencode.json`** — sanitized config template (API key redacted)

---

## Repository Layout

```
.
├── AGENTS.md            ← this file
├── opencode.json        ← config template (apiKey = "YOUR_API_KEY")
└── skills/
    ├── <skill-name>/
    │   ├── SKILL.md     ← skill definition loaded by the agent
    │   └── scripts/     ← helper scripts referenced by the skill
    └── ...
```

The `.gitignore` intentionally excludes everything except the above.
All other directories under `/home/guigui/agents/` are project workspaces
and are not versioned here.

---

## opencode.json

The live config lives at `~/.config/opencode/opencode.json`.
This repo holds a copy with `apiKey` replaced by `"YOUR_API_KEY"`.

**When updating the config:**

1. Edit `~/.config/opencode/opencode.json` as needed.
2. Copy the change to `opencode.json` in this repo, then redact the key:
   ```bash
   cp ~/.config/opencode/opencode.json ./opencode.json
   # Then set "apiKey": "YOUR_API_KEY" manually or with:
   sed -i 's/"apiKey": ".*"/"apiKey": "YOUR_API_KEY"/' opencode.json
   ```
3. Commit and push.

---

## Skills

Skills are Markdown files that inject specialized instructions and workflows
into the agent's context when a matching user intent is detected.

OpenCode loads skills from the path configured in `opencode.json`:

```json
"skills": {
  "paths": ["/home/guigui/agents/skills"]
}
```

Each skill lives in its own subdirectory:

```
skills/<skill-name>/
├── SKILL.md          ← required: skill definition
└── scripts/          ← optional: bash helpers called by the skill
    └── <helper>.sh
```

### Adding a new skill

1. Create the directory: `skills/<skill-name>/`
2. Write `SKILL.md` using the template below.
3. Add any helper scripts under `scripts/` (make them executable: `chmod +x`).
4. Commit both files.

### Removing or renaming a skill

- Delete or move the directory and commit.
- OpenCode picks up the change on next launch (no restart needed for most clients).

---

## Skill Template

````markdown
---
name: <skill-name>
description: >
  One-paragraph description of when to load this skill.
  Include trigger phrases the agent should match on (e.g. "list workspaces",
  "run notebook", "find tenant"). This text is used by the agent to decide
  whether to load the skill.
version: 1.0.0
compatibility: [agents.md/v1, opencode, claude-code, github-copilot, cursor]
authors: [<author>]
---

# <Skill Title>

One-sentence summary of what this skill does.

---

## Execution Constraints & Guardrails

- **Constraint 1.** Describe a hard rule the agent must follow.
- **Constraint 2.** E.g. read-only by default, always authenticate first, etc.
- **Do not fabricate.** If a value is missing, report it as absent.

---

## Step 0 — Prerequisites (if any)

Describe any setup the agent must perform before executing commands
(authentication, env var checks, etc.).

```bash
bash /home/guigui/agents/skills/<skill-name>/scripts/<helper>.sh
```

---

## User-Intent Mappings

### Scenario 1: <describe the scenario>

**Example prompts:**
- "..."
- "..."

**Execution sequence:**

1. Step one.
2. Step two.
3. Render results using the Output Format below.

### Scenario 2: <describe the scenario>

...

---

## Output Format

Describe the expected output structure (table, JSON, prose, etc.).

**Example rendered output:**

| Field | Value |
|---|---|
| **Field 1** | `example-value` |
| **Field 2** | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |

---

## Examples

### Input
"Example user prompt"

### Expected Action Chain
1. Run `bash /home/guigui/agents/skills/<skill-name>/scripts/<helper>.sh`
2. Parse output.
3. Render result.

### Expected Output

| Field | Value |
|---|---|
| **Field 1** | `dummy-value` |
````

---

## Script conventions

Helper scripts follow these conventions (see existing scripts for reference):

- `#!/usr/bin/env bash` shebang, `set -uo pipefail`
- Accept input via positional arguments or environment variables (never hardcoded credentials)
- Output JSON on stdout on success; `{"error": "<msg>"}` on failure
- Exit 0 on success, 1 on error
- Use only standard POSIX tools (`curl`, `grep`, `sed`) unless a specific CLI is the point of the skill

---

## Existing Skills

### `azure-tenant-lookup`

Resolves the Entra ID tenant (UUID, display name, region) behind any Azure
Storage Account using only public unauthenticated HTTP signals.

- No credentials required.
- Script: `scripts/find-tenant.sh <storage_account_name>`
- Returns JSON with keys: `storage_account`, `tenant_id`, `tenant_name`, `tenant_region`, `source`

### `fab-cli`

Wraps the Microsoft Fabric `fab` CLI for workspace, capacity, ACL, job, table,
and raw REST operations.

- Requires `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` env vars.
- Always run `scripts/fab-auth.sh` before any `fab` command.
- Script: `scripts/fab-auth.sh` (sets CLI mode, enables encryption fallback, logs in as service principal)
