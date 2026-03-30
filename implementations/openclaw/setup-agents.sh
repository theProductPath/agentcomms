#!/usr/bin/env bash
# AgentComms v0.9 — setup-agents.sh
# Sets up the three demo agents (Vera, Jin, Ash) in both AgentComms and OpenClaw.
#
# Usage:
#   bash implementations/openclaw/setup-agents.sh [--agentcomms-root /path/to/AgentComms] [--model anthropic/claude-haiku-4-5]

set -euo pipefail

# ─── Root resolution ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMPL_DIR="$SCRIPT_DIR"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# ─── Defaults ────────────────────────────────────────────────────────────────
AC_ROOT=""
MODEL_OVERRIDE=""
SOULS_DIR="$IMPL_DIR/agent-souls"
ADD_AGENT_SCRIPT=""  # resolved below

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
      echo "Usage: bash setup-agents.sh [--agentcomms-root /path] [--model anthropic/claude-haiku-4-5]" >&2
      exit 1
      ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────
info()    { echo "  → $*"; }
ok()      { echo "  ✓ $*"; }
warn()    { echo "  ⚠  $*"; }
section() { echo ""; echo "── $* ──"; }

# ─── Resolve AgentComms root ─────────────────────────────────────────────────
section "Resolving AgentComms root"

if [[ -z "$AC_ROOT" ]]; then
  # Try to infer: installer-path.txt points back to repo, or look for MAILBOX.md
  # Walk up from IMPL_DIR to find an AgentComms instance, or use the repo itself
  # For demo purposes, default to ~/AgentComms if it exists, else require --agentcomms-root
  if [[ -f "$HOME/AgentComms/MAILBOX.md" ]]; then
    AC_ROOT="$HOME/AgentComms"
  elif [[ -f "$(pwd)/MAILBOX.md" ]]; then
    AC_ROOT="$(pwd)"
  else
    echo "" >&2
    echo "✗ Could not detect AgentComms root." >&2
    echo "" >&2
    echo "  Pass it explicitly:" >&2
    echo "    bash implementations/openclaw/setup-agents.sh --agentcomms-root /path/to/AgentComms" >&2
    echo "" >&2
    echo "  Or run setup.sh first to create an AgentComms instance:" >&2
    echo "    bash setup.sh --path ~/AgentComms" >&2
    echo "" >&2
    exit 1
  fi
fi

AC_ROOT="${AC_ROOT/#\~/$HOME}"

if [[ ! -f "$AC_ROOT/MAILBOX.md" ]]; then
  echo "" >&2
  echo "✗ Not a valid AgentComms root: $AC_ROOT" >&2
  echo "  MAILBOX.md not found. Run setup.sh to initialize it." >&2
  exit 1
fi

ok "AgentComms root: $AC_ROOT"

# ─── Resolve add-agent.sh ────────────────────────────────────────────────────
# Could be in the repo scripts/ dir (development) or installed in AC_ROOT/scripts/
if [[ -f "$REPO_DIR/scripts/add-agent.sh" ]]; then
  ADD_AGENT_SCRIPT="$REPO_DIR/scripts/add-agent.sh"
elif [[ -f "$AC_ROOT/scripts/add-agent.sh" ]]; then
  ADD_AGENT_SCRIPT="$AC_ROOT/scripts/add-agent.sh"
else
  echo "" >&2
  echo "✗ add-agent.sh not found." >&2
  echo "  Expected at: $REPO_DIR/scripts/add-agent.sh" >&2
  echo "  Run setup.sh to install scripts into your AgentComms instance." >&2
  exit 1
fi

ok "add-agent.sh: $ADD_AGENT_SCRIPT"

# ─── Detect model ─────────────────────────────────────────────────────────────
section "Detecting model"

OPENCLAW_AVAILABLE=false
MODEL=""

if [[ -n "$MODEL_OVERRIDE" ]]; then
  MODEL="$MODEL_OVERRIDE"
  ok "Using model: $MODEL (from --model flag)"
