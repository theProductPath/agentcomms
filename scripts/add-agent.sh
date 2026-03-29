#!/usr/bin/env bash
# AgentComms — add-agent.sh
# Adds a new agent to this AgentComms instance.
# Generic — no OpenClaw knowledge. Works with any AgentComms mailbox.
#
# Usage:
#   bash add-agent.sh <agent-name> [--root /path/to/AgentComms] [--force]
#
# What it does:
#   1. Creates agents/<agent-name>/inbox/ and inbox/processed/
#   2. Adds the agent to agents/MEMBERS.md (creates file if missing)
#   3. Prints the agent's inbox path

set -euo pipefail

# ─── Root resolution ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_ROOT="$(dirname "$SCRIPT_DIR")"

# ─── Defaults ────────────────────────────────────────────────────────────────
AGENT_NAME=""
FORCE=false
MAILBOX_NAME=""

# ─── Arg parsing ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      AC_ROOT="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --mailbox-name)
      MAILBOX_NAME="$2"
      shift 2
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      echo "Usage: bash add-agent.sh <agent-name> [--root /path] [--force]" >&2
      exit 1
      ;;
    *)
      if [[ -z "$AGENT_NAME" ]]; then
        AGENT_NAME="$1"
      else
        echo "Unexpected argument: $1" >&2
        echo "Usage: bash add-agent.sh <agent-name> [--root /path] [--force]" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$AGENT_NAME" ]]; then
  echo "Usage: bash add-agent.sh <agent-name> [--root /path] [--force]" >&2
  exit 1
fi

# Resolve ~ in root path
AC_ROOT="${AC_ROOT/#\~/$HOME}"

# ─── Validate AgentComms root ─────────────────────────────────────────────────
if [[ ! -d "$AC_ROOT" ]]; then
  echo "✗ AgentComms root not found: $AC_ROOT" >&2
  exit 1
fi

AGENTS_DIR="$AC_ROOT/agents"
INBOX_DIR="$AGENTS_DIR/$AGENT_NAME/inbox"
PROCESSED_DIR="$INBOX_DIR/processed"
MEMBERS_FILE="$AGENTS_DIR/MEMBERS.md"
TODAY="$(date +%Y-%m-%d)"

# ─── Check if agent already exists ───────────────────────────────────────────
if [[ -d "$INBOX_DIR" ]]; then
  if [[ "$FORCE" == "true" ]]; then
    # Ensure processed/ exists even if inbox already existed
    mkdir -p "$PROCESSED_DIR"
    echo ""
    echo "✅ Agent ready: $AGENT_NAME"
    echo "   Inbox: $INBOX_DIR/"
    echo "   Registered in: $MEMBERS_FILE"
    echo ""
    exit 0
  else
    echo "✗ Agent already exists: $AGENT_NAME" >&2
    echo "  Inbox found at: $INBOX_DIR" >&2
    echo "  Use --force to skip this error and ensure folders exist." >&2
    exit 1
  fi
fi

# ─── Create folders ───────────────────────────────────────────────────────────
mkdir -p "$PROCESSED_DIR"

# Add .keep files so git tracks the empty dirs
touch "$INBOX_DIR/.keep"
touch "$PROCESSED_DIR/.keep"

# ─── Update MEMBERS.md ────────────────────────────────────────────────────────
if [[ ! -f "$MEMBERS_FILE" ]]; then
  # Read mailbox name from MAILBOX.md or use passed flag or default
  if [[ -z "$MAILBOX_NAME" ]]; then
    MAILBOX_FILE="$AC_ROOT/MAILBOX.md"
    if [[ -f "$MAILBOX_FILE" ]]; then
      raw="$(grep -m1 '^mailbox-name:' "$MAILBOX_FILE" 2>/dev/null || true)"
      MAILBOX_NAME="$(echo "$raw" | sed 's/^mailbox-name:[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    fi
    [[ -z "$MAILBOX_NAME" ]] && MAILBOX_NAME="My Team"
  fi

  cat > "$MEMBERS_FILE" << MEMBERS_EOF
# Members — ${MAILBOX_NAME}

| Agent | Joined | Status |
|-------|--------|--------|
MEMBERS_EOF
fi

# Append the new agent row (only if not already listed)
if ! grep -q "| $AGENT_NAME |" "$MEMBERS_FILE" 2>/dev/null; then
  echo "| $AGENT_NAME | $TODAY | active |" >> "$MEMBERS_FILE"
fi

# ─── Output ───────────────────────────────────────────────────────────────────
echo ""
echo "✅ Agent added: $AGENT_NAME"
echo "   Inbox: $INBOX_DIR/"
echo "   Registered in: $MEMBERS_FILE"
echo ""
