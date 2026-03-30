#!/usr/bin/env bash
# AgentComms v0.9 — run-demo.sh
# One command to set up and load the Research & Write demo mission.
# Verbose output at each step. Ends with instructions for the operator.
#
# Usage:
#   bash implementations/openclaw/run-demo.sh [--agentcomms-root /path/to/AgentComms] [--model <id>]

set -euo pipefail

# ─── Root resolution ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMPL_DIR="$SCRIPT_DIR"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# ─── Defaults ────────────────────────────────────────────────────────────────
AC_ROOT=""
MODEL_OVERRIDE=""

# ─── Arg parsing ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agentcomms-root)
      AC_ROOT="$2"
      shift 2
      ;;
    --model)
      MODEL_OVERRIDE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash run-demo.sh [--agentcomms-root /path] [--model anthropic/claude-haiku-4-5]" >&2
      exit 1
      ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────
step()    { echo ""; echo "▸ $*"; }
ok()      { echo "  ✓ $*"; }
info()    { echo "  → $*"; }
warn()    { echo "  ⚠  $*"; }
fail()    { echo "  ✗ $*" >&2; }

# ─── Welcome ─────────────────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│  AgentComms · v0.9 · Research & Write Demo           │"
echo "│  OpenClaw implementation — theProductPath            │"
echo "└─────────────────────────────────────────────────────┘"
echo ""

# ─── Step 1: Prerequisites ────────────────────────────────────────────────────
step "Step 1 — Checking prerequisites"

# Check openclaw — hard requirement
if command -v openclaw >/dev/null 2>&1; then
  ok "openclaw found: $(which openclaw)"
else
  echo "" >&2
  echo "✗ OpenClaw is required to run this demo." >&2
  echo "" >&2
  echo "  This demo uses OpenClaw to register agents and fire sessions." >&2
  echo "  Without it, agents can receive signals but won't activate." >&2
  echo "" >&2
  echo "  Install OpenClaw: https://openclaw.ai" >&2
  echo "" >&2
  echo "  Once installed, re-run:" >&2
  echo "    bash implementations/openclaw/run-demo.sh --agentcomms-root $AC_ROOT" >&2
  echo "" >&2
  exit 1
fi

# Resolve AgentComms root
if [[ -z "$AC_ROOT" ]]; then
  if [[ -f "$HOME/AgentComms/MAILBOX.md" ]]; then
    AC_ROOT="$HOME/AgentComms"
  elif [[ -f "$(pwd)/MAILBOX.md" ]]; then
    AC_ROOT="$(pwd)"
  else
    echo "" >&2
    fail "Could not detect AgentComms root."
    echo "" >&2
    echo "  Pass it explicitly:" >&2
    echo "    bash implementations/openclaw/run-demo.sh --agentcomms-root /path/to/AgentComms" >&2
    echo "" >&2
    echo "  Or run setup.sh first:" >&2
    echo "    bash setup.sh --path ~/AgentComms" >&2
    echo "" >&2
    exit 1
  fi
fi

AC_ROOT="${AC_ROOT/#\~/$HOME}"

if [[ ! -f "$AC_ROOT/MAILBOX.md" ]]; then
  fail "Not a valid AgentComms root: $AC_ROOT (MAILBOX.md not found)" >&2
  echo "  Run: bash setup.sh --path $AC_ROOT" >&2
  exit 1
fi

ok "AgentComms root: $AC_ROOT"

# ─── Step 2: Detect model ─────────────────────────────────────────────────────
step "Step 2 — Detecting model"

MODEL=""
if [[ -n "$MODEL_OVERRIDE" ]]; then
  MODEL="$MODEL_OVERRIDE"
  ok "Using model: $MODEL (from --model flag)"
