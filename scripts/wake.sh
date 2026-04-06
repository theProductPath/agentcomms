#!/usr/bin/env bash
# AgentComms v0.7 — wake.sh
# Delivers a wake signal to an agent's inbox and fires a one-shot OpenClaw session.
#
# Usage:
#   bash wake.sh <agent-name>
#   bash wake.sh <agent-name> "Your custom message here."
#   bash wake.sh <agent-name> --subject "Subject Line" "Your custom message."
#   bash wake.sh <agent-name> --no-session "Message (skip OpenClaw session)"

set -eu

# ─── Root resolution ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_ROOT="$(dirname "$SCRIPT_DIR")"
AC_ROOT="${AC_ROOT/#\~/$HOME}"

# ─── Defaults ────────────────────────────────────────────────────────────────
AGENT_NAME=""
MESSAGE="Check your inbox and process any pending signals."
SUBJECT="Wake Signal"
FIRE_SESSION=true

# ─── Arg parsing ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --subject)
      SUBJECT="$2"
      shift 2
      ;;
    --no-session)
      FIRE_SESSION=false
      shift
      ;;
    --root)
      AC_ROOT="$2"
      shift 2
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      echo "Usage: bash wake.sh <agent-name> [--subject \"Subject\"] [--no-session] [\"message\"]" >&2
      exit 1
      ;;
    *)
      if [[ -z "$AGENT_NAME" ]]; then
        AGENT_NAME="$1"
      else
        MESSAGE="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$AGENT_NAME" ]]; then
  echo "Usage: bash wake.sh <agent-name> [--subject \"Subject\"] [--no-session] [\"message\"]" >&2
  exit 1
fi

# ─── Validate agent folder ────────────────────────────────────────────────────
INBOX_DIR="$AC_ROOT/agents/$AGENT_NAME/inbox"
if [[ ! -d "$INBOX_DIR" ]]; then
  echo "✗ Agent not found: $AGENT_NAME" >&2
  echo "  Expected inbox at: $INBOX_DIR" >&2
  echo "  Run: bash AgentComms/scripts/wake.sh --help to list available agents" >&2
  echo "" >&2
  echo "  Available agents:" >&2
  for d in "$AC_ROOT/agents"/*/; do
    [[ -d "$d" ]] && echo "    · $(basename "$d")" >&2
  done
  exit 1
fi

# ─── Read mailbox identity ────────────────────────────────────────────────────
MAILBOX_ID="unknown"
MAILBOX_FILE="$AC_ROOT/MAILBOX.md"
if [[ -f "$MAILBOX_FILE" ]]; then
  raw="$(grep -m1 '^mailbox-id:' "$MAILBOX_FILE" 2>/dev/null || true)"
  MAILBOX_ID="$(echo "$raw" | sed 's/^mailbox-id:[[:space:]]*//' | tr -d '[:space:]')"
  [[ -z "$MAILBOX_ID" ]] && MAILBOX_ID="unknown"
fi

# ─── Write wake signal ────────────────────────────────────────────────────────
NOW_DATE="$(date +%Y-%m-%d)"
NOW_TIME="$(date +%H:%M)"
NOW_STAMP="$(date +%Y-%m-%d_%H%M%S)"
SIGNAL_FILE="$INBOX_DIR/${NOW_STAMP}_wake.md"

cat > "$SIGNAL_FILE" << SIGNAL_EOF
# ${SUBJECT}

From: operator
Sent: ${NOW_DATE} ${NOW_TIME}
Mailbox: ${MAILBOX_ID}

${MESSAGE}
SIGNAL_EOF

echo ""
echo "✅ Signal delivered to $AGENT_NAME"
echo "   → $SIGNAL_FILE"
echo ""

# ─── Fire OpenClaw session ────────────────────────────────────────────────────
if [[ "$FIRE_SESSION" == "true" ]]; then
  if command -v openclaw >/dev/null 2>&1; then
    echo "🚀 Firing OpenClaw session for $AGENT_NAME..."
    openclaw agent --agent "$AGENT_NAME" --message "$MESSAGE" || {
      echo "⚠  OpenClaw session failed. Signal was delivered — start a session manually."
    }
    echo ""
  else
    echo "⚠  openclaw not found in PATH."
    echo "   Signal delivered to inbox. Start a session manually:"
    echo "   openclaw agent --agent $AGENT_NAME --message \"$MESSAGE\""
    echo ""
  fi
fi

echo "Done."
echo ""
