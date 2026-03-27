#!/usr/bin/env bash
# AgentComms v0.7 — teardown.sh
# Gracefully closes a mailbox: validates state, warns about open threads, writes MAILBOX-CLOSED.md
#
# Usage: bash teardown.sh
# Run from your AgentComms root folder, or pass --root /path/to/AgentComms

set -euo pipefail

# ─── Root resolution ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      AC_ROOT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash teardown.sh [--root /path/to/AgentComms]" >&2
      exit 1
      ;;
  esac
done

# If --root not given, assume script is in scripts/ one level below AC root
if [[ -z "$AC_ROOT" ]]; then
  AC_ROOT="$(dirname "$SCRIPT_DIR")"
fi
AC_ROOT="${AC_ROOT/#\~/$HOME}"
if [[ "$AC_ROOT" != /* ]]; then
  AC_ROOT="$(pwd)/$AC_ROOT"
fi

if [[ ! -d "$AC_ROOT" ]]; then
  echo "✗ AgentComms root not found: $AC_ROOT" >&2
  exit 1
fi

echo ""
echo "┌─────────────────────────────────────────────────┐"
echo "│  AgentComms Teardown  ·  v0.7                    │"
echo "│  Closing a mailbox                               │"
echo "└─────────────────────────────────────────────────┘"
echo ""
echo "Root: $AC_ROOT"
echo ""

# ─── Read MAILBOX.md ─────────────────────────────────────────────────────────
MAILBOX_FILE="$AC_ROOT/MAILBOX.md"
MAILBOX_ID="unknown"
MAILBOX_NAME="Unknown Team"
MAILBOX_CREATED=""
MAILBOX_VERSION=""

if [[ -f "$MAILBOX_FILE" ]]; then
  MAILBOX_ID="$(grep -m1 '^mailbox-id:' "$MAILBOX_FILE" | sed 's/^mailbox-id:[[:space:]]*//' | tr -d '[:space:]')"
  MAILBOX_NAME="$(grep -m1 '^mailbox-name:' "$MAILBOX_FILE" | sed 's/^mailbox-name:[[:space:]]*//')"
  MAILBOX_CREATED="$(grep -m1 '^created:' "$MAILBOX_FILE" | sed 's/^created:[[:space:]]*//' | tr -d '[:space:]')"
  MAILBOX_VERSION="$(grep -m1 '^agentcomms-version:' "$MAILBOX_FILE" | sed 's/^agentcomms-version:[[:space:]]*//' | tr -d '[:space:]')"
  echo "  Mailbox ID:   $MAILBOX_ID"
  echo "  Mailbox Name: $MAILBOX_NAME"
  [[ -n "$MAILBOX_CREATED" ]] && echo "  Created:      $MAILBOX_CREATED"
  echo ""
else
  echo "  ⚠ MAILBOX.md not found — mailbox-id will be 'unknown'"
  echo ""
fi

# ─── Read agents/MEMBERS.md ──────────────────────────────────────────────────
MEMBERS_FILE="$AC_ROOT/agents/MEMBERS.md"
MEMBERS_LIST=()

if [[ -f "$MEMBERS_FILE" ]]; then
  while IFS= read -r line; do
    # Match table rows: | agent | ... |
    if [[ "$line" =~ ^\|[[:space:]]*([^|]+)[[:space:]]*\|[[:space:]]*([^|]*)[[:space:]]*\|[[:space:]]*([^|]*)[[:space:]]*\| ]]; then
      agent="${BASH_REMATCH[1]}"
      agent="$(echo "$agent" | tr -d '[:space:]')"
      [[ "$agent" == "Agent" || "$agent" == "---" || "$agent" =~ ^-+$ ]] && continue
      MEMBERS_LIST+=("$agent")
    fi
  done < "$MEMBERS_FILE"
  echo "  Members in MEMBERS.md: ${#MEMBERS_LIST[@]}"
  for m in "${MEMBERS_LIST[@]}"; do
    echo "    · $m"
  done
  echo ""
fi

# ─── Scan open threads ────────────────────────────────────────────────────────
THREADS_DIR="$AC_ROOT/threads"
OPEN_THREADS=()
TERMINAL_STATUSES="done|closed|archived|pending-archive|complete"

if [[ -d "$THREADS_DIR" ]]; then
  for thread_dir in "$THREADS_DIR"/*/; do
    [[ -d "$thread_dir" ]] || continue
    thread_name="$(basename "$thread_dir")"
    status_file="$thread_dir/status.md"
    status="open"
    if [[ -f "$status_file" ]]; then
      raw_status="$(grep -i '^status:' "$status_file" | head -1 | sed 's/^status:[[:space:]]*//' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
      [[ -n "$raw_status" ]] && status="$raw_status"
    fi
    # Check if terminal
    if echo "$status" | grep -qiE "^($TERMINAL_STATUSES)$"; then
      continue
    fi
    OPEN_THREADS+=("$thread_name ($status)")
  done
fi

if [[ ${#OPEN_THREADS[@]} -gt 0 ]]; then
  echo "  ⚠  Unresolved threads (${#OPEN_THREADS[@]}):"
  for t in "${OPEN_THREADS[@]}"; do
    echo "    🔴 $t"
  done
  echo ""
  echo "  These threads are not done. Tearing down will mark the mailbox closed"
  echo "  but these threads will remain on disk for your records."
  echo ""
else
  echo "  ✓ No open threads — all work is resolved."
  echo ""
fi

# ─── Confirmation ─────────────────────────────────────────────────────────────
printf "  Close mailbox \"%s\" (%s)? This cannot be undone. [y/N] " "$MAILBOX_NAME" "$MAILBOX_ID"
REPLY=""
read -r REPLY </dev/tty 2>/dev/null || true
echo ""
if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
  echo "  Aborted. Mailbox not closed."
  echo ""
  exit 0
fi
echo ""

# ─── Write MAILBOX-CLOSED.md ─────────────────────────────────────────────────
TODAY="$(date +%Y-%m-%d)"
NOW="$(date '+%Y-%m-%d %H:%M %Z')"
CLOSED_FILE="$AC_ROOT/MAILBOX-CLOSED.md"

cat > "$CLOSED_FILE" << CLOSED_EOF
# AgentComms Mailbox — CLOSED

mailbox-id: ${MAILBOX_ID}
mailbox-name: ${MAILBOX_NAME}
created: ${MAILBOX_CREATED:-unknown}
closed: ${TODAY}
agentcomms-version: ${MAILBOX_VERSION:-1}

---

## Closure Summary

Closed at: ${NOW}

### Members at Close

CLOSED_EOF

if [[ ${#MEMBERS_LIST[@]} -gt 0 ]]; then
  echo "| Agent | Status |" >> "$CLOSED_FILE"
  echo "|-------|--------|" >> "$CLOSED_FILE"
  for m in "${MEMBERS_LIST[@]}"; do
    echo "| $m | notified |" >> "$CLOSED_FILE"
  done
else
  echo "_No members listed in MEMBERS.md_" >> "$CLOSED_FILE"
fi

echo "" >> "$CLOSED_FILE"

if [[ ${#OPEN_THREADS[@]} -gt 0 ]]; then
  echo "### Unresolved Threads at Close" >> "$CLOSED_FILE"
  echo "" >> "$CLOSED_FILE"
  for t in "${OPEN_THREADS[@]}"; do
    echo "- ⚠ $t" >> "$CLOSED_FILE"
  done
  echo "" >> "$CLOSED_FILE"
else
  echo "### Threads" >> "$CLOSED_FILE"
  echo "" >> "$CLOSED_FILE"
  echo "_All threads resolved at close._" >> "$CLOSED_FILE"
  echo "" >> "$CLOSED_FILE"
fi

cat >> "$CLOSED_FILE" << 'CLOSED_FOOTER'
---

*This file marks the official closure of this AgentComms mailbox.*
*The archive remains intact as institutional memory.*
CLOSED_FOOTER

echo "  ✓ MAILBOX-CLOSED.md written"
echo ""

# ─── Print cleanup checklist ─────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════"
echo "  AgentComms Mailbox Closed"
echo ""
echo "  Mailbox:  $MAILBOX_ID  ($MAILBOX_NAME)"
echo "  Closed:   $NOW"
echo ""
echo "  ── Cleanup Checklist ──────────────────────────────"
echo ""
echo "  1. [ ] Notify all members the mailbox is closed:"
for m in "${MEMBERS_LIST[@]:-}"; do
  [[ -n "$m" ]] && echo "         · $m"
done
echo ""
echo "  2. [ ] Archive or delete agent workspace configs"
echo "         pointing to this mailbox"
echo ""
echo "  3. [ ] Remove any cron jobs polling this mailbox"
echo ""
if [[ ${#OPEN_THREADS[@]} -gt 0 ]]; then
  echo "  4. [ ] Resolve or hand off open threads:"
  for t in "${OPEN_THREADS[@]}"; do
    echo "         · $t"
  done
  echo ""
fi
echo "  5. [ ] Keep the archive/ folder — it's your record"
echo ""
echo "  6. [ ] Remove the dashboard if no longer needed:"
echo "         bash $AC_ROOT/dashboard/start.sh --no-open"
echo "         → Stop via the Stop button in the dashboard"
echo ""
echo "  MAILBOX-CLOSED.md has been written to:"
echo "  $CLOSED_FILE"
echo ""
echo "══════════════════════════════════════════════════════"
echo ""
