# AgentComms — OpenClaw Implementation

This folder contains everything you need to run the AgentComms Research & Write demo with a real 3-agent OpenClaw team.

---

## The Demo Team

| Agent | Role | What They Do |
|-------|------|--------------|
| **Vera** | Orchestrator | Receives the mission brief, routes tasks to Jin and Ash, reviews output, writes result.md, and archives the thread |
| **Jin** | Researcher | Reads the brief, produces a structured 3-point research summary (`jin-research-summary.md`), signals Vera when done |
| **Ash** | Writer | Reads the brief and Jin's research, writes a polished one-page memo (`ash-memo.md`), signals Vera when done |

The full mission: *Answer the question "What are the three most important things to consider when starting a new software project?" — research, write, and deliver a polished one-page memo.*

---

## Prerequisites

Before running the demo, you need:

1. **OpenClaw installed** and available in your PATH
2. **At least one OpenClaw agent registered** with a model — the setup script will detect your default agent's model automatically. If no default exists, pass `--model <id>` explicitly.
3. **An AgentComms mailbox** set up (run `bash setup.sh --path ~/AgentComms` from the repo root)

Check your OpenClaw setup:
```bash
openclaw agents list
```

You should see at least one agent with a `Model:` value. If not, add one first:
```bash
openclaw agents add myagent --workspace ~/.openclaw/workspace-myagent --model anthropic/claude-haiku-4-5
```

---

## One-Command Setup + Demo Load

```bash
bash implementations/openclaw/run-demo.sh --agentcomms-root ~/AgentComms
```

Optional flags:
```bash
# Override model detection
bash implementations/openclaw/run-demo.sh \
  --agentcomms-root ~/AgentComms \
  --model anthropic/claude-haiku-4-5
```

What `run-demo.sh` does:
1. Verifies prerequisites (openclaw, AgentComms root)
2. Detects your default model (or uses `--model`)
3. Runs `setup-agents.sh` to create Vera, Jin, and Ash in both AgentComms and OpenClaw
4. Creates the mission thread with `brief.md` and `status.md`
5. Drops the mission signal into Vera's inbox
6. Runs a pre-flight check
7. Prints the wake command to start the mission

---

## Activate: Wake Vera

After `run-demo.sh` completes, start the mission:

```bash
bash ~/AgentComms/scripts/wake.sh vera "Check your inbox — your mission brief is waiting."
```

This delivers a wake signal to Vera's inbox and fires an OpenClaw session. Vera reads her inbox, picks up the mission brief, and routes research to Jin. From there the chain runs autonomously (bridged by cron polling between handoffs).

---

## Setup Only (No Mission Load)

If you want to set up the agents without loading the demo mission:

```bash
bash implementations/openclaw/setup-agents.sh \
  --agentcomms-root ~/AgentComms \
  [--model anthropic/claude-haiku-4-5]
```

This creates:
- `~/AgentComms/agents/vera/inbox/`
- `~/AgentComms/agents/jin/inbox/`
- `~/AgentComms/agents/ash/inbox/`
- OpenClaw workspaces at `~/.openclaw/workspace-vera/`, `workspace-jin/`, `workspace-ash/`
- SOUL.md in each workspace (with real inbox paths substituted)
- Each agent registered in OpenClaw via `openclaw agents add`

---

## What Happens During the Demo

```
Operator
  └── wake.sh vera "Check your inbox..."
        └── Vera activates
              └── Reads brief, creates research task
                    └── Drops signal → Jin's inbox
                          └── Jin activates (next cron cycle, ~15 min)
                                └── Researches topic
                                      └── Writes jin-research-summary.md in thread folder
                                            └── Drops signal → Vera's inbox
                                                  └── Vera activates (next cron cycle)
                                                        └── Reviews research, routes to Ash
                                                              └── Drops signal → Ash's inbox
                                                                    └── Ash activates
                                                                          └── Writes ash-memo.md
                                                                                └── Drops signal → Vera's inbox
                                                                                      └── Vera activates
                                                                                            └── Writes result.md
                                                                                                  └── Archives thread ← DONE
```

> **Key finding from the experiment:** Inter-agent handoffs (Jin → Vera, Ash → Vera) do not self-activate. Cron polling bridges the gap (~15 min latency per hop). This is expected behavior in v0.9.

---

## Monitoring Progress

```bash
# Watch the dashboard
bash ~/AgentComms/dashboard/start.sh

# Check inboxes manually
bash ~/AgentComms/scripts/inbox-snapshot.sh

# Check thread status
cat ~/AgentComms/threads/*/status.md
```

---

## Cleanup / Reset

```bash
# Reset the mailbox to a clean state
bash ~/AgentComms/scripts/reset.sh

# Full mailbox teardown (archives open threads, generates cleanup checklist)
bash ~/AgentComms/scripts/teardown.sh
```

---

## Files in This Folder

| File | Purpose |
|------|---------|
| `run-demo.sh` | One-command demo setup + mission load |
| `setup-agents.sh` | Creates vera/jin/ash in AgentComms + OpenClaw |
| `agent-souls/vera-SOUL.md` | Vera's identity and operating protocol |
| `agent-souls/jin-SOUL.md` | Jin's identity and operating protocol |
| `agent-souls/ash-SOUL.md` | Ash's identity and operating protocol |
| `scaffold/` | Pre-populated example showing a completed 3-agent run |

---

## Scaffold Example

The `scaffold/` folder shows what a completed 3-agent run looks like — full artifact trail including brief, research summary, writer memo, and result. Copy it into your AgentComms instance to explore the pattern without running the demo:

```bash
cp -r implementations/openclaw/scaffold/ ~/AgentComms/
```

---

*AgentComms v0.9 · theProductPath · OpenClaw implementation*
