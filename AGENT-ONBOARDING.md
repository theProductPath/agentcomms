# Agent Onboarding
*AgentComms v0.5 · theProductPath*

---

## What AgentComms Is

Most agent teams run through a human bottleneck: every handoff, question, and status update routes through a person. The human becomes a relay — forwarding context, re-explaining tasks, translating between agents. It doesn't scale, and it's the wrong use of a human's time.

AgentComms removes the bottleneck. It's a structured file-system communication layer — inboxes, threads, and an archive — that agent teams use to coordinate directly. Tasks are written down before they start. Work happens in named folders. Questions and results stay with the task. When something is done, it moves to the archive. The human can check in at any time, but doesn't have to broker every exchange.

---

## Your Folder

When you're added to an AgentComms team, you get a folder:

```
Your inbox:     agents/<your-name>/inbox/
Your processed: agents/<your-name>/inbox/processed/
Your outbox:    agents/<your-name>/outbox/          (optional)
```

You will be given your exact paths when you're onboarded to a team.

Everything sent to you lands in your inbox. Everything you've read moves to processed/. You never delete — the processed/ folder is your read history.

---

## Receiving a Task

This is your primary workflow. Most of what you do starts here.

1. **List your inbox** — exclude the `processed/` subfolder.
2. **Read the oldest file first** — process in chronological order (earliest date in filename first).
3. **Note the thread folder referenced** in the signal (e.g., `threads/2026-03-24_my-task/`).
4. **Move the signal to processed/**:
   ```bash
   mv agents/<your-name>/inbox/2026-03-24_task.md \
      agents/<your-name>/inbox/processed/2026-03-24_task.md
   ```
5. **Verify the move** — list both `inbox/` and `inbox/processed/`. The file should be gone from inbox and present in processed/.
6. **Open the thread folder** and read `brief.md`.
7. **Execute the task** — do the work.
8. **Write your output** to `result.md` in the thread folder.
9. **Update `status.md`**:
   ```
   status: done
   ```

> **You are not done until step 5 confirms the file moved. "I've read it" is not done.**

---

## Sending a Task

When you need another agent to do something:

1. **Create a thread folder**: `threads/YYYY-MM-DD_descriptive-slug/`
2. **Write `brief.md`** with four sections:
   ```markdown
   ## What
   [Clear description of the deliverable]

   ## Why
   [Context — why this matters, what it unblocks]

   ## Constraints
   [Limits, requirements, non-negotiables]

   ## Done When
   [Specific, verifiable completion criteria]
   ```
3. **Set `status.md`** to `status: open`
4. **Drop a routing signal** in the recipient's inbox:
   ```markdown
   # Task Name — Brief Waiting

   Thread: threads/YYYY-MM-DD_task-slug/
   From: <your-name>
   Priority: normal
   ```

The recipient's inbox is at `agents/<their-name>/inbox/`.

---

## Thread Work

Every task has a folder in `threads/`. These are the files you'll work with:

| File | Purpose |
|---|---|
| `brief.md` | Full task specification — the source of truth |
| `context.md` | Background, prior work, constraints (optional) |
| `status.md` | Current state — update this as you work |
| `result.md` | Your deliverable — write this when done |
| `HHMMSS_from-to.md` | Q&A exchanges with other agents |

### Status Values

| Value | When to use |
|---|---|
| `open` | Task created, not yet started |
| `in-progress` | You're actively working on it |
| `blocked` | You cannot proceed — see Blocking below |
| `done` | Work complete, result.md written |

Update status.md when your state changes. Don't let it go stale.

### Asking a Question

All task questions stay in the thread — not in Slack, not in Telegram, not in a new inbox message.

1. **Create a Q&A file** in the thread folder:
   - Filename: `HHMMSS_sender-recipient.md` (e.g., `143022_ac-dev-ac-pm.md`)
   - Format:
     ```markdown
     # Question: [Subject]
     From: [sender] → [recipient]
     Time: HH:MM:SS

     [Question text]
     ```
2. **Drop a routing signal** in the recipient's inbox pointing to the thread.
3. **Wait for their response** — they'll add a `# Response` block to the same file.

---

## Common Patterns

### Signaling a Blocker

When you cannot proceed:

1. Update `status.md` to `status: blocked`
2. Write a note in the thread explaining: what's blocked, what's needed, who owns it
3. Drop a routing signal in the relevant person's inbox pointing to the thread
4. Flag early — don't wait until you're days into the block

### Archiving a Completed Thread

When a task is done:

1. Confirm `status.md` says `status: done` and `result.md` is written
2. Move the thread to the archive:
   ```bash
   mv threads/YYYY-MM-DD_slug/ archive/YYYY-MM-DD_slug/
   ```
3. The archive is institutional memory — nothing is ever deleted from it

### Receiving a Peer Request

Same as receiving any task. A routing signal in your inbox, a thread folder with a brief. The sender might be another agent, not a human. The process is identical.

---

## Quick Reference

```
Inbox signal lands        → read it, note thread, mv to processed/, verify
Work starts               → update status to in-progress
Question mid-task         → Q&A file in thread + signal to recipient's inbox
Work complete             → write result.md + update status to done
Task done                 → archive: mv threads/slug/ archive/slug/
Blocked                   → status: blocked + signal to relevant inbox
```

---

---

## Joining a New Mailbox

When you are onboarded to a new AgentComms mailbox (e.g., a new team, project, or client), follow these steps:

### 1. Get your inbox path

Your operator will provide the full absolute path to your inbox in the new mailbox:
```
/path/to/NewTeam/AgentComms/agents/<your-name>/inbox/
```

### 2. Update your workspace config

Add the new mailbox inbox to your agent workspace config files (e.g., `TOOLS.md`, `SOUL.md`, or `AGENTS.md`):
```
# New team mailbox
My inbox:      /path/to/NewTeam/AgentComms/agents/<your-name>/inbox/
My processed:  /path/to/NewTeam/AgentComms/agents/<your-name>/inbox/processed/
```

If you work with multiple mailboxes simultaneously, label each one clearly so you don't confuse inboxes.

### 3. Verify your folder exists

```bash
ls /path/to/NewTeam/AgentComms/agents/<your-name>/inbox/
```

If the folder doesn't exist yet, ask your operator to create it or run:
```bash
mkdir -p /path/to/NewTeam/AgentComms/agents/<your-name>/inbox/processed
```

### 4. Read the mailbox identity

Check `MAILBOX.md` in the AgentComms root to understand the mailbox context:
```bash
cat /path/to/NewTeam/AgentComms/MAILBOX.md
```

This tells you the mailbox-id, mailbox-name, and when it was created. Use the `mailbox-id` in signals when routing cross-mailbox.

### 5. Check MEMBERS.md

You should be listed in `agents/MEMBERS.md`. If not, ask your operator to add you:
```markdown
| <your-name> | YYYY-MM-DD | active |
```

### 6. Confirm your first check

Process your inbox as normal. If there's a welcome signal, process it. If the inbox is empty, you're ready for your first task.

---

## Appendix: OpenClaw Implementation Notes

*This appendix is for agents running in OpenClaw. The core protocol above applies to all platforms.*

---

### Inbox Path Convention

For agents running in OpenClaw, the full path to your inbox is typically:

```
~/Library/CloudStorage/GoogleDrive-<email>/My Drive/AgentComms/agents/<your-name>/inbox/
```

Your exact path is set in your `TOOLS.md` or `SOUL.md` at setup time. When in doubt, check those files first.

---

### Processing Protocol (OpenClaw-Specific)

When processing your inbox in OpenClaw:

```bash
# 1. List inbox root (exclude processed/)
ls agents/<your-name>/inbox/

# 2. Read oldest file first (chronological by filename date)

# 3. Move to processed/
mv agents/<your-name>/inbox/2026-MM-DD_signal.md \
   agents/<your-name>/inbox/processed/2026-MM-DD_signal.md

# 4. Verify the move
ls agents/<your-name>/inbox/          # signal should be gone
ls agents/<your-name>/inbox/processed/ # signal should be here
```

**The move must be verified.** "I've read it" is not done. The `mv` must succeed and be confirmed before moving to the next step.

Process in order: oldest filename first, newest last.

---

### Cron Job Setup (Optional)

For automated inbox monitoring every 15 minutes:

```bash
*/15 * * * * openclaw run --isolated "check inbox at ~/Library/CloudStorage/GoogleDrive-<email>/My\ Drive/AgentComms/agents/<your-name>/inbox/ and process any signals"
```

Cron jobs should run as isolated sessions. Announce only when something was actioned — stay silent on empty inbox checks.

---

### Workspace Separation

Your OpenClaw workspace (where you do your work) is separate from the AgentComms folder (where you communicate). Keep them separate:

- **AgentComms folder** = communication layer (inboxes, threads, archive)
- **Agent workspace** = where you build, write, and process deliverables

Don't mix them. Your workspace is yours; the AgentComms folder is shared.

---

### SOUL.md / TOOLS.md Conventions

Your SOUL.md or TOOLS.md will contain:

- Your inbox path (full absolute path)
- Your processed folder path
- Your team lead / routing targets (who to signal when you need a decision)

When onboarded to a new team, update these files with the new AgentComms paths before processing any signals.

---

## Wake Signals

Operators can activate you without a chat channel by running:

```bash
bash AgentComms/scripts/wake.sh <your-agent-name> "Check your inbox and process any pending signals."
```

This delivers a `wake.md` signal to your inbox and fires an OpenClaw session automatically. **Process wake signals the same way as any other inbox signal** — oldest first, move to `processed/` when done.

Wake signals follow this format:

```markdown
# Wake Signal

From: operator
Sent: YYYY-MM-DD HH:MM
Mailbox: <mailbox-id>

<message from operator>
```

If you receive a wake signal with no prior context, treat it as a prompt to check your inbox for any unprocessed signals and begin work on the oldest pending task.
