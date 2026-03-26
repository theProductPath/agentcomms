#!/usr/bin/env bash
# inbox-snapshot.sh
# Generates a text-based snapshot of AgentComms inbox state.
# Output is clean plain text — suitable for Telegram or any channel.
#
# Usage:
#   bash scripts/inbox-snapshot.sh
#
# Configuration:
#   Edit AGENTCOMMS and AC_THREADS below to point to your AgentComms instance.
#   By default this assumes the script lives inside a standard AgentComms folder
#   (one level below the instance root).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_ROOT="${AGENTCOMMS_PATH:-$(dirname "$SCRIPT_DIR")}"

AGENTCOMMS="$AC_ROOT/agents"
AC_THREADS="$AC_ROOT/threads"

# Optional: additional comms systems. Add blocks below to include them.
# EXTRA_LABEL="IT-Comms"
# EXTRA_AGENTS="/path/to/IT-Comms/agents"
# EXTRA_THREADS="/path/to/IT-Comms/threads"

NOW=$(date "+%a %b %-d, %-I:%M %p")

echo "📬 AgentComms Snapshot"
echo "$NOW"
echo ""

# ── AgentComms inboxes ────────────────────────────────────────────────────────
echo "── AgentComms ──────────────────"

BACKLOGGED=()
CLEAR=()
NOW_TS=$(date +%s)

if [ ! -d "$AGENTCOMMS" ]; then
  echo "  (agents folder not found: $AGENTCOMMS)"
else
  for agent_dir in "$AGENTCOMMS"/*/; do
    [ -d "$agent_dir" ] || continue
    agent=$(basename "$agent_dir")
    inbox="$agent_dir/inbox"
    unread=$(find "$inbox" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    latest_processed=$(ls -t "$inbox/processed" 2>/dev/null | head -1)
    last_active="${latest_processed:0:10}"
    [ -z "$last_active" ] && last_active="never"

    if [ "$unread" -gt 0 ]; then
      # Calculate age of oldest unread file
      oldest_ts=$(python3 << 'PYEOF' 2>/dev/null
import os, sys
inbox = sys.argv[1]
try:
  mtimes = [int(os.path.getmtime(os.path.join(inbox, f))) for f in os.listdir(inbox) 
            if f.endswith('.md') and os.path.isfile(os.path.join(inbox, f))]
  print(min(mtimes) if mtimes else '')
except:
  print('')
PYEOF
)
      age_str="?"
      if [ -n "$oldest_ts" ]; then
        age_secs=$(( NOW_TS - oldest_ts ))
        if [ "$age_secs" -lt 3600 ]; then
          age_str="$((age_secs / 60))m"
        elif [ "$age_secs" -lt 86400 ]; then
          age_str="$((age_secs / 3600))h"
        else
          age_str="$((age_secs / 86400))d"
        fi
      fi
      BACKLOGGED+=("$agent|$unread|$age_str")
    else
      CLEAR+=("$agent|$last_active")
    fi
  done
fi

# Print backlogged first (needs attention)
if [ ${#BACKLOGGED[@]} -gt 0 ]; then
  echo "⚠️  Needs attention:"
  for entry in "${BACKLOGGED[@]}"; do
    IFS='|' read -r agent unread age_str <<< "$entry"
    printf "  🔴 %-16s %2d  %5s\n" "$agent" "$unread" "$age_str"
  done
  echo "✅ ${#CLEAR[@]} others clear"
  echo ""
elif [ ${#CLEAR[@]} -gt 0 ]; then
  echo "✅  All clear (${#CLEAR[@]} agents)"
  echo ""
fi

echo ""

# ── Open Threads ──────────────────────────────────────────────────────────────
echo "── Open Threads ────────────────"

if [ ! -d "$AC_THREADS" ]; then
  echo "  (threads folder not found: $AC_THREADS)"
else
  python3 <<PYEOF
import os, re

TERMINAL = {'done', 'closed', 'archived', 'pending-archive', 'complete'}

def is_terminal(sf):
    try:
        with open(sf) as fh:
            for line in fh.read().lower().splitlines():
                if re.match(r'[\*#\s\-]*status[\*\s]*:', line):
                    for t in TERMINAL:
                        if t in line:
                            return True
    except:
        pass
    return False

def get_label(sf):
    try:
        with open(sf) as fh:
            for line in fh:
                line = line.strip()
                m = re.match(r'[\*]*[Ss]tatus[\*]*:\s*(.*)', line)
                if m:
                    return m.group(1).strip()
    except:
        pass
    return ''

threads_dir = """$AC_THREADS"""
open_threads = []
try:
    for thread in sorted(os.listdir(threads_dir)):
        td = os.path.join(threads_dir, thread)
        if not os.path.isdir(td):
            continue
        sf = os.path.join(td, 'status.md')
        if os.path.isfile(sf) and is_terminal(sf):
            continue
        label = get_label(sf) if os.path.isfile(sf) else ''
        open_threads.append((thread, label))
except Exception as e:
    print(f"  (error reading threads: {e})")
    exit(0)

if open_threads:
    for thread, label in open_threads:
        suffix = f" — {label}" if label else ""
        print(f"  📂 {thread}{suffix}")
else:
    print("  (no open threads)")
PYEOF
fi

echo ""
echo "────────────────────────────────"
