# Agent Config — Maintenance Guide

This repo tracks configuration for two coding agents — **OpenCode** and **Pi** — plus
the shared skills that both agents load.

Tracked files:

- **`skills/`** — agent skills (loaded by both OpenCode and Pi at runtime)
- **`RTK.md`** — RTK (Rust Token Killer) quickstart and Pi integration guide
- **`tmpl_opencode.json`** — OpenCode config template (API key redacted)
- **`tmpl_pi_models.json`** — Pi custom provider/model template (API key redacted)
- **`tmpl_pi_settings.json`** — Pi global settings template
- **`tmpl_pi_mcp.json`** — Pi MCP server config template (for `pi-mcp-adapter`)

---

## Repository Layout

```
.
├── AGENTS.md                ← this file
├── RTK.md                   ← RTK quickstart + Pi integration guide
├── tmpl_opencode.json       ← OpenCode config template (apiKey = "YOUR_API_KEY")
├── tmpl_pi_models.json      ← Pi models template  (apiKey = "YOUR_API_KEY")
├── tmpl_pi_settings.json    ← Pi settings template
├── tmpl_pi_mcp.json         ← Pi MCP servers template
└── skills/
    ├── <skill-name>/
    │   ├── SKILL.md     ← skill definition loaded by the agent
    │   └── scripts/     ← helper scripts referenced by the skill
    └── ...
```

The `.gitignore` intentionally excludes everything except the above.
All other directories under `$HOME/agents/` are project workspaces
and are not versioned here.

---

## tmpl_opencode.json

The live config lives at `~/.config/opencode/opencode.json`.
This repo holds a sanitized copy named `tmpl_opencode.json` with `apiKey` replaced by `"YOUR_API_KEY"`.
The file is intentionally **not** named `opencode.json` to avoid being picked up by OpenCode automatically.

**When updating the config:**

1. Edit `~/.config/opencode/opencode.json` as needed.
2. Copy the change to `tmpl_opencode.json` in this repo, then redact the key:
   ```bash
   cp ~/.config/opencode/opencode.json ./tmpl_opencode.json
   # Then set "apiKey": "YOUR_API_KEY" manually or with:
   sed -i 's/"apiKey": ".*"/"apiKey": "YOUR_API_KEY"/' tmpl_opencode.json
   ```
3. Commit and push.

---

## tmpl_pi_models.json

The live config lives at `~/.pi/agent/models.json`.
This repo holds a sanitized copy named `tmpl_pi_models.json` with `apiKey` replaced by `"YOUR_API_KEY"`.

Defines the `llmproxy` custom provider (Orange LiteLLM proxy, OpenAI-compatible completions)
and the `vertex_ai/claude-sonnet-4-6` model entry.

**When updating the config:**

1. Edit `~/.pi/agent/models.json` as needed.
2. Copy the change to `tmpl_pi_models.json` in this repo, then redact the key:
   ```bash
   cp ~/.pi/agent/models.json ./tmpl_pi_models.json
   sed -i 's/"apiKey": ".*"/"apiKey": "YOUR_API_KEY"/' tmpl_pi_models.json
   ```
3. Commit and push.

---

## tmpl_pi_settings.json

The live config lives at `~/.pi/agent/settings.json`.
This repo holds a copy named `tmpl_pi_settings.json` (no secrets — safe to commit as-is).

Configures: default provider/model, shared skills path, and the four Pi packages:
`context-mode`, `pi-mcp-adapter`, `pi-web-access`, `pi-subagents`.

> **Note:** Running `pi install npm:<package>` writes directly to `~/.pi/agent/settings.json`.
> After installing packages this way, sync back to the template:
> ```bash
> cp ~/.pi/agent/settings.json ./tmpl_pi_settings.json
> ```

**When updating the config:**

1. Edit `~/.pi/agent/settings.json` as needed (or run `pi install`/`pi remove`).
2. Copy the change to `tmpl_pi_settings.json`:
   ```bash
   cp ~/.pi/agent/settings.json ./tmpl_pi_settings.json
   ```
3. Commit and push.

---

## tmpl_pi_mcp.json

The live config lives at `~/.pi/agent/mcp.json`.
This repo holds a copy named `tmpl_pi_mcp.json` (no secrets — safe to commit as-is).

Read by `pi-mcp-adapter`. Defines the three MCP servers:
- `azure` — `@azure/mcp@latest` (stdio, lazy)
- `microsoft-learn` — `https://learn.microsoft.com/api/mcp` (HTTP, lazy)
- `drawio` — `drawio-mcp-server --editor` (stdio, lazy)

All servers use `lifecycle: "lazy"` — they connect only on first tool call.
Use `/mcp` inside Pi to inspect status, reconnect, or toggle direct tools.

**When updating the config:**

1. Edit `~/.pi/agent/mcp.json` as needed.
2. Copy the change to `tmpl_pi_mcp.json`:
   ```bash
   cp ~/.pi/agent/mcp.json ./tmpl_pi_mcp.json
   ```
3. Commit and push.

---

## Skills

Skills are Markdown files that inject specialized instructions and workflows
into the agent's context when a matching user intent is detected.

OpenCode loads skills from the path configured in `tmpl_opencode.json`:
Pi loads skills from the path configured in `tmpl_pi_settings.json`.

```json
"skills": {
  "paths": ["$HOME/agents/skills"]
}
```

Pi (`tmpl_pi_settings.json`):

```json
"skills": ["~/agents/skills"]
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
- Pi picks up the change on next launch or after `/reload` inside a session.

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
bash $HOME/agents/skills/<skill-name>/scripts/<helper>.sh
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
1. Run `bash $HOME/agents/skills/<skill-name>/scripts/<helper>.sh`
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

---

## RTK — Rust Token Killer

[RTK](https://github.com/rtk-ai/rtk) is a high-performance CLI proxy that reduces LLM token
consumption by 60–90%. It intercepts bash commands and rewrites them to their compact RTK
equivalents before the model sees the output.

Full quickstart and Pi integration guide: **[RTK.md](./RTK.md)**

**TL;DR — install and enable for Pi and OpenCode:**

```bash
# 1. Install binary
brew install rtk-ai/tap/rtk          # Homebrew
# or: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh

# 2a. Install OpenCode plugin (global)
rtk init -g --opencode               # writes ~/.config/opencode/plugins/rtk.ts

# 2b. Install Pi extension (global)
rtk init --agent pi --global         # writes ~/.pi/agent/extensions/rtk.ts

# 3. Restart the agent — then verify
rtk gain                              # shows token savings dashboard
```

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
