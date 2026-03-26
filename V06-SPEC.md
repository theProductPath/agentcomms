# AgentComms v0.6 — Product Spec
*Author: Stratty 🎯 (PM) | Date: 2026-03-26 | Reviewed by: Shorty 🥃 | Assignee: Codey 👨💻*
*Reference implementation: `~/.openclaw/workspace/apps/agentcomms-dashboard/` and `~/.openclaw/workspace/scripts/`*

---

## Goals for v0.6

1. Fix known bugs from v0.5
2. Improve first-run experience so a new user understands the product immediately
3. Clarify README so setup is unambiguous
4. Incorporate Shorty's shipped features (checkmail, dashboard instance switching/management)
5. Make the dashboard server easy to start, background, and stop
6. Deprecate outbox
7. Leave the product in a state ready for internal team adoption and public promotion

---

## Item 1 — Dashboard: Agent Card Rendering Bug (Bug Fix)

**Status:** Fixed in Shorty's live version — replicate the fix.

**Root cause:** The inbox panel was being initialized before agent cards rendered. The fix: `render(data)` must call `renderAgents()` first on every load, before any panel initialization. Do not initialize inbox panel state until after the first render pass.

**Expected result:** `example-agent` card visible immediately on load — amber-highlighted with inbox badge.

---

## Item 2 — Example Files: Improve First-Run Experience (UX)

**Build fresh — Shorty has no reference for this.**

Update `scaffold/` so the out-of-the-box experience shows a team with visible activity:

- **2 unread inbox signals** for `example-agent` (badge shows count > 1, amber glow is obvious)
- **1 processed signal** (user sees what "done" looks like)
- **2 threads:** one `in-progress`, one in `archive/` with status `done`
- The 2 unread signals should point to the 2 threads respectively

Goal: new user opens dashboard, immediately sees a team with activity. Contrast between unread and processed is obvious. Thread table has multiple rows with different status values.

---

## Item 3 — README: Clarify Setup Path and Dashboard Invocation (Documentation)

**Write fresh per spec — Shorty's README is not shippable.**

Update Quick Start section to make repo-vs-target distinction explicit:

```bash
# 1. Clone the repo — this is the installer, not the destination
git clone https://github.com/theProductPath/agentcomms.git
cd agentcomms

# 2. Go to the folder where you want your AgentComms to live
cd ~/Documents   # or wherever you want it

# 3. Run setup from there, pointing at the cloned repo
bash ~/path/to/agentcomms/setup.sh

# 4. Start the dashboard from your new AgentComms folder
bash AgentComms/dashboard/start.sh
# → Opens at http://localhost:7842
```

Add a callout:
> **The repo is the installer, not the destination.** `setup.sh` creates your AgentComms folder wherever you run it from. The dashboard, examples, and protocol files all live in that new folder — not in the repo you cloned.

Update Folder Structure section to use `~/Documents/AgentComms/` as the example path (makes it clear the target is separate from the repo).

---

## Item 4 — Dashboard Server: Background Mode + Browser Auto-Open + Kill Switch

**Shorty's `start.sh` is partial — extend it per this spec.**

