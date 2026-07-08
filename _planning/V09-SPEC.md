# AgentComms v0.9 — Product Spec
*Author: Stratty 🎯 (PM) | Date: 2026-03-29 | Status: DRAFT — pending v0.8 completion*

---

## Goals for v0.9

1. Ship the AgentComms landing page — `index.html` live at `agentcomms.theproductpath.com` via GitHub Pages
2. OpenClaw demo environment — setup and teardown scripts for the live 3-agent demo (demo environment work already in progress — this spec covers integration and cleanup only)

---

## Item 1 — Landing Page: GitHub Pages + index.html

**Dependency:** Desy delivers `index.html` to `AI-Collab/tPP/Products/AgentComms/index.html`

### 1a. CNAME file

Add a `CNAME` file to the repo root containing exactly:
```
agentcomms.theproductpath.com
```

### 1b. Commit index.html and CNAME

```bash
cp "AI-Collab/tPP/Products/AgentComms/index.html" /path/to/agentcomms-repo/index.html
git add index.html CNAME
git commit -m "Add landing page and GitHub Pages config"
git push
```

### 1c. Verify GitHub Pages

Confirm page is live at `theproductpath.github.io/agentcomms` after push. Check:
- Page loads without errors
- All sections render correctly
- CTA button links to correct GitHub repo URL
- Mobile responsive

### 1d. DNS note for Jones

Once GitHub Pages is confirmed working, Jones adds a CNAME DNS record in Squarespace:
- Name: `agentcomms`
- Value: `theproductpath.github.io`

This is a Jones action — not Codey's. Flag it clearly in your completion message.

---

## Item 2 — OpenClaw Demo: Setup + Teardown Integration

**Note:** Demo environment setup is already in progress. This item covers the cleanup scripts and reset integration only — do not re-spec the setup work already planned.

### 2a. demo-setup.sh

`implementations/openclaw/demo-setup.sh` — sets up the live 3-agent Research & Write demo:
1. Creates inbox folders for demo agents in AgentComms
2. Registers demo agents in OpenClaw (`openclaw agents add` for each)
3. Drops the sample mission brief into the orchestrator's inbox
4. Prints confirmation: agent names, inbox paths, next step ("Run: bash scripts/wake.sh <orchestrator>")

### 2b. demo-teardown.sh

`implementations/openclaw/demo-teardown.sh` — cleans up after the live demo:
1. Deregisters demo agents from OpenClaw (`openclaw agents delete` for each)
2. Removes cron jobs if configured
3. Calls `reset.sh --example` to restore the static scaffold
4. Prints confirmation that everything is clean

### 2c. reset.sh update (minor)

Update `scripts/reset.sh` to print a note when OpenClaw demo agents may be registered:
```
⚠ If you ran the OpenClaw live demo, also run:
  bash implementations/openclaw/demo-teardown.sh
```
This appears only when `implementations/openclaw/demo-teardown.sh` exists in the repo.

---

## Definition of Done

- [ ] `CNAME` file in repo root with `agentcomms.theproductpath.com`
- [ ] `index.html` committed to repo root from Desy's deliverable
- [ ] Page confirmed live at `theproductpath.github.io/agentcomms`
- [ ] Jones notified to add DNS CNAME record in Squarespace
- [ ] `implementations/openclaw/demo-setup.sh` creates inbox folders + registers agents
- [ ] `implementations/openclaw/demo-teardown.sh` deregisters agents + calls reset
- [ ] `reset.sh` prints OpenClaw teardown note when applicable
- [ ] All changes committed and pushed to `theProductPath/agentcomms`

---

*Spec written by Stratty 🎯 | Ready for Codey 👨‍💻 after v0.8 complete*
