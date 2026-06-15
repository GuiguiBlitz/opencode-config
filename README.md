# opencode-config

Agent configuration for OpenCode and Pi: MCP servers, model settings, and skills.

## Contents

| Path | Purpose |
|---|---|
| `tmpl_opencode.json` | OpenCode config template (API key redacted — copy to `~/.config/opencode/opencode.json`) |
| `tmpl_pi_models.json` | Pi custom provider/model template (copy to `~/.pi/agent/models.json`) |
| `tmpl_pi_settings.json` | Pi global settings template (copy to `~/.pi/agent/settings.json`) |
| `tmpl_pi_mcp.json` | Pi MCP servers template for `pi-mcp-adapter` (copy to `~/.pi/agent/mcp.json`) |
| `skills/` | Agent skills loaded at runtime by both OpenCode and Pi |
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

### OpenCode

2. Copy and configure the template as your live config:
   ```bash
   cp ~/agents/tmpl_opencode.json ~/.config/opencode/opencode.json
   # Edit ~/.config/opencode/opencode.json and set your apiKey
   ```

3. OpenCode will automatically pick up skills from `~/agents/skills/` on next launch.

### Pi

2. Install Pi:
   ```bash
   npm install -g --ignore-scripts @earendil-works/pi-coding-agent
   ```

3. Copy and configure the template files:
   ```bash
   mkdir -p ~/.pi/agent
   cp ~/agents/tmpl_pi_models.json ~/.pi/agent/models.json
   # Edit ~/.pi/agent/models.json and set your apiKey

   cp ~/agents/tmpl_pi_settings.json ~/.pi/agent/settings.json
   cp ~/agents/tmpl_pi_mcp.json ~/.pi/agent/mcp.json
   ```

4. Install the packages (writes into `~/.pi/agent/settings.json` automatically):
   ```bash
   pi install npm:context-mode
   pi install npm:pi-mcp-adapter
   pi install npm:pi-web-access
   pi install npm:pi-subagents
   ```

5. (Optional) Add API keys for web search providers (`pi-web-access`):
   ```bash
   # Create ~/.pi/web-search.json with any keys you have:
   # { "exaApiKey": "exa-...", "perplexityApiKey": "pplx-...", "geminiApiKey": "AIza..." }
   # Zero-config Exa MCP search works without any keys.
   ```

6. Restart Pi. Skills from `~/agents/skills/` and all MCP servers load automatically.

#### How MCP works in Pi

Pi has no built-in MCP support. The `pi-mcp-adapter` package provides it. It reads
`~/.pi/agent/mcp.json` (and optionally `.pi/mcp.json` for project-level overrides) and
exposes all servers through a single lightweight `mcp` proxy tool. Servers are lazy by
default — they connect only when first called, not at startup.

Use `/mcp` inside Pi to see server status, toggle direct vs proxy tools, and reconnect servers.

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
