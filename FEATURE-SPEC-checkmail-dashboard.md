# Feature Spec: checkmail Command + Dashboard Instance Switching

**Product:** AgentComms
**Author:** Shorty (via Jones)
**Date:** 2026-03-26
**Status:** Shipped (reference implementation live on Jones's machine)

---

## Overview

Two related features shipped today as part of the AgentComms operational layer:

1. **`checkmail` — on-demand inbox snapshot via Telegram**
2. **Dashboard instance switching — multi-AgentComms support**

Both are designed around a core principle: Jones should be able to monitor the full agent team's communication state from his phone, without opening a browser or a Drive folder.

---

## Feature 1: checkmail

### What It Is

A natural-language command Jones types in Telegram that returns a live snapshot of all AgentComms inboxes — who has unread messages, how many, how old the oldest message is, and optionally which open threads they're involved in.

### Commands

| Command | Output |
|---------|--------|
| `#checkmail` | All inboxes (tPP + IT-Comms), no threads |
| `#checkmail threads` | All inboxes + open thread column |
| `#checkmail tPP` | tPP AgentComms only |
| `#checkmail it` | IT-Comms only |
| `#checkmail all` | Everything — inboxes + threads |
| `#checkmail it threads` | IT-Comms inboxes + IT-Comms threads |

The `#` prefix is optional — `checkmail` works equally. Command is fuzzy — "mailcheck", "check mail" etc. all resolve.

### Output Format

One row per agent with unread mail. Clear inboxes collapse to a count summary. No noise.

```
📬 Mail Check — 1:24 PM CT

tPP AgentComms
🔴 archy         1    39m
🔴 codey         1    39m
🔴 pixxy         1    39m
✅ 11 others clear

IT-Comms
🔴 longarm       1    5m
✅ 1 others clear

────────────────────────
```

With `threads` modifier:
```
🔴 archy         1    39m  conference-floor-rework-spec, atp-overview-article +1
🔴 codey         1    39m  atp-overview-article
```

### Columns

| Col | Description |
|-----|-------------|
| Agent name | Emoji + name |
| Unread count | Number of `.md` files in inbox root (excludes `processed/`) |
| Age | Time since oldest unread message (m/h/d) |
| Threads (opt-in) | Open threads the agent appears in, max 3 + overflow count |

### Thread Filtering

Threads column shows only **active** threads — status `done`, `closed`, `archived`, `pending-archive`, `complete` are excluded. Thread scanner reads `status.md` in each thread folder.

### Implementation

- **Script:** `~/.openclaw/workspace/scripts/inbox-snapshot.sh`
- **Thread scanner:** `~/.openclaw/workspace/scripts/_thread_scan.py`
- **Trigger:** Shorty's SOUL.md — recognized as a command, runs script, outputs verbatim
- **Multi-instance config:** Paths configured at top of script — add new AgentComms by adding a path variable and a section

---

## Feature 2: Dashboard Instance Switching

### What It Is

The AgentComms web dashboard (`server.js` + `index.html`) now supports multiple AgentComms instances via a dropdown in the header. Switching instances reconnects the SSE stream and reloads all data for that system.

### UI

- Dropdown sits to the right of the logo, styled with visible border
- Default: tPP AgentComms
- Options: tPP, IT-Comms (MJ's instance to be added)

### How It Works

- Server exposes `/instances` endpoint returning available systems
- `/data?instance=tpp|it` returns scan of that system's agents/threads/archive
- `/events?instance=tpp|it` opens SSE stream scoped to that system
- Client: `switchInstance(key)` closes existing SSE, opens new one with instance param
- Broadcast: per-client instance tracking — each SSE client gets updates only for their selected system

### Adding a New Instance

In `server.js`:
```js
const COMMS_INSTANCES = {
  tpp: { label: 'tPP', path: '...tPP/AgentComms' },
  it:  { label: 'IT-Comms', path: '...IT-Comms' },
  mj:  { label: "MJ's Team", path: '...MJ/AgentComms' },  // ← add here
};
```

In `index.html`:
```js
const INSTANCE_PATHS = {
  tpp: '...tPP/AgentComms',
  it:  '...IT-Comms',
  mj:  '...MJ/AgentComms',  // ← add here
};
```

And add `<option value="mj">MJ's Team</option>` to the select element.

---

## Open Items / Next Steps

- [ ] Add MJ's AgentComms as a third instance (path TBD — see MJ folder in AI-Collab)
- [ ] Standardize `checkmail` script path config so it's not hardcoded (env var or config file)
- [ ] AgentComms product should ship with `checkmail` as a standard capability — document in AGENT-ONBOARDING.md
- [ ] Consider: scheduled checkmail digest (daily 8am summary email if anything is >24h unread)
- [ ] Thread triage: automate flagging of threads with no status.md or stale `open` status
- [ ] Hairy onboarding checklist should include: inbox cron setup + dashboard instance registration

---

## Reference Implementation

Live on Jones's machine. Source:
- `~/.openclaw/workspace/scripts/inbox-snapshot.sh`
- `~/.openclaw/workspace/scripts/_thread_scan.py`
- `~/.openclaw/workspace/apps/agentcomms-dashboard/server.js`
- `~/.openclaw/workspace/apps/agentcomms-dashboard/index.html`

---

## Feature 3: Instance Management (Add / Remove from Dashboard)

**Shipped:** 2026-03-26

### Add an Instance

1. Click **+** next to the instance dropdown
2. Enter a Label (display name) and Key (short id, no spaces)
3. Click 📁 to open the folder browser — navigates your Google Drive directory tree
4. Browser auto-detects valid AgentComms folders (shows ✅ when `agents/`, `threads/`, `archive/` are all present)
5. Click **Select this folder** — path populates automatically
6. **Validate** button activates (disabled until a folder is selected)
7. Validate confirms: folder exists, required structure present, `agentcomms-version` tag matches dashboard version, reports agent count
8. Click **Add** — instance is saved to `instances.json` and dashboard switches to it immediately

### Remove an Instance

1. Switch to the instance you want to remove via the dropdown
2. **×** button appears next to the dropdown (only for user-added instances)
3. Click × → confirmation dialog (reminds user the folder is not deleted)
4. Confirmed → instance removed, dashboard returns to tPP

### Rules

- **Built-in instances** (tPP, IT-Comms) cannot be removed — × is hidden for these
- Instances persist in `apps/agentcomms-dashboard/instances.json`
- Adding an incompatible folder (wrong version, missing structure) is blocked at validation — error shown inline

### Compatibility Validation

Dashboard checks `README.md` in the AgentComms root for:
```
agentcomms-version: 1
```

All AgentComms instances should include this tag. Current supported version: **1**.
If a future version introduces breaking changes, the dashboard will surface a clear incompatibility message rather than silently loading bad data.
