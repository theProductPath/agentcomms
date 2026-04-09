#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BOX="$ROOT/MAILBOX.md"
MEM="$ROOT/agents/MEMBERS.md"
CLOSED="$ROOT/MAILBOX-CLOSED.md"
id="unknown"
name="My Team"
created=""
[[ -f "$BOX" ]] && { id="$(grep '^mailbox-id:' "$BOX"|sed 's/^mailbox-id:[[:space:]]*//')"; name="$(grep '^mailbox-name:' "$BOX"|sed 's/^mailbox-name:[[:space:]]*//')"; created="$(grep '^created:' "$BOX"|sed 's/^created:[[:space:]]*//')"; }
{
  echo "# AgentComms Mailbox — CLOSED"
  echo
  echo "mailbox-id: $id"
  echo "mailbox-name: $name"
  echo "created: ${created:-unknown}"
  echo "closed: $(date +%F)"
  echo "agentcomms-version: 1"
  echo
  echo "## Cleanup Checklist"
  echo "- [ ] Notify members"
  echo "- [ ] Remove cron jobs"
  echo "- [ ] Archive any remaining open threads"
  echo "- [ ] Keep archive/ intact"
} > "$CLOSED"

echo "Wrote $CLOSED"
