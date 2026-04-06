#!/usr/bin/env bash
# start.sh — Launch the AgentComms Dashboard
# Usage: bash start.sh [--no-open] [--port 7843]
# 
# Starts the dashboard server in the background and optionally opens a browser.
# By default, listens on http://localhost:7843 and auto-opens in your browser.

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTCOMMS_PATH="$(dirname "$SCRIPT_DIR")"
PORT=7843
AUTO_OPEN=true

# ─── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-open)
      AUTO_OPEN=false
      shift
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash start.sh [--no-open] [--port 7843]" >&2
      exit 1
      ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# ─── Check Node.js ───────────────────────────────────────────────────────────
if ! has_cmd node; then
  echo "Error: Node.js is not installed or not in PATH" >&2
  echo "Install from: https://nodejs.org/" >&2
  exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VERSION" -lt 14 ]]; then
  echo "Error: Node.js 14 or higher required (found: $(node -v))" >&2
  exit 1
fi

# ─── Start server in background ──────────────────────────────────────────────
export AGENTCOMMS_PATH
export AGENTCOMMS_PORT=$PORT

cd "$SCRIPT_DIR"

echo ""
echo "Starting AgentComms Dashboard..."
echo ""

# Start server and capture PID
node server.js "$PORT" &
SERVER_PID=$!

# Give server a moment to start
sleep 1

# Check if server is still running
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "✗ Failed to start dashboard server" >&2
  exit 1
fi

echo "AgentComms Dashboard started in the background (PID $SERVER_PID)"
echo "→ http://localhost:$PORT"
echo "Stop it: click \"Stop Server\" in the dashboard, or run: kill $SERVER_PID"
echo ""

# ─── Auto-open browser ───────────────────────────────────────────────────────
if [[ "$AUTO_OPEN" == "true" ]]; then
  URL="http://localhost:$PORT"
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open "$URL"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if has_cmd xdg-open; then
      xdg-open "$URL"
    elif has_cmd firefox; then
      firefox "$URL" &
    elif has_cmd chromium; then
      chromium "$URL" &
    fi
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows
    start "$URL"
  fi
fi

# Script exits here, returning the terminal to the user.
# The server continues running in the background.
# Use the Stop button in the dashboard UI or: kill $SERVER_PID
