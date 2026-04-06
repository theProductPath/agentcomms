#!/usr/bin/env bash
# AgentComms v0.7 — setup.sh
# Bootstraps a local AgentComms instance.
# Usage: bash setup.sh [--path /path/to/destination] [--team "my team"]

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
TARGET="./AgentComms"
TEAM=""
FORCE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAFFOLD_DIR="$SCRIPT_DIR/scaffold"
DASHBOARD_SRC="$SCRIPT_DIR/dashboard"

# ─── Arg parsing ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      TARGET="$2"
      shift 2
      ;;
    --team)
      TEAM="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash setup.sh [--path /path/to/destination] [--team \"my team\"] [--force]" >&2
      exit 1
      ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────
ok()   { echo "  ✓ $*"; }
skip() { echo "  → Skipping existing: $*"; }
fail() { echo "  ✗ $*" >&2; }

make_dir() {
  local dir="$1"
  local rel="${dir#$TARGET/}"
  if [[ "$dir" == "$TARGET" ]]; then rel="."; fi
  if [[ -d "$dir" ]]; then return 0; fi
  if ! mkdir -p "$dir" 2>/tmp/agentcomms_err; then
    fail "Failed to create: $rel"
    echo "    $(cat /tmp/agentcomms_err)" >&2
    echo "" >&2
    echo "  Setup incomplete. Check directory permissions and try again." >&2
    exit 1
  fi
  ok "$rel/"
}

write_file() {
  local src="$1"
  local dest="$2"
  local rel="${dest#$TARGET/}"
  if [[ -f "$dest" ]]; then skip "$rel"; return 0; fi
  if ! cp "$src" "$dest" 2>/tmp/agentcomms_err; then
    fail "Failed to write: $rel"
    echo "    $(cat /tmp/agentcomms_err)" >&2
    exit 1
  fi
  ok "$rel"
}

# Slugify a string: lowercase, spaces→hyphens, strip special chars
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[[:space:]][[:space:]]*/\-/g' \
    | sed 's/[^a-z0-9-]//g' \
    | sed 's/--*/-/g' \
    | sed 's/^-//' \
    | sed 's/-$//'
}

# ─── Welcome header ──────────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────┐"
echo "│  AgentComms  ·  v0.8  ·  theProductPath          │"
echo "│  Local setup for your agent team                 │"
echo "└─────────────────────────────────────────────────┘"
echo ""

# ─── Prereq: bash version ────────────────────────────────────────────────────
BASH_MAJOR="${BASH_VERSINFO[0]}"
BASH_MINOR="${BASH_VERSINFO[1]}"
if [[ "$BASH_MAJOR" -lt 3 ]] || [[ "$BASH_MAJOR" -eq 3 && "$BASH_MINOR" -lt 2 ]]; then
  fail "Requires bash 3.2 or higher. Found: ${BASH_VERSION}"
  exit 1
fi

# ─── Prereq: scaffold dir ────────────────────────────────────────────────────
if [[ ! -d "$SCAFFOLD_DIR" ]]; then
  fail "Scaffold files not found at: $SCAFFOLD_DIR"
  echo "    Run setup.sh from the agentcomms repo root directory." >&2
  exit 1
fi