else
  if command -v openclaw >/dev/null 2>&1; then
    info "Checking default OpenClaw agent for model..."
    DETECTED=$(openclaw agents list 2>/dev/null | grep -A5 "(default)" | grep "Model:" | sed 's/.*Model: //' | tr -d ' ' || true)
    if [[ -n "$DETECTED" ]]; then
      MODEL="$DETECTED"
      ok "Detected model: $MODEL (from your default OpenClaw agent)"
    else
      warn "No default model detected. Agents will be created without a model."
      warn "Pass --model <id> if you want sessions to fire (e.g. --model anthropic/claude-haiku-4-5)"
    fi
  else
    info "openclaw not available — skipping model detection"
  fi
fi

# ─── Step 3: Run setup-agents.sh ─────────────────────────────────────────────
step "Step 3 — Setting up demo agents (vera, jin, ash)"

SETUP_SCRIPT="$IMPL_DIR/setup-agents.sh"
if [[ ! -f "$SETUP_SCRIPT" ]]; then
  fail "setup-agents.sh not found at: $SETUP_SCRIPT" >&2
  exit 1
fi

SETUP_ARGS=("--agentcomms-root" "$AC_ROOT")
if [[ -n "$MODEL" ]]; then
  SETUP_ARGS+=("--model" "$MODEL")
fi

bash "$SETUP_SCRIPT" "${SETUP_ARGS[@]}"

# ─── Capture inbox paths ──────────────────────────────────────────────────────
VERA_INBOX="$AC_ROOT/agents/vera/inbox"
JIN_INBOX="$AC_ROOT/agents/jin/inbox"
ASH_INBOX="$AC_ROOT/agents/ash/inbox"

# ─── Step 4: Create mission thread ───────────────────────────────────────────
step "Step 4 — Creating mission thread"

TODAY="$(date +%Y-%m-%d)"
THREAD_SLUG="${TODAY}_software-project-research-mission"
THREAD_DIR="$AC_ROOT/threads/$THREAD_SLUG"

if [[ -d "$THREAD_DIR" ]]; then
  info "Thread already exists — skipping creation: $THREAD_DIR"
else
  mkdir -p "$THREAD_DIR"

  # Write brief.md
  cat > "$THREAD_DIR/brief.md" << 'BRIEF_EOF'
# Mission Brief — Software Project Research & Write

## Mission

What are the three most important things to consider when starting a new software project?

## Team

- **Jin** handles research — produces `jin-research-summary.md` with 3 structured considerations and supporting rationale
- **Ash** handles writing — produces `ash-memo.md`, a polished one-page memo suitable for a technical audience
- **Vera** (you) coordinates, reviews, and closes the thread

## Deliverable

A polished one-page memo in this thread folder as `ash-memo.md`, with your synthesis and sign-off in `result.md`.

## Done When

