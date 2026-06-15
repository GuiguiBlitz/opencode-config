# RTK — Quickstart for Pi and OpenCode

[RTK (Rust Token Killer)](https://github.com/rtk-ai/rtk) is a high-performance CLI proxy that
reduces LLM token consumption by **60–90%** by filtering and compressing command output before it
reaches the model. It is a single Rust binary with <10ms overhead and support for 100+ commands.

---

## How It Works

```
  Without RTK:                              With RTK:

  Pi  --git status-->  shell  -->  git      Pi  --git status-->  RTK  -->  git
   ^                               |         ^                    |          |
   |     ~2,000 tokens (raw)       |         |  ~200 tokens       | filter   |
   +-------------------------------+         +---- (filtered) ----+----------+
```

RTK's Pi integration is a **TypeScript extension** that hooks into Pi's `tool_call` event.
It intercepts every `bash` tool call, runs `rtk rewrite <command>` in the background (<2ms),
and mutates the command in-place if a compact equivalent exists. The model never sees the
`rtk` prefix — it just receives dramatically smaller output.

---

## Installation

### 1. Install the RTK binary

**Homebrew (macOS & Linux, recommended):**
```bash
brew install rtk-ai/tap/rtk
```

**Quick install (Linux/macOS curl):**
```bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
# Add to PATH if needed:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc   # or ~/.zshrc
```

**Cargo (from source):**
```bash
# ⚠️ Use the Git URL — two unrelated crates share the name "rtk"
cargo install --git https://github.com/rtk-ai/rtk rtk
```

### 2. Verify the installation

```bash
rtk --version   # e.g. rtk 0.28.2
rtk gain        # token savings dashboard (should not error)
```

> If `rtk gain` fails, you may have the wrong package. Run `cargo uninstall rtk` and reinstall
> using the Git URL above.

### 3. Install the agent extension

#### OpenCode

**Global (all projects):**
```bash
rtk init --global --opencode
# shorthand:
rtk init -g --opencode
```
→ Writes `~/.config/opencode/plugins/rtk.ts`. Uses the `tool.execute.before` hook.

Uninstall:
```bash
rtk init --uninstall --global --opencode
```

#### Pi

**Global (all Pi projects):**
```bash
rtk init --agent pi --global
```
→ Writes `~/.pi/agent/extensions/rtk.ts`

**Project-local only:**
```bash
cd /your/project
rtk init --agent pi
```
→ Writes `.pi/extensions/rtk.ts` inside the project

Uninstall:
```bash
rtk init --uninstall --agent pi --global   # global
rtk init --uninstall --agent pi            # project-local
```

### 4. Restart the agent

**OpenCode:** restart the OpenCode session; it auto-discovers plugins from
`~/.config/opencode/plugins/` on startup.

**Pi:** auto-discovers extensions at startup from both `~/.pi/agent/extensions/` and
`.pi/extensions/`. No manual config change is needed.

---

## Verifying It Works

After restarting Pi, ask the agent to run any instrumented command (e.g. `git status`,
`cargo test`). Then check savings:

```bash
rtk gain
# Total commands : 12
# Input tokens   : 45,230
# Output tokens  : 4,890
# Saved          : 40,340  (89.2%)
```

To preview rewrites without a running session:
```bash
rtk rewrite "cargo test"
# → rtk cargo test
rtk rewrite "git log -n 10"
# → rtk git log -n 10
```

---

## Uninstall

```bash
# OpenCode (global)
rtk init --uninstall --global --opencode

# Pi (global)
rtk init --uninstall --agent pi --global

# Pi (project-local)
rtk init --uninstall --agent pi
```

---

## Configuration

RTK config lives at `~/.config/rtk/config.toml` (Linux) or
`~/Library/Application Support/rtk/config.toml` (macOS).

```bash
rtk config            # show current config
rtk config --create   # create config file with defaults
```

### Key options

```toml
[tracking]
enabled = true
history_days = 90

[display]
colors = true
emoji = true
max_width = 120

[filters]
ignore_dirs = [".git", "node_modules", "target", "__pycache__", ".venv"]
ignore_files = ["*.lock", "*.min.js", "*.min.css"]

[tee]
enabled = true      # saves full raw output to disk when a command fails
mode = "failures"   # "failures" | "always" | "never"

[telemetry]
enabled = true      # anonymous daily ping; set false to opt out

[hooks]
exclude_commands = []   # commands to never auto-rewrite
```

### Environment variables

| Variable | Effect |
|---|---|
| `RTK_DISABLED=1` | Disable RTK for one command or the whole session |
| `RTK_TELEMETRY_DISABLED=1` | Opt out of anonymous telemetry |
| `RTK_HOOK_AUDIT=1` | Enable hook audit logging |

### Excluding commands from rewrite

```toml
[hooks]
exclude_commands = ["git rebase", "docker exec", "^curl"]
```

Or ad-hoc:
```bash
RTK_DISABLED=1 git rebase main
```

### Per-project filters

Create `.rtk/filters.toml` in the project root to add custom filters or override built-ins.
See the [filter DSL reference](https://github.com/rtk-ai/rtk/blob/master/src/filters/README.md).

---

## Token Savings Reference (30-min session)

| Command | Standard | RTK | Savings |
|---|---|---|---|
| `ls` / `tree` × 10 | 2,000 | 400 | −80% |
| `cat` / `read` × 20 | 40,000 | 12,000 | −70% |
| `grep` / `rg` × 8 | 16,000 | 3,200 | −80% |
| `git status` × 10 | 3,000 | 600 | −80% |
| `git diff` × 5 | 10,000 | 2,500 | −75% |
| `git log` × 5 | 2,500 | 500 | −80% |
| `cargo test` / `npm test` × 5 | 25,000 | 2,500 | −90% |
| `pytest` × 4 | 8,000 | 800 | −90% |
| **Total** | **~118,000** | **~23,900** | **−80%** |

---

## How the Agent Plugins Work (Technical)

Both integrations are thin TypeScript delegates. All rewrite logic lives in the Rust binary
(`src/discover/registry.rs`). The hooks are purely thin delegates.

### OpenCode plugin (`rtk.ts`)

1. Registers on the `tool.execute.before` hook.
2. For each `bash` tool call, runs `rtk rewrite <cmd>` with a short timeout.
3. If RTK returns a rewritten command, the input is mutated in-place before OpenCode executes it.
4. All error paths are silent — RTK never blocks execution.

### Pi extension (`rtk.ts`)

1. On load, probes `rtk --version` and aborts silently if RTK is missing or too old (< 0.23.0).
2. Subscribes to Pi's `tool_call` event and narrows to `bash` tool calls via `isToolCallEventType`.
3. For each command, calls `rtk rewrite <cmd>` via `pi.exec` with a 2-second timeout.
4. If RTK returns a rewritten command (exit 0 or 3), `event.input.command` is mutated in-place.
5. All error paths return `undefined` — RTK never blocks execution.

---

## Resources

- [RTK GitHub](https://github.com/rtk-ai/rtk)
- [Official docs](https://www.rtk-ai.app)
- [Supported agents](https://github.com/rtk-ai/rtk/blob/master/docs/guide/getting-started/supported-agents.md)
- [What RTK optimizes](https://github.com/rtk-ai/rtk/blob/master/docs/guide/resources/what-rtk-covers.md)
- [Troubleshooting](https://www.rtk-ai.app/guide/troubleshooting)
- [Discord](https://discord.gg/RySmvNF5kF)
