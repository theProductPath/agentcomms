# Communication Protocol
*AgentComms v0.5 · theProductPath*

---

## Overview

AgentComms is a structured file-system communication layer for agent teams. It gives agents a way to coordinate asynchronously — passing tasks, tracking work, and archiving results — without routing every handoff through a human.

Three zones. One rule per zone. Everything else follows.

---

## The Three Zones

```
AgentComms/
├── agents/          ← SIGNALS: small routing files, point to threads
├── threads/         ← SUBSTANCE: all active work lives here
└── archive/         ← HISTORY: completed threads, never deleted
```

| Zone | What Lives Here | Rule |
|---|---|---|
| `agents/*/inbox/` | Routing signals only | Never store full briefs or deliverables here |
| `threads/` | Briefs, context, Q&A, results | One folder per task |
| `archive/` | Completed threads moved from threads/ | Never delete |

---

## The Five Protocols

### 1. Brief-First

Every task starts with a `brief.md`. Before any agent begins work, the task must be written down:

```markdown
# Task Title

## What
[Clear description of the deliverable]

## Why
[Context — why this matters, what it unblocks]

## Constraints
[Limits, requirements, non-negotiables]

## Done When
[Specific, verifiable completion criteria]
```

A brief lives in the thread folder. It is the source of truth for the task.

---

### 2. Inbox as Signal

Agent inboxes carry **routing signals only** — small files that say "there's work for you in threads/".

**Signal format:**
```markdown
# Task Name — Brief Waiting

Thread: threads/YYYY-MM-DD_task-slug/
From: sender-agent
Priority: normal | high | urgent
Mailbox: <mailbox-id>  (optional — include when sending cross-mailbox signals)
```

**What signals are not:**
- Full briefs (those go in the thread folder)
- Q&A exchanges (those go in the thread folder)
- Deliverables (those go in result.md)

**Processing rule:** Read the signal, note the thread, move the signal to `processed/`. Verify the move. Then open the thread and read `brief.md`.

---

### 3. Q&A in Thread

All task questions and answers happen in the thread folder — never in inboxes, never in external channels.

**Q&A file naming:** `HHMMSS_sender-recipient.md`  
*Example: `143022_ac-dev-ac-pm.md`*

**Q&A format:**
```markdown
# Question: [Subject]
From: [sender] → [recipient]
Time: HH:MM:SS

[Question text]

---

# Response
From: [recipient] → [sender]
Time: HH:MM:SS

[Answer text]
```

To ask a question: write the Q&A file in the thread folder, then drop a routing signal in the recipient's inbox pointing to the thread.

---

### 4. Done = Archived

A thread is not done until it's in the **top-level `archive/` folder**.

✅ Correct path:  `archive/YYYY-MM-DD_slug/`
❌ Wrong path:    `threads/archive/YYYY-MM-DD_slug/`  ← this should never exist

**The done sequence:**
1. Write `result.md` in the thread folder (the actual deliverable or summary)
2. Update `status.md` to `status: done`
3. Move the thread folder to the top-level archive:
   ```
   mv threads/YYYY-MM-DD_slug/  archive/YYYY-MM-DD_slug/
   ```

The archive is institutional memory. Nothing is ever deleted from it.

**Who owns the status?** The agent who created the thread owns `status.md`. Only the thread creator (or the human operator) should mark a thread `done`. If you completed your part but others are still working, update status to `in-progress` with a note — do not mark it `done`.

---

### 5. Inbox Monitoring

Agents are responsible for checking their inbox. There is no push notification layer in v0.5.

**Monitoring convention:**
- Check inbox at session start
- Process oldest-first (by filename date)
- Never leave signals unprocessed for more than one session cycle
- An unread signal in processed/ is not the same as being done — the task still needs to be executed

**Processing is complete when:**
- Signal has been moved to `processed/`
- Move has been verified with `ls`
- Thread has been opened and `brief.md` read
- Work has been started (or a blocker has been flagged)

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| Agent folders | Lowercase, hyphenated | `ac-dev`, `ac-pm`, `example-agent` |
| Thread folders | `YYYY-MM-DD_descriptive-slug` | `2026-03-24_api-auth-spec` |
| Inbox signals | `YYYY-MM-DD_task-slug.md` | `2026-03-24_build-dashboard.md` |
| Q&A files | `HHMMSS_sender-recipient.md` | `143022_ac-dev-ac-pm.md` |

---

## Status Values

The `status.md` file in every thread folder tracks the current state.

| Value | Meaning |
|---|---|
| `open` | Task created, not yet started |
| `in-progress` | Actively being worked on |
| `blocked` | Cannot proceed — blocker noted, signal sent |
| `done` | Work complete, result.md written |

**Format:**
```markdown
status: in-progress
assigned-to: agent-name
opened: YYYY-MM-DD
updated: YYYY-MM-DD
```

---

## Blocking Protocol

When an agent cannot proceed:

1. Update `status.md` to `status: blocked`
2. Write a note in the thread explaining: what's blocked, what's needed to unblock, who owns it
3. Drop a routing signal in the relevant person's inbox pointing to the thread
4. Don't wait — flag early, not after days of no progress

---

## Common Patterns

### Receiving a task
1. Read inbox signal → note thread path → move signal to processed/ → verify
2. Open thread → read brief.md → execute → write result.md → update status to done
3. Archive: move thread to archive/

### Sending a task to another agent
1. Create thread folder in `threads/YYYY-MM-DD_task-slug/`
2. Write `brief.md` (What / Why / Constraints / Done When)
3. Set `status.md` to `open`
4. Drop a routing signal in the recipient's inbox

### Asking a question mid-task
1. Create `HHMMSS_sender-recipient.md` in the thread folder
2. Drop a routing signal in the recipient's inbox pointing to the thread
3. Wait for their response in the same file

---

## File Reference

| File | Location | Purpose |
|---|---|---|
| `brief.md` | `threads/YYYY-MM-DD_slug/` | The full task specification |
| `context.md` | `threads/YYYY-MM-DD_slug/` | Background, constraints, prior work (optional) |
| `status.md` | `threads/YYYY-MM-DD_slug/` | Current state of the task |
| `result.md` | `threads/YYYY-MM-DD_slug/` | Final deliverable (written when done) |
| `HHMMSS_from-to.md` | `threads/YYYY-MM-DD_slug/` | Q&A exchanges |
| `YYYY-MM-DD_slug.md` | `agents/<name>/inbox/` | Routing signal (pointer to thread) |

---

*See `AGENT-ONBOARDING.md` for step-by-step onboarding instructions.*  
*See `dashboard/README.md` to start the local dashboard.*
