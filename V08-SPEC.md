# AgentComms v0.8 — Product Spec
*Author: Shorty 🥃 | Date: 2026-03-28 | Status: DRAFT — ready for Codey*

---

## Goals for v0.8

1. Merge the two diverged `server.js` codebases into a single canonical v0.8
2. Add Dispatcher toggle (enable/disable the agentcomms-dispatcher cron)
3. Add Agent Wake (manually trigger an agent to check their inbox)

The repo `server.js` (from `server.js.shorty-ref`) is the reference for what Shorty is currently running locally. v0.8 should start from that codebase — it is the more capable of the two — and layer the dispatcher features on top.

---

## Context: The Divergence

Two versions of `server.js` exist:

| | Repo `server.js` | Shorty's local (`server.js.shorty-ref`) |
|---|---|---|
| Port | 7842 | 7843 |
| Multi-instance | ✅ (instances.json) | ✅ (instances.json) |
| MAILBOX.md parsing | ❌ | ✅ |
| MEMBERS.md / ghost detection | ❌ | ✅ |
| `agentcomms-version` file support | ❌ (README.md only) | ✅ |
| `/shutdown` endpoint (Stop button) | ❌ | ✅ |
| `/switch-instance` (rewires watcher) | ❌ | ✅ |
| Path security (`isPathSafe`) | ❌ | ✅ |
| `__DASHBOARD_ORIGIN__` injection | ❌ | ✅ |
| Dispatcher toggle/wake | ✅ | ❌ |
| Outbox scanning | ✅ | ❌ |
| Collection threads (date subfolders) | ✅ | ❌ |
| Thread title from brief.md | ✅ | ❌ |
| `involvedAgents` in thread data | ✅ | ❌ |

**Resolution:** Start from `server.js.shorty-ref`. Bring the repo's unique features into it. The result is `v0.8`.

---

## Item 1 — Merge: Bring Repo Features into Shorty's Base

### 1a. Outbox scanning

In `scanAgentComms()`, add outbox file counting alongside inbox:

```js
const outboxPath = path.join(agentPath, 'outbox');
const outboxFiles = safeReadDir(outboxPath).filter(f =>
  f !== '.keep' && !f.startsWith('.')
);
agentObj.outboxCount = outboxFiles.length;
agentObj.outboxFiles = outboxFiles;
```

No UI changes required — expose in data; frontend can surface as needed.

### 1b. Collection threads

In `scanThreadDir()`, detect thread folders whose children are date-stamped subfolders (`/^\d{4}-\d{2}-\d{2}$/`). If found, treat each date subfolder as a virtual thread with slug `parentFolder/YYYY-MM-DD` and title `parent folder name — YYYY-MM-DD`.

### 1c. Thread enrichment

In `parseThread()` (or equivalent), add:
- `title`: derive from `status.md` first, fall back to first non-empty line of `brief.md`, fall back to slug with dashes replaced by spaces
- `involvedAgents`: extract from thread slug + filenames by matching against the known agent list
- `summary`: first 120 chars of status.md or brief.md (already partially present — standardize)

### 1d. Port