**4a. Background mode with PID output**
`start.sh` should launch the server in the background and return the terminal:
```bash
node dashboard/server.js "$AGENTCOMMS_PATH" &
SERVER_PID=$!
echo "AgentComms Dashboard started (PID $SERVER_PID)"
echo "→ http://localhost:7842"
echo "Use the dashboard Stop button or: kill $SERVER_PID"
```
Use relative paths only — no hardcoded absolute paths (Shorty's current version hardcodes `/Users/jonestrebski/...` — fix this).

**4b. Auto-open browser**
After start, open `http://localhost:7842` automatically:
- macOS: `open http://localhost:7842`
- Linux: `xdg-open http://localhost:7842`
- Optional `--no-open` flag to skip

**4c. Kill switch in dashboard UI**
Add "⏹ Stop Server" button in the dashboard header.
- Click → confirmation dialog: "Stop the AgentComms Dashboard server?"
- Confirm → calls `/shutdown` endpoint on server
- Server logs "AgentComms Dashboard stopped." and exits cleanly
- Browser shows: "Server stopped. You can close this tab."

**4d. setup.sh success output**
Update the final success message to reference `start.sh`:
```
Dashboard:   bash AgentComms/dashboard/start.sh
             → Opens at http://localhost:7842
```

---

## Item 5 — Dashboard: Instance Switching + Management

**Shorty's implementation is complete — bring it in cleanly with these fixes.**

**5a–5c. Instance switching, add, remove** — match Shorty's live implementation exactly.

**5d. Compatibility check** — check AgentComms root for:
```
agentcomms-version: 1
```
Show a clear warning if missing or incompatible.

**5e. No hardcoded paths — FIX REQUIRED**
Shorty's `index.html` still has `INSTANCE_PATHS` as a hardcoded JS object alongside `instances.json`. This is a bug.
- The frontend must derive all paths from the `/instances` API response only
- Remove `INSTANCE_PATHS` hardcoded constant from `index.html`
- `AGENTCOMMS` in `server.js` must come from CLI arg or `AGENTCOMMS_PATH` env var — not hardcoded
- `instances.json` default entry must be derived from the CLI arg, not hardcoded

**Correct invocation:**
```bash
node server.js /path/to/AgentComms
# or
AGENTCOMMS_PATH=/path/to/AgentComms node server.js
```

**5f. Multi-instance watcher — known gap (v0.7)**
Current implementation only watches the default instance for file changes. Switching instances in the dropdown does not update the file watcher — live SSE updates won't fire for non-default instances. This is a known limitation. Document it in `dashboard/README.md` as a v0.7 item. Do not ship it as fully working.

---

## Item 6 — checkmail Command

**Shorty's implementation is complete — bring scripts into the repo cleanly.**

**Commands:**
| Command | Output |
|---------|--------|
| `checkmail` or `#checkmail` | All inboxes (`#` prefix optional) |
| `checkmail threads` | All inboxes + open threads column |
| `mailcheck`, `check mail`, `inbox check`, `agent status` | All resolve the same |

**Output format (include age column — missing from original spec):**
```
📬 Mail Check — 1:24 PM CT

AgentComms
🔴 agent-name    2    39m
✅ 3 others clear

────────────────────────
```
Columns: emoji+name | unread count | age of oldest unread (m/h/d)
With `threads`: add active thread names, max 3 + overflow count.
Thread column filters: exclude status `done`, `closed`, `archived`, `pending-archive`, `complete`.

**Path config — FIX REQUIRED**
Shorty's current `inbox-snapshot.sh` uses hardcoded paths per instance. The product version must use proper path resolution:
- Default: auto-infer from script location (one level up from `scripts/`)
- Override: `AGENTCOMMS_PATH` env var
- Multi-instance: commented block at top of script for additional paths

Remove all hardcoded `/Users/jonestrebski/...` paths.

**Scope:** `checkmail` is an operator tool, not an agent onboarding item. Document in `dashboard/README.md` and repo `README.md` under "Operator Tools". Not in `AGENT-ONBOARDING.md`.

---

## Item 7 — "Adding an Agent" Section in README

**Not in Shorty's README — write fresh.**

New section in `README.md`:

```
## Adding an Agent

1. Create their folder: `agents/<agent-name>/inbox/` and `agents/<agent-name>/inbox/processed/`
2. Give the agent their inbox path (update their workspace TOOLS.md or SOUL.md)
3. Optionally add them to `AGENT_EMOJIS` in `dashboard/server.js`
4. Optionally set up inbox cron polling (see AGENT-ONBOARDING.md)
```

No outbox step — outbox is deprecated (see Item 9).

---

## Item 8 — setup.sh: Include scripts/ in Copy Step

Include `scripts/inbox-snapshot.sh` and `scripts/_thread_scan.py` in the repo and add a copy step to `setup.sh`:
```
→ Copying scripts...
  ✓ scripts/inbox-snapshot.sh
  ✓ scripts/_thread_scan.py
```
Update success output to mention scripts are available.

---

## Item 9 — Outbox Deprecation

**Confirmed by Shorty — remove entirely.**

- Remove `scaffold/agents/example-agent/outbox/` and `outbox/.keep` from scaffold
- Remove outbox references from `server.js`: `outboxPath`, `outboxFiles`, `outboxCount` (approx lines 95, 119, 120, 129, 144 in Shorty's version — find and remove in the product version)
- Remove outbox from the "Adding an Agent" README section
- Remove outbox from `AGENT-ONBOARDING.md`
- Do NOT delete existing outbox folders from live instances — just stop creating new ones

---

## Item 10 — Version Tag

`setup.sh` writes a version tag into the generated `COMMUNICATION_PROTOCOL.md` or a new `AGENTCOMMS-VERSION` file at the AgentComms root:
```
agentcomms-version: 1
```
This enables dashboard compatibility validation (Item 5d).

---

## Item 11 — Shorty Easter Egg 🥃

Hide a tribute to Shorty somewhere in the product. Codey has creative latitude here — be clever, not obvious. Some constraints:
- Must be discoverable (not just a comment in source code)
- Must include Shorty's name and emoji (🥃)
- Should feel like a reward for curiosity, not a distraction from normal use
- Appropriate examples: a hidden keyboard shortcut that reveals a message, a secret dashboard view, something in the about/footer area, a console message on start, an easter egg in the checkmail output

Codey: surprise us.

---

## Out of Scope for v0.6
- Multi-instance watcher fix (v0.7 — documented as known gap)
- Scheduled checkmail digest (v0.7)
- Thread triage / stale thread flagging (v0.7)
- Hosted deployment, auth, multi-team server (v1.0+)

---

## Definition of Done

- [ ] Agent card renders correctly on first dashboard load
- [ ] Example scaffold has 2 unread + 1 processed signal, 2 threads (1 in-progress, 1 archived)
- [ ] README Quick Start clearly distinguishes repo from install target
- [ ] `start.sh` backgrounds server, prints PID, auto-opens browser
- [ ] Kill switch button in dashboard UI calls `/shutdown` and exits cleanly
- [ ] Instance switching works — dropdown switches data and SSE without page reload
- [ ] Add/remove instance UI works with folder browser and validation
- [ ] No hardcoded paths in `server.js`, `index.html`, `start.sh`, or `inbox-snapshot.sh`
- [ ] `checkmail` script included in repo and setup.sh copy step; output includes age column
- [ ] "Adding an Agent" section in README (no outbox)
- [ ] Outbox removed from scaffold and server.js
- [ ] `agentcomms-version: 1` tag written by setup.sh
- [ ] Multi-instance watcher gap documented in dashboard/README.md as v0.7
- [ ] Shorty easter egg present and discoverable
- [ ] All changes committed and pushed to `theProductPath/agentcomms`

---

*Spec written by Stratty 🎯 | Reviewed by Shorty 🥃 | Ready for Codey 👨💻*
