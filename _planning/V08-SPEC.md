# AgentComms v0.8 — Product Spec
*Author: Stratty 🎯 (PM) | Date: 2026-03-29 | Status: DRAFT*

---

## Goals for v0.8

1. Add `reset.sh` — lets a human wipe an AgentComms instance back to clean or example state
2. Improve first-run scaffold with a 3-agent Research & Write example (replaces single example-agent)
3. Update documentation to cover setup → use → reset lifecycle clearly

---

## Item 1 — reset.sh

**Problem:** Once a user has run setup.sh and explored the example, there is no way to wipe the instance back to a clean state without manually deleting files. This blocks the setup → explore → reset loop that new users need.

**Solution:** `scripts/reset.sh` — a script that wipes all agent, thread, and archive content and optionally restores the example state.

### Usage

```bash
# Wipe to clean empty instance (prompts for confirmation)
bash AgentComms/scripts/reset.sh

# Skip confirmation prompt (for automated contexts)
bash AgentComms/scripts/reset.sh --force

# Wipe and restore example content
bash AgentComms/scripts/reset.sh --example

# Wipe and restore example, skip confirmation
bash AgentComms/scripts/reset.sh --example --force
```

### What it does

1. **Check for open threads** — scan `threads/` for any with status not `done`, `closed`, or `archived`. If found, list them and ask: "These threads are still open. Reset anyway? [y/N]" (skipped with `--force`)
2. **Confirmation prompt** — "This will delete all agents, threads, and archive contents. Are you sure? [y/N]" (skipped with `--force`)
3. **Wipe content:**
   - Delete all contents of `agents/` (all inbox folders and signals)
   - Delete all contents of `threads/`
   - Delete all contents of `archive/`
   - Reset `agents/MEMBERS.md` to empty placeholder
4. **If `--example` flag passed:** re-copy scaffold content from the installer repo into the instance (same content setup.sh installs on first run)
5. **Success output:**
   ```
   ✅ AgentComms reset complete.
   → Instance: /path/to/AgentComms
   → State: clean (or: example content restored)
   ```

### What it does NOT touch

- `dashboard/` — dashboard files untouched
- `scripts/` — scripts untouched (including reset.sh itself)
- `MAILBOX.md` — mailbox identity preserved
- `COMMUNICATION_PROTOCOL.md` — protocol doc untouched
- `AGENT-ONBOARDING.md` — untouched

### Path resolution

Same pattern as other scripts — infer AgentComms root from script location. Support `--root <path>` override. No hardcoded paths.

### Finding the scaffold source

`reset.sh --example` needs the scaffold content. Resolution order:
1. Check for `AGENTCOMMS_INSTALLER` env var pointing to the cloned repo
2. Check for a `installer-path.txt` file at the AgentComms root (written by setup.sh)
3. If neither found: print error with instructions to set `AGENTCOMMS_INSTALLER=/path/to/cloned/repo`

**setup.sh should be updated** to write `installer-path.txt` at the AgentComms root on first run so `--example` works without any env var setup.

---

## Item 2 — Scaffold: Replace single example-agent with 3-agent Research & Write example

**Problem:** The current scaffold shows a single `example-agent` with a couple of inbox signals. This is a static, underwhelming demo for a system built around multi-agent coordination.

**Solution:** Replace with a pre-populated, completed Research & Write run — three agents (orchestrator, researcher, writer), a mission, and the full artifact trail showing what a completed run looks like.

### New scaffold structure

```
scaffold/
├── agents/
│   ├── example-orchestrator/
│   │   └── inbox/
│   │       ├── processed/
│   │       │   ├── 2026-01-01_mission-brief.md
│   │       │   ├── 2026-01-01_research-complete.md
│   │       │   └── 2026-01-01_memo-complete.md
│   ├── example-researcher/
│   │   └── inbox/
│   │       └── processed/
│   │           └── 2026-01-01_research-task.md
│   └── example-writer/
│       └── inbox/
│           └── processed/
│               └── 2026-01-01_writing-task.md
│
├── threads/                    ← empty (run is complete, all in archive)
│
└── archive/
    └── 2026-01-01_example-research-mission/
        ├── brief.md
        ├── status.md           ← status: done
        ├── researcher-summary.md
        ├── writer-memo.md
        └── result.md
```

### Sample mission

The example mission should be immediately legible and credible to any new user:

> **Mission:** What are the three most important things to consider when starting a new software project?

This is universally relevant, non-technical enough for any user to evaluate, and short enough that the example artifacts feel realistic rather than padded.

### Example artifacts to write

- `brief.md` — mission brief from operator to orchestrator
- `researcher-summary.md` — researcher's structured findings (3 considerations with supporting rationale)
- `writer-memo.md` — writer's polished one-page memo
- `result.md` — pointer to the deliverable, status confirmation
- Inbox signals in each agent's `processed/` folder showing the routing chain

**Goal:** New user opens dashboard, sees three agents all with clear inboxes, one archived thread with a complete artifact trail. They understand immediately: this is what a completed run looks like, and here's every handoff that happened.

### MEMBERS.md

Update scaffold to include all three example agents:

```markdown
# Members — [mailbox-name]

| Agent | Joined | Status |
|-------|--------|--------|
| example-orchestrator | 2026-01-01 | active |
| example-researcher | 2026-01-01 | active |
| example-writer | 2026-01-01 | active |
```

---

## Item 3 — README: Setup → Use → Reset lifecycle

**Problem:** The README covers setup well but doesn't explain the full lifecycle: how to explore the example, how to wipe it, and how to start fresh with your own team.

**Add a "Lifecycle" or "Getting Started" section** after Quick Start:

```markdown
## The Setup → Use → Reset Loop

When you first run setup.sh, your AgentComms instance comes with an example Research & Write team and a completed mission so you can see what a full run looks like.

When you're ready to start fresh:

```bash
# Wipe everything and start clean
bash AgentComms/scripts/reset.sh

# Or restore the example content at any time
bash AgentComms/scripts/reset.sh --example
```

To add your own agents, see [Adding an Agent](#adding-an-agent).
```

---

## Definition of Done

- [ ] `scripts/reset.sh` wipes agents/, threads/, archive/, MEMBERS.md with confirmation prompt
- [ ] `--force` skips confirmation
- [ ] `--example` re-copies scaffold content; resolves installer path from `installer-path.txt` or `AGENTCOMMS_INSTALLER` env var
- [ ] `setup.sh` writes `installer-path.txt` at AgentComms root on first run
- [ ] `reset.sh` handles missing open threads gracefully (warns, prompts)
- [ ] Reset preserves dashboard/, scripts/, MAILBOX.md, COMMUNICATION_PROTOCOL.md
- [ ] Scaffold replaced with 3-agent Research & Write example (orchestrator, researcher, writer)
- [ ] All example artifacts written: brief, researcher summary, writer memo, result, inbox signals
- [ ] MEMBERS.md scaffold includes all three example agents
- [ ] README includes setup → use → reset lifecycle section
- [ ] All changes committed and pushed to `theProductPath/agentcomms`

---

## Out of Scope for v0.8

- OpenClaw 3-agent live demo (activate the example and watch it run) — v0.9
- OpenClaw agent deregistration in reset.sh — v0.9 (depends on live demo)
- Scheduled checkmail digest — deferred
- Hosted deployment / auth — v1.0+

---

*Spec written by Stratty 🎯 | Ready for Codey 👨‍💻*
