#!/bin/sh
# =============================================================================
# QA-skills installer
# Registers the Playwright MCP server and installs the qa-playwright* skills
# for: omp, hermes, claude (Claude Code), codex, zcode.
# Runs on Linux (bash/dash/WSL) and Windows (Git Bash / MSYS2).
#
# Usage:
#   ./install.sh                       interactive confirm for detected agents
#   ./install.sh --all                 all detected agents, no prompt
#   ./install.sh --agents hermes,codex restrict to a subset
#   ./install.sh --skills-only         skills only, no MCP config changes
#   ./install.sh --mcp-only            MCP config only, no skill files
#   ./install.sh --project             also write ./.mcp.json (omp project scope)
#   ./install.sh --dry-run             show what would happen, change nothing
#   ./install.sh --uninstall [--all | --agents ...] [--skills-only|--mcp-only]
#
# Every modified file gets a sibling .bak.<timestamp> backup. Re-runs are
# idempotent: identical state is detected and left untouched.
# =============================================================================
set -u

REPO_OWNER="CHANGE_ME"
REPO_NAME="QA-skills"
REPO_BRANCH="main"
MCP_PACKAGE="@playwright/mcp@latest"
SKILL_NAMES='qa-playwright qa-playwright-core qa-playwright-branch-features qa-playwright-forms-auth qa-playwright-i18n-rtl qa-playwright-responsive qa-playwright-ssr-seo'
ALL_AGENTS='omp hermes claude codex zcode'
STATE_DIR="${QA_SKILLS_INSTALL_DIR:-$HOME/.qa-skills-installer}"
MANIFEST="$STATE_DIR/manifest"