else
  if command -v openclaw >/dev/null 2>&1; then
    OPENCLAW_AVAILABLE=true
    info "openclaw found — detecting default agent model..."
    DETECTED_MODEL=$(openclaw agents list 2>/dev/null | grep -A5 "(default)" | grep "Model:" | sed 's/.*Model: //' | tr -d ' ' || true)
    if [[ -n "$DETECTED_MODEL" ]]; then
      MODEL="$DETECTED_MODEL"
      ok "Using model: $MODEL (from your default OpenClaw agent)"
    else
      warn "openclaw found but no default model detected."
      warn "Pass --model <id> to set the model, or agents will be registered without one."
      warn "Example: --model anthropic/claude-haiku-4-5"
      MODEL=""
    fi
  else
    warn "openclaw not found in PATH."
    warn "AgentComms inboxes will be created, but agents won't be registered in OpenClaw."
    warn "wake.sh will deliver signals to inboxes, but sessions won't auto-fire."
    OPENCLAW_AVAILABLE=false
    MODEL=""
  fi
fi

# ─── Set up each agent ────────────────────────────────────────────────────────
section "Setting up demo agents"

AGENTS=("vera" "jin" "ash")
VERA_INBOX=""
JIN_INBOX=""
ASH_INBOX=""

for AGENT in "${AGENTS[@]}"; do
  echo ""
  info "Setting up $AGENT..."

  # 1. Create AgentComms inbox via add-agent.sh
  bash "$ADD_AGENT_SCRIPT" "$AGENT" --root "$AC_ROOT" --force

  AGENT_INBOX="$AC_ROOT/agents/$AGENT/inbox"

  # Capture inbox paths for SOUL.md substitution
  case "$AGENT" in
    vera) VERA_INBOX="$AGENT_INBOX" ;;
    jin)  JIN_INBOX="$AGENT_INBOX"  ;;
    ash)  ASH_INBOX="$AGENT_INBOX"  ;;
  esac
done

# All inboxes are now set — do SOUL.md + OpenClaw registration in a second pass
echo ""
info "Writing SOUL.md files and registering with OpenClaw..."

for AGENT in "${AGENTS[@]}"; do
  SOUL_SRC="$SOULS_DIR/${AGENT}-SOUL.md"
  WORKSPACE="$HOME/.openclaw/workspace-${AGENT}"
  SOUL_DEST="$WORKSPACE/SOUL.md"

  if [[ ! -f "$SOUL_SRC" ]]; then
    echo "  ✗ SOUL.md not found for $AGENT: $SOUL_SRC" >&2
    exit 1
  fi

  # 2–4. OpenClaw workspace + registration — only if openclaw is available
  if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then
    # Create workspace directory
    mkdir -p "$WORKSPACE"

    # Write SOUL.md with placeholder substitution
    sed \
      -e "s|{{VERA_INBOX}}|$VERA_INBOX|g" \
      -e "s|{{JIN_INBOX}}|$JIN_INBOX|g" \
      -e "s|{{ASH_INBOX}}|$ASH_INBOX|g" \
      -e "s|{{AGENTCOMMS_ROOT}}|$AC_ROOT|g" \
      -e "s|{{INBOX_PATH}}|$AC_ROOT/agents/$AGENT/inbox|g" \
      "$SOUL_SRC" > "$SOUL_DEST"

    ok "$AGENT: SOUL.md written to $SOUL_DEST"

    # Register with OpenClaw
    if [[ -n "$MODEL" ]]; then
      openclaw agents add "$AGENT" \
        --workspace "$WORKSPACE" \
        --model "$MODEL" \
        --non-interactive 2>/dev/null && ok "$AGENT: registered with OpenClaw (model: $MODEL)" \
        || warn "$AGENT: openclaw agents add failed — may already be registered. SOUL.md is in place."
    else
      warn "$AGENT: skipping OpenClaw registration (no model set — pass --model to register)"
    fi
  else
    info "$AGENT: AgentComms inbox created. Skipping OpenClaw workspace (openclaw not available)."
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "✅ Demo team ready in AgentComms + OpenClaw:"
echo ""
printf "   %-20s inbox: %s/\n" "vera (orchestrator)" "$VERA_INBOX"
printf "   %-20s inbox: %s/\n" "jin  (researcher)"   "$JIN_INBOX"
printf "   %-20s inbox: %s/\n" "ash  (writer)"       "$ASH_INBOX"
echo ""
if [[ -n "$MODEL" ]]; then
  if [[ -n "$MODEL_OVERRIDE" ]]; then
    echo "   Model: $MODEL (from --model flag)"
  else
    echo "   Model: $MODEL (from default agent)"
  fi
else
  echo "   Model: none set — agents created but not registered with OpenClaw"
fi
echo ""
echo "   Next: run implementations/openclaw/run-demo.sh to load the mission and start."
echo "══════════════════════════════════════════════════════"
echo ""
