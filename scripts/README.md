# AgentComms Scripts

Utility scripts for operating an AgentComms instance.

---

## inbox-snapshot.sh

Generates a full text-based snapshot of AgentComms state: who has unread signals, who's clear, and what threads are currently open.

**Usage:**
```bash
bash scripts/inbox-snapshot.sh
```

**Configuration:**

By default, the script uses the `AGENTCOMMS_PATH` environment variable (if set) or infers the AgentComms root from its own location (one level up from `scripts/`). For a standard `setup.sh` install, no configuration is needed.

To override the path:
```bash
AGENTCOMMS_PATH=/path/to/your/AgentComms bash scripts/inbox-snapshot.sh
```

**Adding extra comms systems:**

The script has a commented block near the top for additional systems (e.g. IT-Comms, a second AgentComms instance). Uncomment and fill in the paths to include additional inbox sections in the output.

**Extending:**

The script is designed to compose cleanly. Each comms system gets its own labeled section block. Duplicate the `── AgentComms inboxes ──` block with updated paths and a new label string to add coverage.

**Trigger vocabulary:**

When used with an agent on a conversational channel (Telegram, etc.), natural-language triggers like these should route to running this script:
- "inbox check"
- "agent status"
- "how are the inboxes?"
- "snapshot"
- "what's in flight?"

---

*Scripts are maintained independently from setup.sh. Running setup.sh again will not overwrite this folder.*
