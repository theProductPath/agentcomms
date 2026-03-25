#!/usr/bin/env bash
# AgentComms v0.5 — setup.sh
# Bootstraps a local AgentComms instance.
# Usage: bash setup.sh [--path /path/to/destination] [--team "my team"]

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
TARGET="./AgentComms"
TEAM="your team"
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
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash setup.sh [--path /path/to/destination] [--team \"my team\"]" >&2
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
  if [[ "$dir" == "$TARGET" ]]; then
    rel="."
  fi
  if [[ -d "$dir" ]]; then
    return 0
  fi
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
  if [[ -f "$dest" ]]; then
    skip "$rel"
    return 0
  fi
  if ! cp "$src" "$dest" 2>/tmp/agentcomms_err; then
    fail "Failed to write: $rel"
    echo "    $(cat /tmp/agentcomms_err)" >&2
    echo "" >&2
    echo "  Setup incomplete. Free disk space and try again." >&2
    exit 1
  fi
  ok "$rel"
}

# ─── Welcome header ──────────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────┐"
echo "│  AgentComms  ·  v0.5  ·  theProductPath          │"
echo "│  Local setup for your agent team                 │"
echo "└─────────────────────────────────────────────────┘"
echo ""

# ─── Prereq: bash version ────────────────────────────────────────────────────
# Requires bash ≥ 3.2 (macOS system bash is 3.2; all features used are compatible)
BASH_MAJOR="${BASH_VERSINFO[0]}"
BASH_MINOR="${BASH_VERSINFO[1]}"
if [[ "$BASH_MAJOR" -lt 3 ]] || [[ "$BASH_MAJOR" -eq 3 && "$BASH_MINOR" -lt 2 ]]; then
  fail "Requires bash 3.2 or higher. Found: ${BASH_VERSION}"
  echo "    On macOS, install with: brew install bash" >&2
  echo "" >&2
  echo "  Setup aborted." >&2
  exit 1
fi

# ─── Prereq: scaffold dir ────────────────────────────────────────────────────
if [[ ! -d "$SCAFFOLD_DIR" ]]; then
  fail "Scaffold files not found at: $SCAFFOLD_DIR"
  echo "    Run setup.sh from the agentcomms repo root directory." >&2
  echo "" >&2
  echo "  Setup aborted." >&2
  exit 1
fi

