# QA-skills

One-command installer that registers the **Playwright MCP server** and installs the seven **qa-playwright\* skills** — a complete browser-QA toolkit — into five AI coding agents:

| Agent | MCP config written | Skills written |
|---|---|---|
| omp | `~/.omp/agent/mcp.json` → `mcpServers.playwright` | `~/.omp/skills/<name>/` |
| hermes | `~/.hermes/config.yaml` → `mcp_servers.playwright` | `~/.hermes/skills/qa/<name>/` |
| claude (Claude Code) | `claude mcp add -s user` → `~/.claude.json` | `~/.claude/skills/<name>/` |
| codex | `~/.codex/config.toml` → `[mcp_servers.playwright]` | `~/.codex/skills/<name>/` |
| zcode | `~/.zcode/cli/config.json` → `mcp.servers.playwright` (strict schema) | `~/.zcode/skills/<name>/` |

---

## Quick install

**Linux / WSL:**

```sh
curl -fsSL https://raw.githubusercontent.com/Amirhossein-Mirzaei23/QA-skills/main/install.sh | sh -s -- --all
```

**Windows (Git Bash / MSYS2):**

```sh
curl -fsSL https://raw.githubusercontent.com/Amirhossein-Mirzaei23/QA-skills/main/install.sh | sh -s -- --all
```

Same script, same command for both platforms — it detects Windows and writes
`cmd /c npx @playwright/mcp@latest` (the exec form Windows needs) instead of plain `npx`.

Prefer running from a clone:

```sh
git clone https://github.com/Amirhossein-Mirzaei23/QA-skills.git
cd QA-skills
./install.sh --all
```

The script auto-detects which of the five agents you have installed and only touches those. Every modified config gets a sibling `.bak.<timestamp>` backup, and re-runs detect identical state and change nothing.

---

## What is Playwright MCP?

