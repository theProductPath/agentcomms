# AgentComms

**A structured file-system communication layer for agent teams.**
`agentcomms-version: 1`
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

**The repo is the installer, not the destination.** `setup.sh` creates your AgentComms instance in a new folder of your choosing. All files — dashboard, examples, and protocols — live in that new folder, not in the repo you cloned.

```bash
# 1. Clone the repo — this is the installer only
git clone https://github.com/theProductPath/agentcomms.git
cd agentcomms

# 2. Go to the folder where you want your AgentComms to live
cd ~/Documents   # or ~/my-team or wherever you prefer

# 3. Run setup from there, pointing to the cloned repo
bash ~/path/to/agentcomms/setup.sh

# 4. Start the dashboard from your AgentComms folder
bash AgentComms/dashboard/start.sh
# → Dashboard opens at http://localhost:7843
```

That's it. You now have a working AgentComms instance with example files and a running dashboard.

**Custom path or team name:**
```bash
bash ~/path/to/agentcomms/setup.sh --path ~/my-team/AgentComms --team "my-team"
```

---

## Folder Structure

```
AgentComms/
├── agents/                          # One folder per agent
│   └── <agent-name>/
│       └── inbox/                   # Routing signals land here
│           ├── processed/           # Signals moved here after reading
│           └── YYYY-MM-DD_slug.md   # Routing signal (pointer to thread)
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
├── dashboard/                       # Local dashboard (port 7843)
│   ├── index.html
│   ├── server.js
│   ├── start.sh
│   └── README.md
│
├── scripts/                         # Operator tools
│   ├── inbox-snapshot.sh            # Checkmail command (email, Telegram, etc.)
│   └── _thread_scan.py              # Helper for inbox snapshot
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
# Start the dashboard (auto-opens in browser)
bash AgentComms/dashboard/start.sh

# Don't auto-open browser
bash AgentComms/dashboard/start.sh --no-open

# Custom port
bash AgentComms/dashboard/start.sh --port 8080
```

The dashboard starts at `http://localhost:7843` by default. A **Stop** button in the header lets you shut down the server cleanly.

**What it shows:**
- **Stats bar** — agents active, messages in flight, threads open, archived count
- **Agents panel** — one card per agent, with inbox count and last activity; agents with unread messages are highlighted in amber
- **Threads table** — all active threads, sortable by date/status/last updated; click a row for detail
- **Thread detail shelf** — inline file viewer for briefs, results, Q&A files
- **Activity map** — canvas view of agents as nodes and threads as connections between them

**Zero-dependency constraint:** `server.js` uses only Node.js built-ins (`http`, `fs`, `path`). No `package.json`, no `node_modules`. Works with Node.js ≥ 14.

See [`dashboard/README.md`](./dashboard/README.md) for configuration details.

---

## Inbox Snapshot

Get a full view of every agent's inbox and all open threads delivered to any chat channel — no dashboard required.

```bash
# Run from anywhere with filesystem access
bash AgentComms/scripts/inbox-snapshot.sh
```

**Sample output:**
```
📬 AgentComms Snapshot
Thu Mar 26, 10:01 AM CT

── AgentComms ──────────────────
⚠️  Needs attention:
  🔴 hairy — 2 unread (last active: 2026-03-24)
     ↳ 2026-03-24_skill-request, 2026-03-24_weekly-check

✅  Clear:
  archy (last: 2026-03-25)
  copy (last: 2026-03-26)

── Open Threads ────────────────
  📂 2026-03-20_conference-floor-rework-spec — IN PROGRESS
  📂 2026-03-25_atp-overview-article — Ready for Review

────────────────────────────────
```

**How it works:**
- Scans all inbox folders and reports agents with unread signals first (backlog-first)
- Shows last-active dates even for clear inboxes — stale agents surface even when technically "clear"
- Filters out threads with terminal status (`done`, `closed`, `archived`, `pending-archive`, `complete`)
- Outputs plain text — suitable for direct Telegram delivery or any other channel

**Usage with an agent:** Configure an agent to run this script when it receives a natural-language trigger ("inbox check," "agent status," "how are the inboxes?"). The agent runs the script and returns the output inline in the conversation. No need to open the dashboard.

**Configuring paths:** Edit the path constants at the top of `scripts/inbox-snapshot.sh`. The script ships pre-configured to work with an AgentComms instance created by `setup.sh`.

See [`scripts/README.md`](./scripts/README.md) for full configuration details.

---

## Adding an Agent

To bring a new agent into your AgentComms instance:

1. **Create their inbox folders:**
   ```bash
   mkdir -p AgentComms/agents/<agent-name>/inbox/processed
   ```

2. **Share their inbox path** with the agent (update their workspace config):
   ```
   ~/path/to/AgentComms/agents/<agent-name>/inbox/
   ```

3. *(Optional)* **Add their emoji** to the dashboard:
   Edit `AgentComms/dashboard/server.js`, find `AGENT_EMOJIS`, and add:
   ```js
   'agent-name': '🎯',  // or any emoji you like
   ```

4. *(Optional)* **Set up automated inbox polling:**
   See [`AGENT-ONBOARDING.md`](./AGENT-ONBOARDING.md) for cron job setup so agents auto-check their inbox on a schedule.

That's it. They can now receive tasks via inbox signals and start working.

---

## Operator Tools

### Inbox Snapshot (checkmail)

Get a full view of every agent's inbox and all open threads without opening the dashboard:

```bash
bash AgentComms/scripts/inbox-snapshot.sh
```

Use this to monitor team status via email, Telegram, or any other channel. Agents can also trigger it when they receive a natural-language "inbox check" request.

**Supported aliases:**
- `checkmail` or `#checkmail`
- `check mail`, `mailcheck`, `inbox check`, `agent status`

See [`scripts/README.md`](./scripts/README.md) for full usage and configuration.

---

## License

MIT
