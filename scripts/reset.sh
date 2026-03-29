#!/usr/bin/env bash
# AgentComms — reset.sh
# Wipe an AgentComms instance back to clean or example state.
#
# Usage:
#   bash AgentComms/scripts/reset.sh
#   bash AgentComms/scripts/reset.sh --force
#   bash AgentComms/scripts/reset.sh --example
#   bash AgentComms/scripts/reset.sh --example --force
#   bash AgentComms/scripts/reset.sh --root /path/to/AgentComms

set -eu

# ─── Infer AC root from script location ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FORCE=false
EXAMPLE=false

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
    --example)
      EXAMPLE=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash reset.sh [--root <path>] [--force] [--example]" >&2
      exit 1
      ;;
  esac
done

# ─── Resolve absolute path ────────────────────────────────────────────────────
AC_ROOT="${AC_ROOT/#\~/$HOME}"
if [[ "$AC_ROOT" != /* ]]; then
  AC_ROOT="$(pwd)/$AC_ROOT"
fi

# ─── Validate root ────────────────────────────────────────────────────────────
if [[ ! -d "$AC_ROOT" ]]; then
  echo "Error: AgentComms root not found: $AC_ROOT" >&2
  exit 1
fi

for required in agents threads archive; do
  if [[ ! -d "$AC_ROOT/$required" ]]; then
    echo "Error: Not a valid AgentComms instance (missing $required/): $AC_ROOT" >&2
    exit 1
  fi
done

echo ""
echo "AgentComms Reset"
echo "Instance: $AC_ROOT"
echo ""

# ─── Check for open threads ───────────────────────────────────────────────────
OPEN_THREADS=()
if [[ -d "$AC_ROOT/threads" ]]; then
  for thread_dir in "$AC_ROOT/threads"/*/; do
    [[ -d "$thread_dir" ]] || continue
    slug="$(basename "$thread_dir")"
    status_file="$thread_dir/status.md"
    if [[ -f "$status_file" ]]; then
      status_content="$(cat "$status_file" | tr '[:upper:]' '[:lower:]')"
      if echo "$status_content" | grep -q "done\|closed\|archived"; then
        continue
      fi
    fi
    OPEN_THREADS+=("$slug")
  done
fi

if [[ ${#OPEN_THREADS[@]} -gt 0 ]]; then
  if [[ "$FORCE" == "true" ]]; then
    echo "  ! Warning: ${#OPEN_THREADS[@]} open thread(s) will be deleted:"
    for t in "${OPEN_THREADS[@]}"; do echo "      - $t"; done
    echo ""
  else
    echo "  ⚠️  Open threads detected:"
    for t in "${OPEN_THREADS[@]}"; do echo "      - $t"; done
    echo ""
    printf "  These threads are still open. Reset anyway? [y/N] "
    REPLY=""
    read -r REPLY </dev/tty || true
    echo ""
    if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
      echo "  Aborted. No changes made."
      exit 0
    fi
  fi
fi

# ─── Confirmation prompt ──────────────────────────────────────────────────────
if [[ "$FORCE" != "true" ]]; then
  printf "  This will delete all agents, threads, and archive contents. Are you sure? [y/N] "
  CONFIRM=""
  read -r CONFIRM </dev/tty || true
  echo ""
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "  Aborted. No changes made."
    exit 0
  fi
fi

# ─── Wipe content ─────────────────────────────────────────────────────────────
echo "→ Wiping agents/ ..."
if [[ -d "$AC_ROOT/agents" ]]; then
  find "$AC_ROOT/agents" -mindepth 1 -not -name "MEMBERS.md" -delete 2>/dev/null || true
fi

echo "→ Wiping threads/ ..."
if [[ -d "$AC_ROOT/threads" ]]; then
  find "$AC_ROOT/threads" -mindepth 1 -delete 2>/dev/null || true
fi

echo "→ Wiping archive/ ..."
if [[ -d "$AC_ROOT/archive" ]]; then
  find "$AC_ROOT/archive" -mindepth 1 -delete 2>/dev/null || true
fi

echo "→ Resetting agents/MEMBERS.md ..."
cat > "$AC_ROOT/agents/MEMBERS.md" << 'MEMBERS_EOF'
# Members

| Agent | Joined | Status |
|-------|--------|--------|
MEMBERS_EOF

# ─── Example content ──────────────────────────────────────────────────────────
if [[ "$EXAMPLE" == "true" ]]; then
  echo ""
  echo "→ Locating scaffold source..."

  INSTALLER_DIR=""

  # 1. Check AGENTCOMMS_INSTALLER env var
  if [[ -n "${AGENTCOMMS_INSTALLER:-}" ]] && [[ -d "$AGENTCOMMS_INSTALLER/scaffold" ]]; then
    INSTALLER_DIR="$AGENTCOMMS_INSTALLER"
    echo "  ✓ Found via AGENTCOMMS_INSTALLER env var: $INSTALLER_DIR"

  # 2. Check installer-path.txt at AC root
  elif [[ -f "$AC_ROOT/installer-path.txt" ]]; then
    INSTALLER_CANDIDATE="$(cat "$AC_ROOT/installer-path.txt" | tr -d '\n\r')"
    if [[ -d "$INSTALLER_CANDIDATE/scaffold" ]]; then
      INSTALLER_DIR="$INSTALLER_CANDIDATE"
      echo "  ✓ Found via installer-path.txt: $INSTALLER_DIR"
    else
      echo "  ✗ installer-path.txt points to: $INSTALLER_CANDIDATE" >&2
      echo "    But scaffold/ not found there." >&2
    fi
  fi

  if [[ -z "$INSTALLER_DIR" ]]; then
    echo "" >&2
    echo "  Error: Cannot locate AgentComms installer repo." >&2
    echo "" >&2
    echo "  To fix, set the AGENTCOMMS_INSTALLER env var:" >&2
    echo "    export AGENTCOMMS_INSTALLER=/path/to/cloned/agentcomms" >&2
    echo "    bash $0 --example" >&2
    echo "" >&2
    echo "  Or re-run setup.sh from the installer repo to regenerate installer-path.txt." >&2
    exit 1
  fi

  SCAFFOLD_DIR="$INSTALLER_DIR/scaffold"

  echo "→ Restoring example content from scaffold..."

  # Copy agents
  if [[ -d "$SCAFFOLD_DIR/agents" ]]; then
    cp -R "$SCAFFOLD_DIR/agents/." "$AC_ROOT/agents/"
    echo "  ✓ agents/"
  fi

  # Copy threads (may be empty)
  if [[ -d "$SCAFFOLD_DIR/threads" ]]; then
    cp -R "$SCAFFOLD_DIR/threads/." "$AC_ROOT/threads/" 2>/dev/null || true
    echo "  ✓ threads/"
  fi

  # Copy archive
  if [[ -d "$SCAFFOLD_DIR/archive" ]]; then
    cp -R "$SCAFFOLD_DIR/archive/." "$AC_ROOT/archive/"
    echo "  ✓ archive/"
  fi

  STATE="example content restored"
else
  STATE="clean"
fi

# ─── Success ──────────────────────────────────────────────────────────────────
echo ""
echo "✅ AgentComms reset complete."
echo "   → Instance: $AC_ROOT"
echo "   → State: $STATE"
echo ""