- `jin-research-summary.md` exists (Jin's research)
- `ash-memo.md` exists (Ash's finished memo)
- `result.md` exists with your synthesis
- `status.md` is `done`
- This thread has been moved from `threads/` to `archive/`
BRIEF_EOF

  # Write status.md
  cat > "$THREAD_DIR/status.md" << STATUS_EOF
status: open
assigned-to: vera
opened: $TODAY
updated: $TODAY
STATUS_EOF

  ok "Thread created: $THREAD_DIR"
  ok "brief.md written"
  ok "status.md: open"
fi

# ─── Step 5: Drop mission signal to Vera's inbox ─────────────────────────────
step "Step 5 — Dropping mission signal to Vera's inbox"

NOW_STAMP="$(date +%Y-%m-%d_%H%M%S)"
SIGNAL_FILE="$VERA_INBOX/${NOW_STAMP}_mission-brief.md"

# Check if a mission signal already exists
EXISTING_SIGNAL=$(ls "$VERA_INBOX"/*mission* 2>/dev/null | head -1 || true)
if [[ -n "$EXISTING_SIGNAL" ]]; then
  info "Mission signal already exists in Vera's inbox — skipping"
  info "Found: $EXISTING_SIGNAL"
else
  cat > "$SIGNAL_FILE" << SIGNAL_EOF
# Mission Brief — Waiting in Threads

Thread: threads/${THREAD_SLUG}/
From: operator
Priority: high

Your mission brief is ready. Read brief.md in the thread folder and begin.

You are the orchestrator. Your team:
- Jin (researcher) — routes to jin's inbox when ready
- Ash (writer) — routes to ash's inbox after Jin's research is done

Done when: result.md exists, status.md is done, and this thread is in archive/.
SIGNAL_EOF

  ok "Mission signal written: $SIGNAL_FILE"
fi

# ─── Step 6: Pre-flight check ─────────────────────────────────────────────────
step "Step 6 — Pre-flight check"

PREFLIGHT_OK=true

# Check all three inboxes exist
for AGENT in vera jin ash; do
  INBOX="$AC_ROOT/agents/$AGENT/inbox"
  if [[ -d "$INBOX" ]]; then
    ok "$AGENT inbox: $INBOX"
  else
    fail "$AGENT inbox not found: $INBOX"
    PREFLIGHT_OK=false
  fi
done

# Check thread was created
if [[ -d "$THREAD_DIR" ]]; then
  ok "Thread exists: $THREAD_DIR"
else
  fail "Thread not found: $THREAD_DIR"
  PREFLIGHT_OK=false
fi

# Check brief.md
if [[ -f "$THREAD_DIR/brief.md" ]]; then
  ok "brief.md present"
else
  fail "brief.md missing from thread"
  PREFLIGHT_OK=false
fi

# Check Vera's inbox has a signal
VERA_SIGNAL_COUNT=$(ls "$VERA_INBOX"/*.md 2>/dev/null | grep -v "processed" | wc -l | tr -d ' ' || echo "0")
if [[ "$VERA_SIGNAL_COUNT" -gt 0 ]]; then
  ok "Vera's inbox: $VERA_SIGNAL_COUNT signal(s) waiting"
else
  fail "No signals in Vera's inbox"
  PREFLIGHT_OK=false
fi

if [[ "$PREFLIGHT_OK" != "true" ]]; then
  echo ""
  echo "✗ Pre-flight check failed. Review the errors above and re-run." >&2
  exit 1
fi

# ─── Step 7: Ready — exit with instructions ───────────────────────────────────
WAKE_SCRIPT=""
if [[ -f "$AC_ROOT/scripts/wake.sh" ]]; then
  WAKE_SCRIPT="$AC_ROOT/scripts/wake.sh"
elif [[ -f "$REPO_DIR/scripts/wake.sh" ]]; then
  WAKE_SCRIPT="$REPO_DIR/scripts/wake.sh"
fi

echo ""
echo "══════════════════════════════════════════════════════"
echo "✅ Demo is loaded and ready."
echo ""
echo "   Vera's inbox has the mission signal."
echo "   Jin and Ash are standing by."
echo ""
if [[ -n "$WAKE_SCRIPT" ]]; then
  echo "   To start the mission, run:"
  echo "     bash $WAKE_SCRIPT vera \"Check your inbox — your mission brief is waiting.\""
else
  echo "   To start the mission, run:"
  echo "     bash AgentComms/scripts/wake.sh vera \"Check your inbox — your mission brief is waiting.\""
fi
echo ""
echo "   What happens next (no action needed from you):"
echo "     1. Vera reads the brief, creates research task, routes to Jin"
echo "     2. Jin researches and reports back to Vera"
echo "     3. Vera routes writing task to Ash"
echo "     4. Ash writes the memo, signals Vera"
echo "     5. Vera reviews, writes result.md, archives the thread"
echo ""
if [[ -f "$AC_ROOT/dashboard/start.sh" ]]; then
  echo "   Watch progress in the dashboard:"
  echo "     bash $AC_ROOT/dashboard/start.sh"
  echo ""
fi
if [[ -f "$AC_ROOT/scripts/reset.sh" ]]; then
  echo "   To reset when done:"
  echo "     bash $AC_ROOT/scripts/reset.sh"
  echo ""
fi
echo "══════════════════════════════════════════════════════"
echo ""