# ─── Resolve absolute target path ────────────────────────────────────────────
TARGET="${TARGET/#\~/$HOME}"
if [[ "$TARGET" != /* ]]; then
  TARGET="$(pwd)/$TARGET"
fi

echo "Setting up AgentComms in: $TARGET"
echo ""

# ─── Existing directory check ────────────────────────────────────────────────
if [[ -d "$TARGET" ]] && [[ -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
  if [[ "$FORCE" == "true" ]]; then
    echo "  ! Directory already exists: $TARGET"
    echo "  → --force flag set, proceeding without prompt."
    echo "  → Existing agent folders, threads, and archive will not be touched."
    echo ""
  else
    echo "  ! Directory already exists: $TARGET"
    echo ""
    echo "  This will add example files and the dashboard to your existing setup."
    echo "  Existing files will NOT be overwritten."
    echo ""
    printf "  Continue? [y/N] "
    REPLY=""
    read -r REPLY </dev/tty 2>/dev/null || true
    echo ""
    if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
      echo "  Aborted. No changes made."
      exit 0
    fi
    echo ""
  fi
fi

# ─── Compute mailbox identity ────────────────────────────────────────────────
TODAY="$(date +%Y-%m-%d)"
if [[ -n "$TEAM" ]]; then
  MAILBOX_NAME="$TEAM"
  MAILBOX_ID="$(slugify "$TEAM")"
else
  MAILBOX_NAME="My Team"
  MAILBOX_ID="mailbox-${TODAY//-/}"
fi

# ─── Step 1: Create directory structure ──────────────────────────────────────
echo "→ Creating folder structure..."
make_dir "$TARGET"
make_dir "$TARGET/agents"
make_dir "$TARGET/agents/example-agent"
make_dir "$TARGET/agents/example-agent/inbox"
make_dir "$TARGET/agents/example-agent/inbox/processed"
make_dir "$TARGET/threads"
make_dir "$TARGET/threads/2026-03-26_first-task"
make_dir "$TARGET/archive"
make_dir "$TARGET/archive/2026-03-26_completed-task"
make_dir "$TARGET/dashboard"
make_dir "$TARGET/scripts"
echo ""

# ─── Step 2: Write example files ─────────────────────────────────────────────
echo "→ Writing example files..."

write_file \
  "$SCAFFOLD_DIR/agents/example-agent/inbox/.keep" \
  "$TARGET/agents/example-agent/inbox/.keep"

write_file \
  "$SCAFFOLD_DIR/agents/example-agent/inbox/2026-03-26_first-signal.md" \
  "$TARGET/agents/example-agent/inbox/2026-03-26_first-signal.md"

write_file \
  "$SCAFFOLD_DIR/agents/example-agent/inbox/2026-03-26_second-signal.md" \
  "$TARGET/agents/example-agent/inbox/2026-03-26_second-signal.md"

write_file \
  "$SCAFFOLD_DIR/agents/example-agent/inbox/processed/.keep" \
  "$TARGET/agents/example-agent/inbox/processed/.keep"

write_file \
  "$SCAFFOLD_DIR/agents/example-agent/inbox/processed/2026-03-25_processed-example.md" \
  "$TARGET/agents/example-agent/inbox/processed/2026-03-25_processed-example.md"

write_file \
  "$SCAFFOLD_DIR/threads/2026-03-26_first-task/brief.md" \
  "$TARGET/threads/2026-03-26_first-task/brief.md"

write_file \
  "$SCAFFOLD_DIR/threads/2026-03-26_first-task/context.md" \
  "$TARGET/threads/2026-03-26_first-task/context.md"

write_file \
  "$SCAFFOLD_DIR/threads/2026-03-26_first-task/status.md" \
  "$TARGET/threads/2026-03-26_first-task/status.md"

write_file \
  "$SCAFFOLD_DIR/threads/2026-03-26_first-task/result.md" \
  "$TARGET/threads/2026-03-26_first-task/result.md"

write_file \
  "$SCAFFOLD_DIR/archive/2026-03-26_completed-task/brief.md" \
  "$TARGET/archive/2026-03-26_completed-task/brief.md"

write_file \
  "$SCAFFOLD_DIR/archive/2026-03-26_completed-task/context.md" \
  "$TARGET/archive/2026-03-26_completed-task/context.md"

write_file \
  "$SCAFFOLD_DIR/archive/2026-03-26_completed-task/status.md" \
  "$TARGET/archive/2026-03-26_completed-task/status.md"

write_file \
  "$SCAFFOLD_DIR/archive/2026-03-26_completed-task/result.md" \
  "$TARGET/archive/2026-03-26_completed-task/result.md"
echo ""

# ─── Step 3: Copy dashboard ──────────────────────────────────────────────────
echo "→ Copying dashboard..."
if [[ -d "$DASHBOARD_SRC" ]]; then
  for f in "$DASHBOARD_SRC"/*; do
    [[ -f "$f" ]] || continue
    fname="$(basename "$f")"
    write_file "$f" "$TARGET/dashboard/$fname"
  done
else
  echo "  → Dashboard source not found — skipping"
fi
echo ""

# ─── Step 3b: Create config/ and dispatcher.json ────────────────────────────
echo "→ Creating config folder..."
make_dir "$TARGET/config"

DISPATCHER_CONFIG="$TARGET/config/dispatcher.json"
if [[ ! -f "$DISPATCHER_CONFIG" ]]; then
  cat > "$DISPATCHER_CONFIG" << 'DISPATCHER_EOF'
{
  "jobId": "",
  "openclawBin": "openclaw",
  "enabled": true
}
DISPATCHER_EOF
  ok "config/dispatcher.json"
else
  skip "config/dispatcher.json"
fi
echo ""

# ─── Step 3c: Write instances.json for dashboard ────────────────────────────
echo "→ Writing instances.json..."
INSTANCES_FILE="$TARGET/dashboard/instances.json"
if [[ ! -f "$INSTANCES_FILE" ]]; then
  cat > "$INSTANCES_FILE" << INSTANCES_EOF
[{"key":"default","name":"AgentComms","path":"${TARGET}","builtin":true}]
INSTANCES_EOF
  ok "dashboard/instances.json"
else
  skip "dashboard/instances.json"
fi
echo ""

# ─── Step 3d: Copy scripts ───────────────────────────────────────────────────
echo "→ Copying scripts..."
SCRIPTS_SRC="$SCRIPT_DIR/scripts"
if [[ -d "$SCRIPTS_SRC" ]]; then
  for f in "$SCRIPTS_SRC"/*; do
    [[ -f "$f" ]] || continue
    fname="$(basename "$f")"
    write_file "$f" "$TARGET/scripts/$fname"
    chmod +x "$TARGET/scripts/$fname" 2>/dev/null || true
  done
else
  echo "  → Scripts source not found — skipping"
fi
echo ""

# ─── Step 4: Write MAILBOX.md ────────────────────────────────────────────────
echo "→ Writing MAILBOX.md..."
MAILBOX_FILE="$TARGET/MAILBOX.md"
if [[ ! -f "$MAILBOX_FILE" ]]; then
  cat > "$MAILBOX_FILE" << MAILBOX_EOF
# AgentComms Mailbox

mailbox-id: ${MAILBOX_ID}
mailbox-name: ${MAILBOX_NAME}
created: ${TODAY}
agentcomms-version: 1
MAILBOX_EOF
  ok "MAILBOX.md"
else
  skip "MAILBOX.md"
fi
echo ""

# ─── Step 4b: Write installer-path.txt at AC root ────────────────────────────
echo "→ Writing installer-path.txt..."
INSTALLER_PATH_FILE="$TARGET/installer-path.txt"
if [[ ! -f "$INSTALLER_PATH_FILE" ]]; then
  echo "$SCRIPT_DIR" > "$INSTALLER_PATH_FILE"
  ok "installer-path.txt"
else
  skip "installer-path.txt"
fi
echo ""

# ─── Step 5: Write agentcomms-version file (for backward compat) ─────────────
echo "→ Writing version tag..."
VERSION_FILE="$TARGET/agentcomms-version"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "1" > "$VERSION_FILE"
  ok "agentcomms-version"
else
  skip "agentcomms-version"
fi

# Also write to README if present (backward compat tag)
README_FILE="$TARGET/README.md"
if [[ -f "$README_FILE" ]]; then
  if ! grep -q "agentcomms-version:" "$README_FILE"; then
    sed -i '' '1a\
<!-- agentcomms-version: 1 -->
' "$README_FILE"
    ok "README.md version tag"
  else
    skip "README.md version tag (already present)"
  fi
else
  cat > "$README_FILE" << 'README_EOF'
<!-- agentcomms-version: 1 -->

# AgentComms · v0.7

*Local agent communication layer. See the repo for full documentation.*

---
For setup and usage instructions, see [theProductPath/agentcomms](https://github.com/theProductPath/agentcomms)
README_EOF
  ok "README.md"
fi
echo ""

# ─── Step 6: Write agents/MEMBERS.md ─────────────────────────────────────────
echo "→ Writing agents/MEMBERS.md..."
MEMBERS_FILE="$TARGET/agents/MEMBERS.md"
if [[ ! -f "$MEMBERS_FILE" ]]; then
  cat > "$MEMBERS_FILE" << MEMBERS_EOF
# Members — ${MAILBOX_NAME}

| Agent | Joined | Status |
|-------|--------|--------|
| example-agent | ${TODAY} | active |
MEMBERS_EOF
  ok "agents/MEMBERS.md"
else
  skip "agents/MEMBERS.md"
fi
echo ""

# ─── Step 7: Write protocol docs ─────────────────────────────────────────────
echo "→ Writing protocol docs..."
PROTOCOL_SRC="$SCRIPT_DIR/COMMUNICATION_PROTOCOL.md"
if [[ -f "$PROTOCOL_SRC" ]]; then
  write_file "$PROTOCOL_SRC" "$TARGET/COMMUNICATION_PROTOCOL.md"
else
  PROTOCOL_DEST="$TARGET/COMMUNICATION_PROTOCOL.md"
  if [[ ! -f "$PROTOCOL_DEST" ]]; then
    cat > "$PROTOCOL_DEST" << 'PROTOCOL_EOF'
# AgentComms Communication Protocol

*Reference for all agents using this AgentComms instance.*

---

## The Three Zones

| Zone | Path | Purpose |
|---|---|---|
| Inbox | `agents/<name>/inbox/` | Routing signals — pointer files only |
| Threads | `threads/` | All work — briefs, context, Q&A, results |
| Archive | `archive/` | Completed threads, permanent history |

---

## Signal Format

```
# Task Name — Brief Waiting

Thread: threads/YYYY-MM-DD_task-slug/
From: sender-agent
Priority: normal | high | urgent
Mailbox: <mailbox-id>  (optional)
```

---

## Status Values

```
open        — Created, not yet started
in-progress — Actively being worked
blocked     — Cannot proceed (signal the blocker's inbox)
done        — Work complete, result.md written
```

---

*AgentComms v0.7 · theProductPath*
PROTOCOL_EOF
    ok "COMMUNICATION_PROTOCOL.md"
  else
    skip "COMMUNICATION_PROTOCOL.md"
  fi
fi
echo ""

# ─── Success ─────────────────────────────────────────────────────────────────
echo "─────────────────────────────────────────────────────"
echo "  AgentComms is ready."
echo ""
echo "  Location:    $TARGET"
echo "  Mailbox:     $MAILBOX_ID  ($MAILBOX_NAME)"
echo "  Dashboard:   bash $TARGET/dashboard/start.sh"
echo "               → Starts at http://localhost:7843"
echo ""
echo "  Folder Structure:"
echo "    agents/                      Your team's agent inboxes"
echo "    threads/                     Active work"
echo "    archive/                     Completed tasks"
echo "    dashboard/                   Web UI + server"
echo "    scripts/                     Operator tools"
echo ""
echo "  Example content:"
echo "    agents/example-agent/        Example agent with inbox signals"
echo "    Completed mission with full artifact trail in archive/"
echo ""
echo "  Operator Tools:"
echo "    bash $TARGET/scripts/add-agent.sh <name>  — add a new agent to this mailbox"
echo "    bash $TARGET/scripts/inbox-snapshot.sh   — inbox status report"
echo "    bash $TARGET/scripts/wake.sh <agent>      — wake an agent manually"
echo "    bash $TARGET/scripts/reset.sh             — wipe to clean or restore example"
if [[ -f "$TARGET/scripts/teardown.sh" ]]; then
echo "    bash $TARGET/scripts/teardown.sh          — close this mailbox"
fi
echo ""
echo "  Dispatcher:  Edit AgentComms/config/dispatcher.json to enable the"
echo "               dispatcher toggle (set jobId to your OpenClaw cron job ID)."
echo "               Run: openclaw cron list   to find your job ID."
echo ""
echo "  Next step:   See AGENT-ONBOARDING.md to add your first agent."
echo "─────────────────────────────────────────────────────"
echo ""