[Playwright MCP](https://github.com/microsoft/playwright-mcp) (`@playwright/mcp`) is Microsoft's official **Model Context Protocol server** that gives an AI agent a real, headless Chromium browser it can drive.

MCP (Model Context Protocol) is a standard for plugging external tools into AI agents. When an agent has the Playwright MCP server registered, it gains a set of browser tools — navigate, click, type, snapshot, screenshot, read console, watch network requests, manage tabs — and can therefore *use a web app the way a human does*:

- **It sees pages structurally, not visually.** The key tool is `browser_snapshot`, an accessibility tree where every interactive element carries a stable `ref`. The agent clicks and types by ref — no fragile pixel coordinates, no vision model needed.
- **It observes effects, not intentions.** After every action it can re-snapshot the DOM, dump `browser_console_messages` (hydration errors, JS exceptions), and inspect `browser_network_requests` (did the API call fire? was the payload right?).
- **It runs on demand.** The server launches via `npx @playwright/mcp@latest`; the first `browser_navigate` spawns the headless browser. No browsers are pre-installed or always running.
- **It can run arbitrary Playwright code** (`browser_run_code_unsafe`) for things the high-level tools can't do — setting viewports, exact payload assertions, `page.evaluate`.

That combination is exactly what browser QA needs: an agent that opens the app, exercises a flow, collects hard evidence (snapshot / console / network / screenshot), and reports pass or fail with citations.

---

## The skills and their use cases

The seven skills form a hub-and-spoke toolkit. **`qa-playwright-core` defines the shared browser loop and evidence rules; the hub routes every task to the right sub-skill.** After install, just tell your agent "test this branch" or "QA the login flow" — the matching skill loads automatically.

| Skill | Use it when |
|---|---|
| `qa-playwright` | **Hub / router.** Any browser-QA task — points at the right sub-skill. |
| `qa-playwright-core` | **Always loaded.** The navigate → snapshot → act → observe loop, tool-loading step (agents defer MCP tools until `tool_search`), stale-ref pitfalls, and the evidence rules every report must follow. |
| `qa-playwright-branch-features` | *"Test this branch."* Reads `git diff` vs the base ref, maps every changed file to the route(s) it affects, derives a test matrix (happy path **and** fail path per changed conditional), then verifies each in the browser. |
| `qa-playwright-forms-auth` | Forms and auth flows: login / register / OTP / password reset, validation errors, server rejections, double-submit guards, Enter-key submit bypass, captcha token attachment. |
| `qa-playwright-ssr-seo` | Server-side rendering and SEO: crawler-visible HTML (via `curl`), `<title>` / meta description / `og:*` / canonical in page source, Nuxt payload embedding data, no flash of empty state, zero hydration warnings. |
| `qa-playwright-i18n-rtl` | Multi-locale apps (fa / en / ar): RTL layout direction, flipped icons, truncated text, Persian digits, untranslated strings leaking through, plus dark/light theme checks on both. |
| `qa-playwright-responsive` | Viewport matrix (375 / 768 / 1440), mobile emulation, horizontal overflow, tap-target sizes, hover-only affordances that break on touch, `inputmode` keyboards, Android WebView fallback behavior. |

### Conventions every skill enforces

- **Evidence before claims** — every ✅/❌ in a report cites a snapshot line, console message, network request, or screenshot. "Looks fine" is not evidence.
- **Test, don't fix** — findings go in the report (`QA-REPORT-<scope>.md` at repo root, with a PASS / PASS WITH NOTES / FAIL summary line); the agent never edits app code mid-QA.
- **Safety** — never real credentials, payment UIs, or permission dialogs; ask for test accounts or test logged-out paths only.
- **Screenshots** land in `qa-evidence/<run-timestamp>/` at the repo root.

---

## Repo structure

```
QA-skills/
├── install.sh                  # the whole installer (POSIX sh, ~540 lines)
├── mcp/
│   └── playwright.json         # canonical MCP entry: npx @playwright/mcp@latest
└── skills/
    ├── qa-playwright/          # hub — routes tasks to sub-skills
    ├── qa-playwright-core/     # the browser loop + evidence rules (load first)
    ├── qa-playwright-branch-features/
    ├── qa-playwright-forms-auth/
    ├── qa-playwright-i18n-rtl/
    ├── qa-playwright-responsive/
    └── qa-playwright-ssr-seo/
```

Each skill is a directory with one `SKILL.md` (YAML frontmatter: name, description, tags, related skills — plus the procedure body). The installer copies these directories verbatim into each agent's skills folder; there is no build step.

---

## The installer, explained

`install.sh` is a single POSIX sh script that runs on Linux (bash/dash/WSL) and Windows (Git Bash / MSYS2). What it actually does:

1. **Bootstrap** — when piped (`curl | sh`), the script detects it's not running inside a checkout, downloads the repo tarball from GitHub, and re-executes itself from the extracted copy. `curl` + `tar` are the only bootstrap requirements.
2. **Detect agents** — for each of the five agents it checks for the config file/dir or CLI on PATH, and targets only the detected ones (override with `--agents`).
3. **OS-specific launch shape** — on Windows it writes `cmd /c npx @playwright/mcp@latest`; on Linux, plain `npx @playwright/mcp@latest`. All five agents accept the `cmd /c` shape.
4. **Merge MCP config, never clobber** — JSON configs (`omp`, `zcode`, `claude` fallback) are merged with a small `node` script that preserves the file's existing indentation. `codex` (TOML) and `hermes` (YAML) blocks are replaced/inserted by targeted `awk`. Anything unrelated in your config is left alone. `claude` prefers the official `claude mcp add -s user` CLI and only falls back to direct JSON editing if the CLI fails.
5. **Install skills** — copies each `skills/<name>/` directory into the agent's skills path, backing up any existing directory first.
6. **Idempotent + reversible** — identical state is detected and skipped; every modified file gets a `.bak.<timestamp>` backup; everything written is recorded in `~/.qa-skills-installer/manifest` so `--uninstall` removes exactly what this installer created (pre-existing skills and unrelated config keys are never touched).
7. **Pre-seed npx cache** — runs `npx -y @playwright/mcp@latest --version` once so the first browser launch in your agent doesn't stall on npx's install prompt.

### All options

```
./install.sh                       interactive confirm for detected agents
./install.sh --all                 all detected agents, no prompt
./install.sh --agents hermes,codex restrict to a subset
./install.sh --skills-only         skills only, no MCP config changes
./install.sh --mcp-only            MCP config only, no skill files
./install.sh --project             also write ./.mcp.json into the current repo (omp project scope)
./install.sh --dry-run             show everything, write nothing
./install.sh --uninstall --all     reverse what was installed (per-manifest)
./install.sh --help                full usage
```

---

## Requirements

- `node` / `npx` on PATH — the MCP server runs via npx; JSON configs are merged with node
- `curl` and `tar` for the piped one-liner (not needed from a clone)
- At least one supported agent installed (omp / hermes / claude / codex / zcode)

## Verify after install

Restart the agents, then:

```sh
claude mcp list                 # playwright — Connected
codex: start a session          # mcp_servers.playwright loaded from config.toml
hermes: start a session         # playwright tools available
zcode: Settings → MCP           # playwright connected
omp:   start a session          # playwright tools are deferred — fetch via tool_search
```

> **omp note:** omp keeps MCP tools out of the system prompt (deferred discovery). The `qa-playwright-core` skill's first step loads them via `tool_search` — that is expected behavior, not a missing server.

## Uninstall

```sh
./install.sh --uninstall --all
```

Removes exactly the skill directories and MCP entries recorded in `~/.qa-skills-installer/manifest` — pre-existing skills and unrelated config keys are never touched.

## Windows notes

- Use Git Bash (ships with Git for Windows). WSL counts as Linux and configures Linux-side agents only.
- All five agents accept the `cmd /c npx …` launch shape the installer writes on Windows.
- Configs live under `%USERPROFILE%` (`.codex`, `.zcode`, `.claude`, `.hermes`, `.omp`).

## License

Skill content: proprietary (see each `SKILL.md`). Installer: MIT.
