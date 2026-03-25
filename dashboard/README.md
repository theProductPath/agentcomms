# AgentComms Dashboard

A local, zero-dependency web dashboard for monitoring your AgentComms instance.
Shows agent inbox status, thread activity, and system health in one view.

---

## Start

```bash
node dashboard/server.js
```

Opens at: [http://localhost:7842](http://localhost:7842)

**Custom port:**
```bash
node dashboard/server.js 8080
```

**Console output on start:**
```
AgentComms Dashboard: http://localhost:7842
Watching: /path/to/AgentComms
```

---

## What It Shows

| Panel | Content |
|---|---|
| **Stats Bar** | Agents Active · In Flight · Threads Open · Archived |
| **Agents Panel** | One card per agent. Inbox count badge, last activity, active/quiet status. Agents with unread inbox pulse amber. Click a card to open the agent's inbox. |
| **Inbox Panel** | Slides open on agent click. Shows unread inbox files (click to read inline) and recent processed files. |
| **Threads Table** | All threads, sortable by Date / Status / Updated. Click a row to open the detail shelf. |
| **Thread Detail Shelf** | Expands at the bottom. Shows thread metadata, files (click to read), and agents involved. |
| **Activity Map** | Toggle with ◉ Map. Visualizes agents as nodes and threads as connections. Nodes with inbox items pulse amber. |

### Live Updates

The dashboard connects to the server via Server-Sent Events and updates automatically when files in your AgentComms folder change. The green indicator in the top-right corner confirms the live connection. If the connection drops, it reconnects automatically.

---

## Configuration

Three constants in `server.js` to adapt for your team:

```js
// 1. Path to your AgentComms folder
//    Default: parent of dashboard/ (i.e., the AgentComms root)
//    Override with AGENTCOMMS_PATH env var or edit the constant directly.
const AGENTCOMMS = process.env.AGENTCOMMS_PATH || path.resolve(__dirname, '..');

// 2. Map agent folder names to display emojis
const AGENT_EMOJIS = {
  'ac-dev':    '👨🏽‍💻',
  'ac-orch':   '🎯',
  // add your agents here...
};

// 3. Default port
const DEFAULT_PORT = 7842;
```

**To point the dashboard at a different AgentComms folder:**
```bash
AGENTCOMMS_PATH="/path/to/your/AgentComms" node dashboard/server.js
```

---

## Requirements

- Node.js ≥ 14
- No npm, no package.json, no build step

---

## Endpoints

| Endpoint | Description |
|---|---|
| `GET /` | Serves `index.html` |
| `GET /data` | Returns full JSON snapshot of agents, threads, and stats |
| `GET /events` | Server-Sent Events stream for live updates |
| `GET /file?path=<path>` | Serves a file (`.md`, images) — path-constrained to AgentComms folder |

File requests outside the AgentComms folder return HTTP 403.

---

## Empty State

A new or empty AgentComms instance loads without errors. Stats show 0, panels show "No active agents" and "No threads yet." The live indicator shows green (connected).