# ─── Resolve absolute target path ────────────────────────────────────────────
# Expand ~ if present
TARGET="${TARGET/#\~/$HOME}"
# Make absolute
if [[ "$TARGET" != /* ]]; then
  TARGET="$(pwd)/$TARGET"
fi

echo "Setting up AgentComms in: $TARGET"
echo ""

# ─── Existing directory check ────────────────────────────────────────────────
if [[ -d "$TARGET" ]] && [[ -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
  echo "  ! Directory already exists: $TARGET"
  echo ""
  echo "  This will add example files and the dashboard to your existing setup."
  echo "  Existing files will NOT be overwritten."
  echo ""
  printf "  Continue? [y/N] "
  read -r REPLY
  if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
    echo ""
    echo "  Aborted. No changes made."
    exit 0
  fi
  echo ""
fi

# ─── Step 1: Create directory structure ──────────────────────────────────────
echo "→ Creating folder structure..."
make_dir "$TARGET"
make_dir "$TARGET/agents"
make_dir "$TARGET/agents/example-agent"
make_dir "$TARGET/agents/example-agent/inbox"
make_dir "$TARGET/agents/example-agent/inbox/processed"
make_dir "$TARGET/agents/example-agent/outbox"
make_dir "$TARGET/threads"
make_dir "$TARGET/threads/2026-01-01_example-thread"
make_dir "$TARGET/archive"
make_dir "$TARGET/archive/2026-01-01_example-completed"
make_dir "$TARGET/dashboard"
echo ""

# ─── Step 2: Write example files ─────────────────────────────────────────────
echo "→ Writing example files..."
write_file \
  "$SCAFFOLD_DIR/agents/example-agent/inbox/2026-01-01_example-signal.md" \
  "$TARGET/agents/example-agent/inbox/2026-01-01_example-signal.md"

write_file \
  "$SCAFFOLD_DIR/agents/example-agent/inbox/processed/.keep" \
  "$TARGET/agents/example-agent/inbox/processed/.keep"

write_file \
  "$SCAFFOLD_DIR/agents/example-agent/outbox/.keep" \
  "$TARGET/agents/example-agent/outbox/.keep"

write_file \
  "$SCAFFOLD_DIR/threads/2026-01-01_example-thread/brief.md" \
  "$TARGET/threads/2026-01-01_example-thread/brief.md"

write_file \
  "$SCAFFOLD_DIR/threads/2026-01-01_example-thread/context.md" \
  "$TARGET/threads/2026-01-01_example-thread/context.md"

write_file \
  "$SCAFFOLD_DIR/threads/2026-01-01_example-thread/status.md" \
  "$TARGET/threads/2026-01-01_example-thread/status.md"

write_file \
  "$SCAFFOLD_DIR/threads/2026-01-01_example-thread/result.md" \
  "$TARGET/threads/2026-01-01_example-thread/result.md"

write_file \
  "$SCAFFOLD_DIR/archive/2026-01-01_example-completed/brief.md" \
  "$TARGET/archive/2026-01-01_example-completed/brief.md"

write_file \
  "$SCAFFOLD_DIR/archive/2026-01-01_example-completed/status.md" \
  "$TARGET/archive/2026-01-01_example-completed/status.md"

write_file \
  "$SCAFFOLD_DIR/archive/2026-01-01_example-completed/result.md" \
  "$TARGET/archive/2026-01-01_example-completed/result.md"
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
  echo "  → Dashboard source not found — skipping (will be added in Phase 2)"
fi
echo ""

# ─── Step 4: Write protocol docs ─────────────────────────────────────────────
echo "→ Writing protocol docs..."
PROTOCOL_SRC="$SCRIPT_DIR/COMMUNICATION_PROTOCOL.md"
if [[ -f "$PROTOCOL_SRC" ]]; then
  write_file "$PROTOCOL_SRC" "$TARGET/COMMUNICATION_PROTOCOL.md"
else
  # Inline fallback — generate COMMUNICATION_PROTOCOL.md directly
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

## The Five Protocols

### 1. Brief-First
Every task starts with a `brief.md` in a thread folder. No brief = no task. The brief must contain: What, Why, Constraints, Done When.

### 2. Inbox as Signal
Inbox files are tiny pointer files — they tell the recipient where to find the work (the thread folder). Never put full briefs or deliverables in an inbox file.

**Signal format:**
```
# Task Name — Brief Waiting
Thread: threads/YYYY-MM-DD_slug/
From: sender-name
Priority: normal | high | urgent
```

### 3. Q&A in Thread
All questions and answers about a task go in the thread folder as `HHMMSS_from-to.md` files. Never use external channels (chat, email) for task Q&A — keep it in the thread so there's a record.

### 4. Done = Archived
A task is not truly done until:
1. `result.md` is written in the thread folder
2. `status.md` is updated to `status: done`
3. The thread folder is moved from `threads/` to `archive/`

The archive is permanent institutional memory. Nothing is ever deleted.

### 5. Inbox Monitoring
Agents are responsible for checking their inbox regularly. Process inbox signals oldest-first. Move each signal to `processed/` after reading. Verify the move before proceeding.

---

## File Naming Conventions

| Type | Format | Example |
|---|---|---|
| Thread folders | `YYYY-MM-DD_descriptive-slug` | `2026-03-24_redesign-onboarding` |
| Inbox signals | `YYYY-MM-DD_task-slug.md` | `2026-03-24_redesign-onboarding.md` |
| Q&A files | `HHMMSS_sender-recipient.md` | `143022_ac-dev-ac-pm.md` |
| Agent folders | lowercase, hyphenated | `ac-dev`, `ops-agent` |

---

## Status Values

```
open        — Created, not yet started
in-progress — Actively being worked
blocked     — Cannot proceed (signal the blocker's inbox)
done        — Work complete, result.md written
```

---

*AgentComms v0.5 · theProductPath*
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
echo "  Dashboard:   node $TARGET/dashboard/server.js"
echo "               → http://localhost:7842"
echo ""
echo "  Examples:    $TARGET/agents/example-agent/"
echo "               $TARGET/threads/2026-01-01_example-thread/"
echo ""
echo "  Next step:   See AGENT-ONBOARDING.md to add your first agent."
echo "─────────────────────────────────────────────────────"
echo ""