Keep `7843` (Shorty's local standard). The repo's `7842` is superseded.

---

## Item 2 — Dispatcher Toggle

**Problem:** The agentcomms-dispatcher cron job runs on a schedule, but there's no way to pause it from the dashboard. When testing or debugging, you want to temporarily disable automatic dispatch without going to the CLI.

**Solution:** A toggle in the dashboard header that shows dispatcher status and lets you enable/disable it with one click.

### 2a. Server endpoints

**`GET /dispatcher/status`**

Returns:
```json
{
  "enabled": true,
  "jobId": "098c1398-aedd-49e9-aff7-aa8cef72120c",
  "status": "ok"
}
```

Implementation: shell out to `openclaw cron list --json`, find the job by ID or name `agentcomms-dispatcher`, return enabled state.

**`POST /dispatcher/toggle`**

Body: `{ "enable": true | false }`

Implementation: shell out to `openclaw cron enable <jobId>` or `openclaw cron disable <jobId>`.

Returns: `{ "ok": true, "enabled": true|false }` or `{ "ok": false, "error": "..." }`.

On success, broadcast an SSE event `{ "type": "dispatcher", "enabled": true|false }` so all open clients update without a page reload.

### 2b. Constants

```js
const DISPATCHER_JOB_ID = '098c1398-aedd-49e9-aff7-aa8cef72120c';
const OPENCLAW_BIN = '/usr/local/bin/node /usr/local/bin/openclaw';
```

Both defined at the top of `server.js`. No config file needed — these are stable.

### 2c. Frontend

Add a dispatcher status pill to the dashboard header, next to the Stop button:

- **Green pill** `● Dispatcher ON` when enabled
- **Red pill** `○ Dispatcher OFF` when disabled
- **Gray pill** `Dispatcher ?` when status fetch fails

Clicking the pill toggles state. Show a brief loading state during the POST. On SSE `dispatcher` event, update pill without reload.

Fetch dispatcher status on page load (single `GET /dispatcher/status`). Re-fetch on SSE `dispatcher` event.

---

## Item 3 — Agent Wake

**Problem:** When an agent's inbox has unprocessed files, you want to manually trigger them to run — without waiting for the next dispatcher cycle or going to the CLI.

**Solution:** A Wake button on each agent card in the dashboard.

### 3a. Server endpoint

**`POST /dispatcher/wake`**

Body: `{ "agentId": "shorty" }`

Implementation:

1. Read `config/agent-dispatch.json` to get the agent's inbox path (fall back to `AgentComms/agents/<agentId>/inbox` if not found)
2. Spawn the agent via the Gateway REST API (`POST http://localhost:18789/api/sessions/spawn`) with a standard wake message prompting them to check their inbox
3. Return `{ "ok": true, "message": "Wake signal sent to <agentId>" }` or `{ "ok": false, "error": "..." }`

Standard wake message:
```
Check your AgentComms inbox at <inboxPath> for any new routing signals.
If inbox is empty, reply NO_REPLY and stop.
If there ARE new files: 1) Read the routing signal to find the thread folder.
2) Read the brief.md in that thread folder for the full task.
3) Complete the task as instructed.
4) Update the thread's status.md to done.
5) Move the inbox signal file to your processed/ folder.
```

### 3b. Frontend

On each agent card, add a **Wake ▶** button that appears when `inboxCount > 0`.

- Clicking Wake POSTs to `/dispatcher/wake` with `{ agentId: agent.name }`
- Show a brief spinner / "Waking…" state
- On success: flash the card green, show "Sent ✓"
- On error: show error inline on the card
- Button is disabled (greyed out) when `inboxCount === 0`

---

## Out of Scope for v0.8

- Dispatcher job configuration (changing schedule, target agents) — v0.9+
- Thread creation from the dashboard — v0.9+
- Auth / hosted deployment — v1.0+
- Delete mailbox UI — deferred (low priority, teardown script covers the use case)

---

## Definition of Done

- [ ] `server.js` starts from `server.js.shorty-ref` (v0.7 Shorty base)
- [ ] Outbox scanning added to `scanAgentComms()`
- [ ] Collection thread detection in `scanThreadDir()`
- [ ] Thread `title`, `involvedAgents`, `summary` populated consistently
- [ ] `GET /dispatcher/status` returns enabled state
- [ ] `POST /dispatcher/toggle` enables/disables dispatcher cron; broadcasts SSE event
- [ ] `POST /dispatcher/wake` spawns agent via Gateway REST API
- [ ] `server.js.shorty-ref` removed from repo (superseded by v0.8)
- [ ] Frontend: dispatcher status pill in header with toggle
- [ ] Frontend: Wake button on agent cards when inbox > 0
- [ ] Dashboard tested against tPP, IT-Comms, and MJ instances
- [ ] All changes committed and pushed to `theProductPath/AgentComms`

---

## Notes

- `server.js.shorty-ref` was added to the repo as a snapshot of Shorty's diverged local build. Once v0.8 ships, that file should be deleted — the divergence is resolved.
- Port stays at `7843`. If the repo was shipping `7842`, that's now superseded. Update `start.sh` accordingly.
- Shorty's local copy (`workspace/apps/agentcomms-dashboard/`) should be replaced with the v0.8 build when Codey ships it. Shorty will restart the server at that point.

---

*Spec written by Shorty 🥃 | Ready for Codey 👨💻*
