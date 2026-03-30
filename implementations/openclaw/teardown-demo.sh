#!/usr/bin/env bash
# AgentComms v0.9 — teardown-demo.sh
# Removes the demo agents (vera, jin, ash) from OpenClaw and deletes their workspaces.
#
# Usage:
#   bash implementations/openclaw/teardown-demo.sh [--force]
#
# Run this after bash AgentComms/scripts/reset.sh to fully clean up the demo.

set -eu

FORCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

AGENTS=("vera" "jin" "ash")

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│  AgentComms Demo — OpenClaw Teardown                │"
echo "└─────────────────────────────────────────────────────┘"
echo ""

# ─── Confirmation ────────────────────────────────────────────────────────────
if [[ "$FORCE" != "true" ]]; then
  echo "  This will:"
  echo "    · Remove vera, jin, and ash from OpenClaw"
  echo "    · Delete their workspaces from ~/.openclaw/"
  echo ""
  printf "  Continue? [y/N] "
  REPLY=""
  read -r REPLY </dev/tty 2>/dev/null || true
  echo ""
  if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
    echo "  Aborted."
    exit 0
  fi
fi

# ─── Remove from OpenClaw ────────────────────────────────────────────────────
if command -v openclaw >/dev/null 2>&1; then
  echo "→ Removing agents from OpenClaw..."
  for AGENT in "${AGENTS[@]}"; do
    if openclaw agents list 2>/dev/null | grep -q "^- $AGENT "; then
      openclaw agents delete "$AGENT" 2>/dev/null && echo "  ✓ openclaw agents delete $AGENT" \
        || echo "  ⚠  Could not delete $AGENT from OpenClaw (may already be removed)"
    else
      echo "  → $AGENT not registered in OpenClaw — skipping"
    fi
  done
else
  echo "  ⚠  openclaw not found — skipping OpenClaw agent removal"
fi
echo ""

# ─── Remove workspaces ───────────────────────────────────────────────────────
echo "→ Removing workspaces from ~/.openclaw/..."
for AGENT in "${AGENTS[@]}"; do
  WORKSPACE="$HOME/.openclaw/workspace-${AGENT}"
  if [[ -d "$WORKSPACE" ]]; then
    rm -rf "$WORKSPACE"
    echo "  ✓ Removed: $WORKSPACE"
  else
    echo "  → $WORKSPACE not found — skipping"
  fi
done
echo ""

echo "✅ Demo teardown complete."
echo "   Run bash AgentComms/scripts/reset.sh if you haven't already"
echo "   to clear the AgentComms inboxes and threads."
echo ""
