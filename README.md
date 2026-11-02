# QA-skills

One-command installer that registers the **Playwright MCP server** (`npx @playwright/mcp@latest`) and installs the seven **qa-playwright\* skills** for five AI coding agents:

| Agent | MCP config written | Skills written |
|---|---|---|
| omp | `~/.omp/agent/mcp.json` → `mcpServers.playwright` | `~/.omp/skills/<name>/` |
| hermes | `~/.hermes/config.yaml` → `mcp_servers.playwright` | `~/.hermes/skills/qa/<name>/` |
| claude (Claude Code) | `claude mcp add -s user` → `~/.claude.json` | `~/.claude/skills/<name>/` |
| codex | `~/.codex/config.toml` → `[mcp_servers.playwright]` | `~/.codex/skills/<name>/` |
| zcode | `~/.zcode/cli/config.json` → `mcp.servers.playwright` (strict schema) | `~/.zcode/skills/<name>/` |

Skills installed: `qa-playwright`, `qa-playwright-core`, `qa-playwright-branch-features`, `qa-playwright-forms-auth`, `qa-playwright-i18n-rtl`, `qa-playwright-responsive`, `qa-playwright-ssr-seo`.

## Install

**Linux / WSL:**

```sh
curl -fsSL https://raw.githubusercontent.com/Amirhossein-Mirzaei23/QA-skills/main/install.sh | sh -s -- --all
```

**Windows (Git Bash / MSYS2):**

```sh
curl -fsSL https://raw.githubusercontent.com/Amirhossein-Mirzaei23/QA-skills/main/install.sh | sh -s -- --all
```

Same script, same command — it detects Windows and writes `cmd /c npx @playwright/mcp@latest` (the exec form Windows needs) instead of plain `npx`.

Run from a clone instead of a pipe: `git clone … && ./install.sh --all`.

## Options

```
./install.sh                       interactive confirm for detected agents
./install.sh --all                 all detected agents, no prompt
./install.sh --agents hermes,codex restrict to a subset
./install.sh --skills-only         skills only
./install.sh --mcp-only            MCP config only
./install.sh --project             also write ./.mcp.json into the current repo (omp project scope)
./install.sh --dry-run             show everything, write nothing
./install.sh --uninstall --all     reverse what was installed (per-manifest)
```

Every modified config gets a sibling `.bak.<timestamp>` backup. Re-runs detect identical state and change nothing.

## Requirements

- `node` / `npx` on PATH (the MCP server itself runs via npx; JSON configs are merged with node)
- `curl` and `tar` for the piped one-liner
- At least one supported agent installed

## Verify after install

Restart the agents, then:

```sh
claude mcp list                 # playwright — Connected
codex: start a session          # mcp_servers.playwright loaded from config.toml
hermes: start a session         # playwright tools available
zcode: Settings → MCP           # playwright connected
omp:   start a session          # playwright tools are deferred — fetch via tool_search
```

omp note: omp keeps MCP tools out of the system prompt (deferred discovery). The `qa-playwright-core` skill's first step loads them via `tool_search` — that is expected behavior, not a missing server.

## Uninstall

```sh
./install.sh --uninstall --all
```

Removes exactly the skill directories and MCP entries this installer recorded in `~/.qa-skills-installer/manifest` — pre-existing skills and unrelated config keys are never touched.

## Windows notes

- Use Git Bash (ships with Git for Windows). WSL counts as Linux and configures Linux-side agents only.
- All five agents accept the `cmd /c npx …` launch shape the installer writes on Windows.
- Configs live under `%USERPROFILE%` (`.codex`, `.zcode`, `.claude`, `.hermes`, `.omp`).

## License

Skill content: proprietary (see each `SKILL.md`). Installer: MIT.
