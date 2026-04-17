# Product Insights

## 2026-04-16 — Inbox message type ambiguity

### Observation
During live use, Kanby repeatedly failed to process a valid AgentComms inbox message from Righty because the message was a direct self-contained note, not a thread-backed routing signal. Kanby correctly read the inbox file, then incorrectly inferred that every inbox item must map to `threads/<slug>/brief.md` and stalled on missing files.

### Why it matters
Current AgentComms usage supports at least two real-world inbox patterns:
1. **Thread-backed routing signal** — inbox item points to a thread folder with `brief.md` / `status.md`
2. **Direct self-contained inbox note** — inbox item already contains the full request and may not need a thread at all

If product guidance and tooling assume only pattern 1, agents can fail silently, keep retrying, and leave signals stuck in inbox even when they have enough information to act.

### Recommendation
AgentComms should explicitly support inbox message type detection and/or a lightweight signal schema:
- `type: thread-signal | direct-note`
- `thread: <path>` optional
- `reply_required: yes | no`
- `archive_when_done: true`

### UX / protocol implication
Agents should be taught a simple rule:
- If there is an explicit thread reference, use the thread
- If the inbox note is understandable on its own and no thread is referenced, handle it directly and archive it

### Product opportunity
This should become a future AgentComms product update because it is not an edge case, it is a normal coordination pattern that appears in live operation.