DRY=0; UNINSTALL=0; ASSUME_YES=0; DO_MCP=1; DO_SKILLS=1; DO_PROJECT=0
AGENTS=''; TARGETS=''

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- bootstrap: fetch the repo when piped (curl | sh) or run outside a checkout
SELF_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || SELF_DIR=''
if [ ! -f "$SELF_DIR/skills/qa-playwright-core/SKILL.md" ]; then
  [ "$REPO_OWNER" != "CHANGE_ME" ] || die "REPO_OWNER is not set in install.sh"
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v tar >/dev/null 2>&1 || die "tar is required"
  TMP=$(mktemp -d) || die "mktemp failed"
  log "Fetching https://github.com/$REPO_OWNER/$REPO_NAME (branch $REPO_BRANCH)..."
  curl -fsSL "https://codeload.github.com/$REPO_OWNER/$REPO_NAME/tar.gz/$REPO_BRANCH" | tar -xz -C "$TMP" ||
    die "could not download repo tarball"
  for f in "$TMP"/*/install.sh; do
    [ -f "$f" ] && exec sh "$f" "$@"
  done
  die "downloaded tarball has no install.sh"
fi
SCRIPT_DIR="$SELF_DIR"

# --- OS-specific MCP launch shape -------------------------------------------
os_is_windows() { case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) return 0 ;; *) return 1 ;; esac; }

if os_is_windows; then
  # Windows cannot exec the npx shim directly; launch through cmd.
  MCP_COMMAND='cmd'
  MCP_ARGS_JSON='["/c","npx","@playwright/mcp@latest"]'
  MCP_TOML_ARGS='["/c", "npx", "@playwright/mcp@latest"]'
  MCP_YAML_COMMAND='cmd'
  MCP_YAML_ARGS="      - /c
      - npx
      - '$MCP_PACKAGE'"
  MCP_ADD_ARGS='cmd /c npx @playwright/mcp@latest'
else
  MCP_COMMAND='npx'
  MCP_ARGS_JSON='["@playwright/mcp@latest"]'
  MCP_TOML_ARGS='["@playwright/mcp@latest"]'
  MCP_YAML_COMMAND='npx'
  MCP_YAML_ARGS="      - '$MCP_PACKAGE'"
  MCP_ADD_ARGS="npx $MCP_PACKAGE"
fi

TS=$(date +%Y%m%d%H%M%S)

# --- generic helpers ----------------------------------------------------------
stage_path() { # stage_path <dest>  -> temp file next to dest (same-fs mv) or /tmp on dry-run
  if [ "$DRY" = 1 ]; then mktemp "${TMPDIR:-/tmp}/qa-skills.XXXXXX"
  else mkdir -p "$(dirname -- "$1")" && mktemp "$(dirname -- "$1")/.qa-skills.XXXXXX"
  fi
}

record() { # record <manifest-line>  (skipped on dry-run)
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$1" >>"$MANIFEST"
}

commit_file() { # commit_file <staged> <dest> <label>
  _staged=$1; _dest=$2; _label=$3
  if [ -f "$_dest" ] && cmp -s "$_staged" "$_dest"; then
    log "    = $_label: already up to date"
    rm -f "$_staged"; return 0
  fi
  if [ "$DRY" = 1 ]; then
    if [ -f "$_dest" ]; then
      _n=$(diff -- "$_dest" "$_staged" 2>/dev/null | grep -c '^[<>]')
    else
      _n=$(grep -c '' "$_staged")
    fi
    log "    ~ [$_label] would write $_dest ($_n changed lines)"
    rm -f "$_staged"; return 0
  fi
  if [ -f "$_dest" ]; then
    _bak="$_dest.bak.$TS"
    cp -p "$_dest" "$_bak" && log "    + $_label: backup -> $_bak"
  else
    log "    + $_label: created $_dest"
    record "created $_dest"
  fi
  mv -f "$_staged" "$_dest"
  return 0
}

# --- node JSON helpers --------------------------------------------------------
node_json_merge() { # node_json_merge <dest> <js-body(cfg,cmd,args)> <label>
  _dest=$1; _js=$2; _label=$3
  command -v node >/dev/null 2>&1 || die "node is required to edit $_dest"
  _stage=$(stage_path "$_dest") || die "mktemp failed"
  QA_CMD="$MCP_COMMAND" QA_ARGS="$MCP_ARGS_JSON" node -e '
    const fs = require("fs");
    const dest = process.argv[1], stage = process.argv[2], js = process.argv[3];
    let cfg = {};
    try { cfg = JSON.parse(fs.readFileSync(dest, "utf8")); }
    catch (e) { if (e.code !== "ENOENT") { console.error("parse error: " + e.message); process.exit(3); } }
    const cmd = process.env.QA_CMD;
    const args = JSON.parse(process.env.QA_ARGS);
    new Function("cfg", "cmd", "args", js)(cfg, cmd, args);
    fs.writeFileSync(stage, JSON.stringify(cfg, null, 2) + "\n");
  ' "$_dest" "$_stage" "$_js" || { rm -f "$_stage"; die "JSON merge failed for $_dest (file left untouched)"; }
  commit_file "$_stage" "$_dest" "$_label"
}

node_json_check() { # node_json_check <file> <dot.path> -> 0 when entry matches cmd/args
  QA_CMD="$MCP_COMMAND" QA_ARGS="$MCP_ARGS_JSON" node -e '
    const fs = require("fs");
    let cfg; try { cfg = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { process.exit(2); }
    let o = cfg;
    for (const k of process.argv[2].split(".")) {
      if (o == null || typeof o !== "object" || !(k in o)) process.exit(1);
      o = o[k];
    }
    const cmd = process.env.QA_CMD, args = JSON.parse(process.env.QA_ARGS);
    if (o && typeof o === "object" && o.command === cmd &&
        JSON.stringify(o.args) === JSON.stringify(args) && o.enabled !== false) process.exit(0);
    process.exit(1);
  ' "$1" "$2"
}

# --- expected blocks ----------------------------------------------------------
codex_expected_block() {
  printf '[mcp_servers.playwright]\ncommand = "%s"\nargs = %s\n' "$MCP_COMMAND" "$MCP_TOML_ARGS"
}
hermes_expected_block() {
  printf '  playwright:\n    command: %s\n    args:\n%s\n    enabled: true\n' "$MCP_YAML_COMMAND" "$MCP_YAML_ARGS"
}

# --- MCP writers (one per agent, all idempotent) -------------------------------
mcp_claude() {
  log '  [claude]'
  f="$HOME/.claude.json"
  if command -v claude >/dev/null 2>&1; then
    if claude mcp get playwright >/dev/null 2>&1; then
      log '    = playwright already registered (claude CLI)'
      return 0
    fi
    if [ "$DRY" = 1 ]; then
      log "    ~ would run: claude mcp add -s user playwright -- $MCP_ADD_ARGS"
      return 0
    fi
    # shellcheck disable=SC2086
    if claude mcp add -s user playwright -- $MCP_ADD_ARGS >/dev/null 2>&1 &&
      claude mcp get playwright >/dev/null 2>&1; then
      log '    + playwright registered via claude CLI'
      record "mcp claude $f"
      return 0
    fi
    log '    ! claude CLI failed; falling back to direct JSON edit'
  fi
  if node_json_check "$f" mcpServers.playwright; then
    log '    = already up to date'
    return 0
  fi
  record "mcp claude $f"
  node_json_merge "$f" 'cfg.mcpServers = cfg.mcpServers || {}; cfg.mcpServers.playwright = { command: cmd, args: args };' claude
}

mcp_zcode() {
  log '  [zcode]'
  f="$HOME/.zcode/cli/config.json"
  if node_json_check "$f" mcp.servers.playwright; then
    log '    = already up to date'
    return 0
  fi
  record "mcp zcode $f"
  # zcode's schema is strict: exactly type/command/args/enabled, nothing else.
  node_json_merge "$f" 'cfg.mcp = cfg.mcp || {}; cfg.mcp.servers = cfg.mcp.servers || {}; cfg.mcp.servers.playwright = { type: "stdio", command: cmd, args: args, enabled: true };' zcode
}

mcp_codex() {
  log '  [codex]'
  f="$HOME/.codex/config.toml"
  exp=$(codex_expected_block)
  exp_body=$(printf '%s' "$exp" | sed 1d | tr -d '\r')
  cur=''
  [ -f "$f" ] && cur=$(awk '
    $0 == "[mcp_servers.playwright]" { inb = 1; next }
    inb && /^\[/ { exit }
    inb { print }
  ' "$f" | tr -d '\r')
  if [ "$cur" = "$exp_body" ]; then
    log '    = already up to date'
    return 0
  fi
  if [ "$DRY" = 1 ]; then
    log "    ~ [codex] would write the [mcp_servers.playwright] block into $f"
    return 0
  fi
  record "mcp codex $f"
  _stage=$(stage_path "$f") || die 'mktemp failed'
  if [ -n "$cur" ] || grep -q '^\[mcp_servers\.playwright\]' "$f" 2>/dev/null; then
    awk -v blk="$exp" '
      BEGIN { n = split(blk, L, "\n") }
      $0 == "[mcp_servers.playwright]" && !done {
        for (i = 1; i < n; i++) print L[i]
        done = 1; inb = 1; next
      }
      inb && /^\[/ { inb = 0 }
      inb { next }
      { print }
    ' "$f" >"$_stage"
  else
    { awk '1' "$f" 2>/dev/null; printf '\n%s\n' "$exp"; } >"$_stage"
  fi
  commit_file "$_stage" "$f" codex
}

mcp_hermes() {
  log '  [hermes]'
  f="$HOME/.hermes/config.yaml"
  exp=$(hermes_expected_block | tr -d '\r')
  cur=''
  [ -f "$f" ] && cur=$(awk '
    /^  playwright:/ { f = 1; print; next }
    f && NF {
      lead = $0; sub(/^[ \t]+/, "", lead)
      if (length($0) - length(lead) < 4) exit
    }
    f { print }
  ' "$f" 2>/dev/null | tr -d '\r')
  if [ "$cur" = "$exp" ]; then
    log '    = already up to date'
    return 0
  fi
  if [ "$DRY" = 1 ]; then
    log "    ~ [hermes] would write the mcp_servers.playwright block into $f"
    return 0
  fi
  record "mcp hermes $f"
  _stage=$(stage_path "$f") || die 'mktemp failed'
  if printf '%s\n' "$cur" | grep -q 'playwright'; then
    # block exists but differs -> replace in place
    awk -v blk="$exp" '
      BEGIN { n = split(blk, L, "\n") }
      /^  playwright:/ && !done {
        for (i = 1; i < n; i++) print L[i]
        done = 1; inb = 1; next
      }
      inb && NF {
        lead = $0; sub(/^[ \t]+/, "", lead)
        if (length($0) - length(lead) < 4) { inb = 0; print; next }
      }
      inb { next }
      { print }
    ' "$f" >"$_stage"
  elif grep -q '^mcp_servers:' "$f" 2>/dev/null; then
    awk -v blk="$exp" '
      !done && /^mcp_servers:/ { print; printf "%s\n", blk; done = 1; next }
      { print }
    ' "$f" >"$_stage"
  else
    { awk '1' "$f" 2>/dev/null; printf '\nmcp_servers:\n%s\n' "$exp"; } >"$_stage"
  fi
  commit_file "$_stage" "$f" hermes
}

mcp_omp_project() {
  f="$PWD/.mcp.json"
  log "  [omp project scope] $f"
  if node_json_check "$f" mcpServers.playwright; then
    log '    = already up to date'
    return 0
  fi
  record "mcp omp-project $f"
  node_json_merge "$f" 'cfg.mcpServers = cfg.mcpServers || {}; cfg.mcpServers.playwright = { command: cmd, args: args };' 'omp .mcp.json'
}

# --- skills -------------------------------------------------------------------
skills_dest() {
  case $1 in
    omp) printf '%s' "$HOME/.omp/skills" ;;
    hermes) printf '%s' "$HOME/.hermes/skills/qa" ;;
    claude) printf '%s' "$HOME/.claude/skills" ;;
    codex) printf '%s' "$HOME/.codex/skills" ;;
    zcode) printf '%s' "$HOME/.zcode/skills" ;;
  esac
}

install_skills_for() {
  _a=$1
  _root=$(skills_dest "$_a")
  log "  [skills] -> $_root"
  _same=0; _chg=0
  for s in $SKILL_NAMES; do
    src="$SCRIPT_DIR/skills/$s"
    dst="$_root/$s"
    [ -d "$src" ] || die "repo is missing skills/$s"
    if [ -d "$dst" ] && diff -rq -- "$src" "$dst" >/dev/null 2>&1; then
      _same=$((_same + 1))
      continue
    fi
    if [ "$DRY" = 1 ]; then
      log "    ~ would install $s"
      _chg=$((_chg + 1))
      continue
    fi
    if [ -d "$dst" ]; then
      mv "$dst" "$dst.bak.$TS" && log "    + backup -> $dst.bak.$TS"
    fi
    mkdir -p "$_root"
    cp -R "$src" "$dst"
    record "skill $dst"
    _chg=$((_chg + 1))
  done
  log "    $_same/7 already identical, $_chg changed"
}

# --- uninstall -----------------------------------------------------------------
uninstall_all() {
  if [ ! -f "$MANIFEST" ]; then
    log "No manifest at $MANIFEST — this installer has not recorded anything."
    return 0
  fi
  log "Uninstalling (manifest: $MANIFEST)"
  while read -r kind p _rest; do
    [ "$kind" = skill ] || continue
    if [ -d "$p" ]; then
      if [ "$DRY" = 1 ]; then log "  ~ would remove $p"; else rm -rf "$p"; log "  - removed $p"; fi
    fi
  done <"$MANIFEST"
  while read -r kind agent p; do
    [ "$kind" = mcp ] || continue
    case $agent in
      claude|omp-project)
        if node_json_check "$p" mcpServers.playwright 2>/dev/null || [ -f "$p" ]; then
          if [ "$DRY" = 1 ]; then log "  ~ would remove playwright from $p"
          else
            if [ "$agent" = claude ] && command -v claude >/dev/null 2>&1; then
              claude mcp remove -s user playwright >/dev/null 2>&1 && log '  - claude: playwright removed via CLI'
            fi
            node_json_merge "$p" 'if (cfg.mcpServers) delete cfg.mcpServers.playwright;' "uninstall-$agent"
          fi
        fi
        ;;
      zcode)
        [ "$DRY" = 1 ] && { log "  ~ would remove playwright from $p"; break; }
        node_json_merge "$p" 'if (cfg.mcp && cfg.mcp.servers) delete cfg.mcp.servers.playwright;' uninstall-zcode
        ;;
      codex)
        if [ -f "$p" ] && grep -q '^\[mcp_servers\.playwright\]' "$p"; then
          if [ "$DRY" = 1 ]; then log "  ~ would remove block from $p"
          else
            _stage=$(stage_path "$p") || die 'mktemp failed'
            awk '
              $0 == "[mcp_servers.playwright]" { inb = 1; next }
              inb && /^\[/ { inb = 0 }
              inb { next }
              { print }
            ' "$p" >"$_stage"
            commit_file "$_stage" "$p" uninstall-codex
          fi
        fi
        ;;
      hermes)
        if [ -f "$p" ] && awk '/^  playwright:/ { f = 1 } f { exit 0 } END { exit f ? 0 : 1 }' "$p"; then
          if [ "$DRY" = 1 ]; then log "  ~ would remove block from $p"
          else
            _stage=$(stage_path "$p") || die 'mktemp failed'
            awk '
              /^  playwright:/ { inb = 1; next }
              inb && NF {
                lead = $0; sub(/^[ \t]+/, "", lead)
                if (length($0) - length(lead) < 4) { inb = 0; print; next }
              }
              inb { next }
              { print }
            ' "$p" >"$_stage"
            commit_file "$_stage" "$p" uninstall-hermes
          fi
        fi
        ;;
    esac
  done <"$MANIFEST"
  while read -r kind p; do
    [ "$kind" = created ] || continue
    if [ "$DRY" = 1 ]; then log "  ~ would remove created file $p"
    else rm -f "$p" && log "  - removed $p"; fi
  done <"$MANIFEST"
  if [ "$DRY" = 0 ]; then
    rm -f "$MANIFEST"
    log 'Manifest cleared.'
  fi
}

# --- agent detection ------------------------------------------------------------
agent_detected() {
  case $1 in
    hermes) [ -f "$HOME/.hermes/config.yaml" ] || command -v hermes >/dev/null 2>&1 ;;
    omp) [ -d "$HOME/.omp" ] || command -v omp >/dev/null 2>&1 ;;
    claude) [ -f "$HOME/.claude.json" ] || [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1 ;;
    codex) [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1 ;;
    zcode) [ -d "$HOME/.zcode" ] ;;
    *) return 1 ;;
  esac
}

usage() { sed -n '2,25p' "$SCRIPT_DIR/install.sh" | sed 's/^# \{0,1\}//'; }

# --- CLI parsing -----------------------------------------------------------------
while [ $# -gt 0 ]; do
  case $1 in
    --all | --yes | -y) ASSUME_YES=1 ;;
    --agents) [ $# -ge 2 ] || die '--agents needs a value'; AGENTS=$2; shift ;;
    --agents=*) AGENTS=${1#--agents=} ;;
    --skills-only) DO_MCP=0 ;;
    --mcp-only) DO_SKILLS=0 ;;
    --project) DO_PROJECT=1 ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

if [ "$UNINSTALL" = 1 ]; then
  uninstall_all
  exit 0
fi

# --- resolve target agents ---------------------------------------------------------
if [ -n "$AGENTS" ]; then
  OLDIFS=$IFS; IFS=','
  for a in $AGENTS; do
    ok=0
    for b in $ALL_AGENTS; do [ "$a" = "$b" ] && ok=1; done
    [ "$ok" = 1 ] || die "unknown agent '$a' (known:$ALL_AGENTS)"
    case " $TARGETS " in *" $a "*) ;; *) TARGETS="$TARGETS $a" ;; esac
  done
  IFS=$OLDIFS
else
  for b in $ALL_AGENTS; do agent_detected "$b" && TARGETS="$TARGETS $b"; done
fi
TARGETS=${TARGETS# }
[ -n "$TARGETS" ] || die "no supported agents detected (looked for:$ALL_AGENTS). Install an agent first or pass --agents."

log "QA-skills installer"
log "  agents :$TARGETS"
log "  mcp    : npx $MCP_PACKAGE $(os_is_windows && echo '(via cmd /c)')"
log "  skills : $(echo "$SKILL_NAMES" | wc -w) qa-playwright* skills"
log ""

if [ "$ASSUME_YES" = 0 ]; then
  if [ ! -t 0 ]; then
    die "non-interactive session: pass --all (or --agents ...) to proceed"
  fi
  printf '%s' "Proceed with the above? [Y/n] "
  read -r _ans || die aborted
  case $_ans in n* | N*) die aborted ;; esac
fi

# --- preflight -----------------------------------------------------------------------
if [ "$DO_MCP" = 1 ]; then
  command -v node >/dev/null 2>&1 || die "node is required (needed for JSON config edits)"
  command -v npx >/dev/null 2>&1 || die "npx is required (the Playwright MCP server runs via npx)"
  if [ "$DRY" = 0 ]; then
    log "Pre-seeding npx cache for $MCP_PACKAGE (avoids the first-run npx prompt)..."
    if npx -y "$MCP_PACKAGE" --version >/dev/null 2>&1; then
      log '  ok'
    else
      log "  WARN: could not execute $MCP_PACKAGE --version; the server may still work from your agents"
    fi
  fi
  log ''
fi

# --- install ---------------------------------------------------------------------------
for a in $TARGETS; do
  log "[$a]"
  if [ "$DO_MCP" = 1 ]; then
    case $a in
      claude) mcp_claude ;;
      zcode) mcp_zcode ;;
      codex) mcp_codex ;;
      hermes) mcp_hermes ;;
      omp) : ;; # omp MCP is handled by --project (see README) or the shared hermes entry
    esac
  fi
  [ "$DO_SKILLS" = 1 ] && install_skills_for "$a"
  log ''
done

if [ "$DO_PROJECT" = 1 ] && [ "$DO_MCP" = 1 ]; then
  log '[omp project scope]'
  mcp_omp_project
  log ''
fi

log "Done.$([ "$DRY" = 1 ] && echo ' (dry run — nothing was written)')"
log 'Restart your agents, then verify:'
log '  claude mcp list          -> playwright'
log '  zcode: Settings -> MCP   -> playwright connected'
log '  codex/hermes/omp: start a session and ask for playwright browser tools'
