# AgentComms

**A structured file-system communication layer for agent teams.**

Most agent teams hit the same problem: every handoff routes through a human. The human becomes the relay — forwarding context, re-explaining tasks, translating between agents. AgentComms removes that bottleneck. It's a local folder structure (inboxes, threads, archive) plus an optional dashboard that agents use to coordinate directly. No cloud, no npm, no build step — just a shell script and a folder convention that works out of the box.

---

## How It Works

AgentComms uses three zones:

- **`agents/*/inbox/`** — Routing signals only. An inbox file says "there's work for you in threads/." Small, fast, easy to scan.
- **`threads/`** — All active work. Each task gets a folder with a brief, context, status, Q&A, and result.
- **`archive/`** — Completed threads. Everything that's done moves here. The archive is never deleted.

Agents check their inbox, read the signal, open the thread, do the work, write the result, and archive. The human can observe at any point via the dashboard — or just check the archive when something's done.

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/theProductPath/agentcomms.git
cd agentcomms

# 2. Run setup — creates an AgentComms instance in ./AgentComms
bash setup.sh

# 3. Start the dashboard
node AgentComms/dashboard/server.js
# → http://localhost:7842
```

That's it. You now have a working AgentComms instance with example files and a running dashboard.

**Custom path or team name:**
```bash
bash setup.sh --path ~/my-team/AgentComms --team "my-team"
```

---

## Folder Structure

```
AgentComms/
├── agents/                          # One folder per agent
│   └── <agent-name>/
│       ├── inbox/                   # Routing signals land here
│       │   ├── processed/           # Signals moved here after reading
│       │   └── YYYY-MM-DD_slug.md   # Routing signal (pointer to thread)
│       └── outbox/                  # Outbound signals (optional)
│
├── threads/                         # Active work — one folder per task
│   └── YYYY-MM-DD_descriptive-slug/
│       ├── brief.md                 # Full assignment spec
│       ├── context.md               # Background and constraints (optional)
│       ├── status.md                # open | in-progress | blocked | done
│       ├── result.md                # Final deliverable (written when complete)
│       └── HHMMSS_from-to.md        # Q&A exchanges (timestamped)
│
├── archive/                         # Completed threads (moved from threads/)
│   └── YYYY-MM-DD_descriptive-slug/ # Same structure as threads/
│
├── dashboard/                       # Local dashboard
│   ├── index.html
│   ├── server.js
│   └── README.md
│
└── COMMUNICATION_PROTOCOL.md        # Protocol reference for all agents
```

---

## The Protocol

Five rules that govern everything:

1. **Brief-First** — Every task starts with a written `brief.md`. No brief, no work.
2. **Inbox as Signal** — Inboxes carry routing signals only. Full briefs and deliverables live in thread folders, not inboxes.
3. **Q&A in Thread** — All task questions and answers happen in the thread folder. Not in Telegram. Not in a new inbox message.
4. **Done = Archived** — A task isn't done until `result.md` is written, `status.md` says `done`, and the thread folder is in `archive/`.
5. **Inbox Monitoring** — Agents are responsible for checking their inbox. Process oldest-first. Move signals to `processed/` and verify the move before marking done.

Full details: see [`COMMUNICATION_PROTOCOL.md`](./COMMUNICATION_PROTOCOL.md) inside your AgentComms instance.

---

## Dashboard

The dashboard gives operators a live view of the AgentComms instance — who has work waiting, what's in flight, what's blocked.

```bash
# Start the dashboard
node AgentComms/dashboard/server.js

# Custom port
node AgentComms/dashboard/server.js 8080
```

Then open `http://localhost:7842` in your browser.

**What it shows:**
- **Stats bar** — agents active, messages in flight, threads open, archived count
- **Agents panel** — one card per agent, with inbox count and last activity; agents with unread messages are highlighted
- **Threads table** — all active threads, sortable by date/status/last updated; click a row for detail
- **Thread detail shelf** — inline file viewer for briefs, results, Q&A files
- **Activity map** — canvas view of agents as nodes and threads as connections between them

**Zero-dependency constraint:** `server.js` uses only Node.js built-ins (`http`, `fs`, `path`). No `package.json`, no `node_modules`. Works with Node.js ≥ 14.

See [`dashboard/README.md`](./dashboard/README.md) for configuration details.

---

## Adding an Agent

See [`AGENT-ONBOARDING.md`](./AGENT-ONBOARDING.md) for full onboarding instructions.

The short version: create a folder at `agents/<agent-name>/` with `inbox/`, `inbox/processed/`, and `outbox/` subfolders, then give the agent their inbox path. They're ready to receive tasks.

---

## Adapting for Your Team

Three config points to wire up a new team:

**1. `AGENTCOMMS` path in `dashboard/server.js`**
```js
const AGENTCOMMS = '/path/to/your/AgentComms';
```
Update this to point to your actual AgentComms instance folder.

**2. `AGENT_EMOJIS` map in `dashboard/server.js`**
```js
const AGENT_EMOJIS = {
  'ac-dev': '👨🏽‍💻',
  'ac-pm':  '📊',
  'ac-orch': '🎯',
};
```
Add your agents here so the dashboard renders their emojis correctly.

**3. Home path in `dashboard/index.html`**
There's a hardcoded home path used for constructing inbox file paths in the browser. Search for `AGENTCOMMS_PATH` in `index.html` and update it to match your instance.

---

## License

MIT
