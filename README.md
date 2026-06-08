# opencode-config

OpenCode agent configuration: MCP servers, model settings, and skills.

## Contents

| Path | Purpose |
|---|---|
| `tmpl_opencode.json` | Config template (API key redacted — copy to `~/.config/opencode/opencode.json` and fill in your key) |
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

2. Copy and configure `tmpl_opencode.json` as your live config:
   ```bash
   cp ~/agents/tmpl_opencode.json ~/.config/opencode/opencode.json
   # Edit ~/.config/opencode/opencode.json and set your apiKey
   ```

3. OpenCode will automatically pick up skills from `~/agents/skills/` on next launch.

## Business context workspaces

Each business context (a client, a project, a domain) gets its own folder under `~/agents/`:

```
~/agents/
├── skills/          ← shared skills, available to all agents
├── tmpl_opencode.json    ← global config template
├── acme-corp/       ← one folder per business context
│   └── AGENTS.md   ← context-specific instructions for the agent
├── contoso/
│   └── AGENTS.md
└── ...
```

When you open OpenCode **from inside a context folder**, it reads that folder's `AGENTS.md`
and uses it as the system prompt for the session — giving you an agent that knows the
context, conventions, and constraints of that specific project.

**To create a new context:**

1. Create the folder:
   ```bash
   mkdir ~/agents/<context-name>
   ```

2. Add an `AGENTS.md` describing the context — who the client is, what tools and APIs
   are in scope, any naming conventions, guardrails, or background knowledge the agent
   should have.

3. Open OpenCode from that folder:
   ```bash
   cd ~/agents/<context-name>
   opencode
   ```

The shared `skills/` are always available regardless of which context you're in.

## Maintenance

See [AGENTS.md](./AGENTS.md) for the full guide on updating the config and creating new skills.
