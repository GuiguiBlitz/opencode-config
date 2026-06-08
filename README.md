# opencode-config

OpenCode agent configuration: MCP servers, model settings, and skills.

## Contents

| Path | Purpose |
|---|---|
| `opencode.json` | Config template (API key redacted — copy to `~/.config/opencode/opencode.json` and fill in your key) |
| `skills/` | Agent skills loaded at runtime |
| `AGENTS.md` | Maintenance guide for the agent itself |

## Skills

| Skill | What it does |
|---|---|
| `azure-tenant-lookup` | Finds the Entra ID tenant behind any Azure Storage Account — no credentials needed |
| `fab-cli` | Drives the Microsoft Fabric `fab` CLI: workspaces, capacities, jobs, ACLs, tables |

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/GuiguiBlitz/opencode-config.git ~/agents
   ```

2. Copy and configure `opencode.json`:
   ```bash
   cp ~/agents/opencode.json ~/.config/opencode/opencode.json
   # Edit ~/.config/opencode/opencode.json and set your apiKey
   ```

3. OpenCode will automatically pick up skills from `~/agents/skills/` on next launch.

## Maintenance

See [AGENTS.md](./AGENTS.md) for the full guide on updating the config and creating new skills.
