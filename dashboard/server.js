#!/usr/bin/env node
/**
 * AgentComms Dashboard — server.js  (v0.8)
 * Zero external dependencies. Node.js built-ins only.
 * Node.js >= 14 required.
 *
 * Usage:
 *   node server.js [port]
 *   Default port: 7843
 *
 * Config:
 *   AGENTCOMMS_PATH env var   — absolute path to your AgentComms folder
 *   AGENTCOMMS_PORT env var   — override default port
 *   config/dispatcher.json   — dispatcher job ID and openclaw binary path
 */

'use strict';

const http          = require('http');
const fs            = require('fs');
const path          = require('path');
const { execSync }  = require('child_process');

// ─── Config ───────────────────────────────────────────────────────────────────

const DEFAULT_PORT = 7843;

// ─── AGENT_EMOJIS ─────────────────────────────────────────────────────────────

const AGENT_EMOJIS = {
  'ac-dev':        '👨🏽\u200d💻',
  'ac-orch':       '🎯',
  'ac-pm':         '📊',
  'ac-design':     '👩🏽\u200d💻',
  'stratty':       '🎯',
  'archy':         '🏗️',
  'stacky':        '⚡',
  'kanby':         '📋',
  'marky':         '✍️',
  'example-agent': '🤖',
  'codey':         '👨\u200d💻',
  'righty':        '📋',
  'hairy':         '🤝',
  'shorty':        '🥃',
  'scouty':        '🔍',
  'smarty':        '🧠',
  'pixxy':         '🎨',
  'desy':          '👩🏽\u200d💻',
  'copy':          '✍️',
};

// ─── Instances ────────────────────────────────────────────────────────────────

const INSTANCES_FILE    = path.join(__dirname, 'instances.json');
const SUPPORTED_VERSION = 1;

// Path to AgentComms folder — used as default instance if instances.json missing
const AGENTCOMMS_DEFAULT = process.env.AGENTCOMMS_PATH
  || path.resolve(__dirname, '..');

function loadInstances() {
  try {
    const raw  = fs.readFileSync(INSTANCES_FILE, 'utf8');
    const list = JSON.parse(raw);
    if (Array.isArray(list) && list.length > 0) {
      // Normalize: accept both `name` and `label` fields
      return list.map(i => ({ ...i, name: i.name || i.label || 'AgentComms' }));
    }
  } catch (_) {}
  // Fallback: single default entry
  return [{ key: 'default', name: 'AgentComms', path: AGENTCOMMS_DEFAULT, builtin: true }];
}

function saveInstances(list) {
  fs.writeFileSync(INSTANCES_FILE, JSON.stringify(list, null, 2));
}

function instanceByKey(key) {
  const list = loadInstances();
  return list.find(i => i.key === key) || list[0];
}

function defaultInstance() {
  return loadInstances()[0];
}

// ─── Dispatcher Config ────────────────────────────────────────────────────────

let dispatcherConfig = { jobId: '', openclawBin: 'openclaw', enabled: true };

function loadDispatcherConfig() {
  const inst       = defaultInstance();
  const configPath = path.join(inst.path, 'config', 'dispatcher.json');
  try {
    const raw = fs.readFileSync(configPath, 'utf8');
    const parsed = JSON.parse(raw);
    // Accept cronJobId as alias for jobId (for compatibility)
    if (parsed.cronJobId && !parsed.jobId) parsed.jobId = parsed.cronJobId;
    dispatcherConfig = { ...dispatcherConfig, ...parsed };
    console.log(`Dispatcher config loaded from: ${configPath}`);
    if (!dispatcherConfig.jobId) {
      console.log('  Dispatcher: jobId empty — dispatcher endpoints will return unconfigured error');
    } else {
      console.log(`  Dispatcher: jobId=${dispatcherConfig.jobId}`);
    }
  } catch (_) {
    console.log(`Dispatcher config not found at ${configPath} — dispatcher features disabled`);
  }
}

// ─── Validation ───────────────────────────────────────────────────────────────

function validateInstancePath(instancePath) {
  const expanded = instancePath.replace(/^~/, process.env.HOME || '');
  if (!fs.existsSync(expanded)) return { ok: false, error: 'Folder not found' };
  for (const sub of ['agents', 'threads', 'archive']) {
    if (!fs.existsSync(path.join(expanded, sub))) {
      return { ok: false, error: `Missing required folder: ${sub}/` };
    }
  }
  // Check agentcomms-version file (preferred) OR README.md tag
  const versionFile = path.join(expanded, 'agentcomms-version');
  const readmeFile  = path.join(expanded, 'README.md');
  let version = null;
  let versionWarning = null;

  if (fs.existsSync(versionFile)) {
    const vContent = safeReadFile(versionFile);
    version = parseInt((vContent || '').trim(), 10) || 1;
  } else if (fs.existsSync(readmeFile)) {
    const readme = safeReadFile(readmeFile) || '';
    const m = readme.match(/agentcomms-version:\s*(\d+)/);
    if (m) {
      version = parseInt(m[1], 10);
      versionWarning = 'agentcomms-version file missing (found tag in README.md)';
    } else {
      versionWarning = 'agentcomms-version file missing — folder may not be a valid AgentComms instance';
    }
  } else {
    versionWarning = 'agentcomms-version file missing';
  }

  if (version !== null && version !== SUPPORTED_VERSION) {
    return { ok: false, error: `Unsupported version: ${version} (dashboard supports v${SUPPORTED_VERSION})` };
  }

  // Count agents
  const agentsDir = path.join(expanded, 'agents');
  let agentCount = 0;
  try {
    agentCount = fs.readdirSync(agentsDir).filter(f => {
      try { return fs.statSync(path.join(agentsDir, f)).isDirectory(); } catch { return false; }
    }).length;
  } catch (_) {}

  return {
    ok:          true,
    version:     version || null,
    agentCount,
    warning:     versionWarning || undefined,
    resolvedPath: expanded,
  };
}

// ─── Mailbox ──────────────────────────────────────────────────────────────────

function parseMailbox(instancePath) {
  const mailboxFile = path.join(instancePath, 'MAILBOX.md');
  const content = safeReadFile(mailboxFile);
  if (!content) return null;
  const idMatch      = content.match(/^mailbox-id:\s*(.+)/m);
  const nameMatch    = content.match(/^mailbox-name:\s*(.+)/m);
  const createdMatch = content.match(/^created:\s*(.+)/m);
  if (!idMatch) return null;
  return {
    mailboxId:   idMatch[1].trim(),
    mailboxName: nameMatch   ? nameMatch[1].trim()   : null,
    created:     createdMatch ? createdMatch[1].trim() : null,
  };
}

// ─── Members ──────────────────────────────────────────────────────────────────

function parseMembers(instancePath) {
  const membersFile = path.join(instancePath, 'agents', 'MEMBERS.md');
  const content = safeReadFile(membersFile);
  if (!content) return null;
  const members = [];
  const lines = content.split('\n');
  for (const line of lines) {
    const m = line.match(/^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|/);
    if (!m) continue;
    const agent = m[1].trim();
    if (agent === 'Agent' || agent === '---' || /^-+$/.test(agent)) continue;
    members.push({ agent: agent, joined: m[2].trim(), status: m[3].trim() });
  }
  return members;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function safeReadDir(dirPath) {
  try { return fs.readdirSync(dirPath); }
  catch (_) { return []; }
}

function safeStat(filePath) {
  try { return fs.statSync(filePath); }
  catch (_) { return null; }
}

function safeReadFile(filePath) {
  try { return fs.readFileSync(filePath, 'utf8'); }
  catch (_) { return null; }
}

function relativeTime(mtimeMs) {
  const diffSec = Math.floor((Date.now() - mtimeMs) / 1000);
  if (diffSec < 60)     return `${diffSec}s ago`;
  if (diffSec < 3600)   return `${Math.floor(diffSec / 60)}m ago`;
  if (diffSec < 86400)  return `${Math.floor(diffSec / 3600)}h ago`;
  if (diffSec < 604800) return `${Math.floor(diffSec / 86400)}d ago`;
  return `${Math.floor(diffSec / 604800)}w ago`;
}

function latestMtime(dirPath) {
  let latest = 0;
  function walk(p) {
    const stat = safeStat(p);
    if (!stat) return;
    if (stat.mtimeMs > latest) latest = stat.mtimeMs;
    if (stat.isDirectory()) {
      for (const entry of safeReadDir(p)) walk(path.join(p, entry));
    }
  }
  walk(dirPath);
  return latest;
}

function extractEmoji(str) {
  const key = str.toLowerCase().trim();
  if (AGENT_EMOJIS[key]) return AGENT_EMOJIS[key];
  const match = str.match(/^([\p{Emoji_Presentation}\p{Emoji}\u200D\uFE0F]+)/u);
  return match ? match[1] : '🤖';
}

// ─── Data Scanner ─────────────────────────────────────────────────────────────

function scanAgentComms(instancePath) {
  const root       = instancePath || defaultInstance().path;
  const agentsDir  = path.join(root, 'agents');
  const threadsDir = path.join(root, 'threads');
  const archiveDir = path.join(root, 'archive');

  const now      = Date.now();
  const sevenDays = 7 * 24 * 60 * 60 * 1000;

  // ── Parse mailbox identity ──
  const mailboxInfo = parseMailbox(root) || {};

  // ── Mailbox closed check ──
  const closedFile    = path.join(root, 'MAILBOX-CLOSED.md');
  const mailboxClosed = !!safeStat(closedFile);
  let closedInfo = null;
  if (mailboxClosed) {
    const content   = safeReadFile(closedFile);
    const closedDate = (content && content.match(/^closed:\s*(.+)/im))
      ? content.match(/^closed:\s*(.+)/im)[1].trim()
      : '';
    closedInfo = { closed: true, closedDate };
  }

  // ── Parse members (for ghost/unregistered detection) ──
  const membersData = parseMembers(root);
  const memberNames = membersData
    ? new Set(membersData.map(m => m.agent.toLowerCase()))
    : null;

  // ── Agents ──
  const agents = [];
  const seenAgentFolders = new Set();

  for (const agentName of safeReadDir(agentsDir).sort()) {
    const agentPath = path.join(agentsDir, agentName);
    const stat = safeStat(agentPath);
    if (!stat || !stat.isDirectory()) continue;
    if (agentName === 'MEMBERS.md' || agentName.startsWith('.')) continue;

    seenAgentFolders.add(agentName.toLowerCase());

    const inboxPath     = path.join(agentPath, 'inbox');
    const outboxPath    = path.join(agentPath, 'outbox');
    const processedPath = path.join(inboxPath, 'processed');

    const allInbox = safeReadDir(inboxPath).filter(f =>
      f !== 'processed' && f !== '.keep' && !f.startsWith('.')
    );
    const inboxFiles = allInbox.map(f => {
      const fp = path.join(inboxPath, f);
      const s  = safeStat(fp);
      return { name: f, path: fp, mtime: s ? s.mtimeMs : 0 };
    }).sort((a, b) => a.name.localeCompare(b.name));

    const processedFiles = safeReadDir(processedPath).filter(f =>
      f !== '.keep' && !f.startsWith('.')
    ).sort().reverse().slice(0, 8);

    const outboxFiles = safeReadDir(outboxPath).filter(f =>
      f !== '.keep' && !f.startsWith('.')
    );

    const lastMtime = latestMtime(agentPath);
    const isActive  = lastMtime > (now - sevenDays) || inboxFiles.length > 0;

    const agentObj = {
      name:           agentName,
      emoji:          AGENT_EMOJIS[agentName] || extractEmoji(agentName),
      inboxCount:     inboxFiles.length,
      inboxFiles,
      processedFiles,
      processedCount: safeReadDir(processedPath).filter(f => f !== '.keep' && !f.startsWith('.')).length,
      outboxCount:    outboxFiles.length,
      outboxFiles:    outboxFiles,
      lastMtime,
      lastActive:     lastMtime > 0 ? relativeTime(lastMtime) : 'never',
      isActive,
    };

    // Membership flags
    if (memberNames && !memberNames.has(agentName.toLowerCase())) {
      agentObj.unregistered = true;
    }

    agents.push(agentObj);
  }

  // ── Ghost agents (in MEMBERS.md but no folder) ──
  if (membersData) {
    for (const member of membersData) {
      if (!seenAgentFolders.has(member.agent.toLowerCase())) {
        agents.push({
          name:           member.agent,
          emoji:          AGENT_EMOJIS[member.agent.toLowerCase()] || '🤖',
          inboxCount:     0,
          inboxFiles:     [],
          processedFiles: [],
          processedCount: 0,
          outboxCount:    0,
          outboxFiles:    [],
          lastMtime:      0,
          lastActive:     'never',
          isActive:       false,
          ghost:          true,
        });
      }
    }
  }

  // ── Threads ──
  const threads = [];

  function scanThreadDir(dirPath, zone) {
    for (const slug of safeReadDir(dirPath).sort()) {
      const tp   = path.join(dirPath, slug);
      const stat = safeStat(tp);
      if (!stat || !stat.isDirectory()) continue;

      // Detect "collection" threads: date-stamped subfolders
      const topEntries = safeReadDir(tp);
      const hasDateSubfolders = topEntries.some(f =>
        /^\d{4}-\d{2}-\d{2}$/.test(f) && safeStat(path.join(tp, f)) && safeStat(path.join(tp, f)).isDirectory()
      );

      if (hasDateSubfolders) {
        // Treat each date subfolder as its own virtual thread
        for (const dateSub of topEntries.filter(f =>
          /^\d{4}-\d{2}-\d{2}$/.test(f) &&
          safeStat(path.join(tp, f)) &&
          safeStat(path.join(tp, f)).isDirectory()
        )) {
          const subPath    = path.join(tp, dateSub);
          const virtualSlug = `${slug}/${dateSub}`;
          const thread     = parseThread(subPath, virtualSlug, zone);
          // Override title for collection threads
          thread.title = `${slug.replace(/-/g, ' ')} — ${dateSub}`;
          threads.push(thread);
        }
      } else {
        threads.push(parseThread(tp, slug, zone));
      }
    }
  }

  scanThreadDir(threadsDir, 'threads');
  scanThreadDir(archiveDir, 'archive');

  // ── Stats ──
  const activeAgents = agents.filter(a => a.isActive && !a.ghost).length;
  const inFlight     = agents.filter(a => !a.ghost).reduce((sum, a) => sum + a.inboxCount, 0);
  const threadsOpen  = threads.filter(t =>
    t.zone === 'threads' && t.status !== 'done' && t.status !== 'archived'
  ).length;
  const archived = threads.filter(t =>
    t.zone === 'archive' || t.status === 'done'
  ).length;

  return {
    agents,
    threads,
    stats: { activeAgents, inFlight, threadsOpen, archived },
    mailbox: { ...mailboxInfo, ...(closedInfo || {}) },
  };
}

function parseThread(threadPath, folder, zone) {
  const files     = safeReadDir(threadPath).filter(f => !f.startsWith('.'));
  let status      = zone === 'archive' ? 'archived' : 'unknown';
  let summary     = '';
  let title       = null;

  // Read status.md if present
  const statusFile   = path.join(threadPath, 'status.md');
  const statusContent = safeReadFile(statusFile);
  if (statusContent) {
    const lower = statusContent.toLowerCase();
    if      (lower.includes('done') || lower.includes('complete') || lower.includes('closed')) status = 'done';
    else if (lower.includes('in-progress') || lower.includes('in progress')) status = 'in-progress';
    else if (lower.includes('blocked'))  status = 'blocked';
    else if (lower.includes('open'))     status = 'open';
    else if (zone !== 'archive')         status = 'open';
    // Summary: first 120 chars of status.md
    summary = statusContent.split('\n').slice(0, 3).join(' ').substring(0, 120);
    // Title: first h1 or first non-empty line from status.md
    const firstLine = statusContent.split('\n').find(l => l.trim());
    if (firstLine) title = firstLine.replace(/^#+\s*/, '').trim();
  }

  // Read brief.md — use for title fallback and summary fallback
  const briefFile    = path.join(threadPath, 'brief.md');
  const briefContent = safeReadFile(briefFile);
  if (briefContent) {
    if (!summary) {
      summary = briefContent.split('\n').find(l => l.trim()) || '';
      summary = summary.replace(/^#+\s*/, '').substring(0, 120);
    }
    if (!title || title.startsWith('status:') || title.startsWith('#')) {
      const briefLine = briefContent.split('\n').find(l => l.trim());
      if (briefLine) title = briefLine.replace(/^#+\s*/, '').trim();
    }
  }

  // Title fallback: slug with dashes replaced by spaces
  if (!title) {
    title = folder.replace(/^\d{4}-\d{2}-\d{2}_/, '').replace(/\//g, ' — ').replace(/-/g, ' ');
  }

  const lastMtime = latestMtime(threadPath);

  // Build file objects with path and mtime
  const fileObjects = files.filter(f =>
    f.endsWith('.md') || f.endsWith('.png') || f.endsWith('.jpg') ||
    f.endsWith('.jpeg') || f.endsWith('.gif') || f.endsWith('.webp') || f.endsWith('.svg')
  ).map(f => {
    const fp = path.join(threadPath, f);
    const s  = safeStat(fp);
    return { name: f, path: fp, mtime: s ? s.mtimeMs : 0 };
  });

  // Extract agents involved
  const involvedAgents = extractAgentsFromThread(folder, files);

  return {
    slug:         folder,
    zone,
    status,
    date:         folder.substring(0, 10),
    title,
    summary,
    files:        fileObjects,
    fileCount:    files.length,
    agents:       involvedAgents,  // `agents` for frontend compatibility
    involvedAgents,                // also expose as involvedAgents
    lastMtime,
    lastActive:   lastMtime > 0 ? relativeTime(lastMtime) : 'never',
  };
}

function extractAgentsFromThread(folder, files) {
  const knownAgents = Object.keys(AGENT_EMOJIS);
  const found = new Set();
  const text  = (folder + ' ' + (Array.isArray(files) ? files.join(' ') : '')).toLowerCase();
  for (const agent of knownAgents) {
    if (text.includes(agent)) found.add(agent);
  }
  return Array.from(found);
}

// ─── SSE Clients ──────────────────────────────────────────────────────────────

const sseClients = new Set();

// Broadcast to all clients (dispatcher events, instance changes)
function broadcastAll(data) {
  const msg = `data: ${JSON.stringify(data)}\n\n`;
  for (const client of sseClients) {
    try { client.res.write(msg); } catch (_) {}
  }
}

// Broadcast data update to clients watching a specific instance
function broadcastUpdate(instancePath) {
  if (sseClients.size === 0) return;
  try {
    const data = scanAgentComms(instancePath);
    const msg  = `data: ${JSON.stringify(data)}\n\n`;
    for (const client of sseClients) {
      if (!instancePath || client.instancePath === instancePath) {
        try { client.res.write(msg); } catch (_) {}
      }
    }
  } catch (err) {
    console.error('Broadcast error:', err.message);
  }
}

// ─── File Watcher ─────────────────────────────────────────────────────────────

let activeWatcher     = null;
let activeWatcherPath = null;
let broadcastTimer    = null;

function debouncedBroadcast(instancePath) {
  if (broadcastTimer) clearTimeout(broadcastTimer);
  broadcastTimer = setTimeout(() => broadcastUpdate(instancePath), 300);
}

function startWatcher(watchPath) {
  if (activeWatcher) {
    try { activeWatcher.close(); } catch (_) {}
    activeWatcher = null;
  }

  activeWatcherPath = watchPath;

  if (!safeStat(watchPath)) {
    console.warn(`Warning: path not found for watcher: ${watchPath}`);
    return;
  }

  try {
    activeWatcher = fs.watch(watchPath, { recursive: true }, (eventType, filename) => {
      if (filename && !filename.includes('.DS_Store')) {
        debouncedBroadcast(watchPath);
      }
    });
    console.log(`Watching: ${watchPath}`);
  } catch (_) {
    // Fallback: watch top-level subdirectories
    for (const sub of ['agents', 'threads', 'archive']) {
      const subPath = path.join(watchPath, sub);
      if (safeStat(subPath)) {
        try {
          fs.watch(subPath, { recursive: false }, () => debouncedBroadcast(watchPath));
        } catch (_2) {}
      }
    }
  }
}

// ─── Path Security ────────────────────────────────────────────────────────────

function isPathSafe(requestedPath) {
  const resolved = path.resolve(requestedPath);
  const dashDir  = path.resolve(__dirname);
  const instances = loadInstances();
  for (const inst of instances) {
    const instResolved = path.resolve(inst.path);
    if (resolved.startsWith(instResolved + path.sep) || resolved === instResolved) {
      return true;
    }
  }
  return resolved.startsWith(dashDir + path.sep) || resolved === dashDir;
}

// ─── MIME Helper ──────────────────────────────────────────────────────────────

function getMime(ext) {
  const map = {
    '.md':   'text/plain; charset=utf-8',
    '.txt':  'text/plain; charset=utf-8',
    '.html': 'text/html; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.js':   'application/javascript; charset=utf-8',
    '.css':  'text/css; charset=utf-8',
    '.png':  'image/png',
    '.jpg':  'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif':  'image/gif',
    '.webp': 'image/webp',
    '.svg':  'image/svg+xml',
  };
  return map[ext] || 'application/octet-stream';
}

// ─── Body Reader ──────────────────────────────────────────────────────────────

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try { resolve(JSON.parse(body)); }
      catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

// ─── Dispatcher Control ───────────────────────────────────────────────────────

function getDispatcherStatus() {
  if (!dispatcherConfig.jobId) {
    return { ok: false, error: 'Dispatcher not configured. Set jobId in config/dispatcher.json.' };
  }
  try {
    const bin = dispatcherConfig.openclawBin || 'openclaw';
    const out = execSync(`${bin} cron list --json`, { encoding: 'utf8', timeout: 5000 }).trim();
    const parsed = JSON.parse(out);
    const jobs   = parsed.jobs || (Array.isArray(parsed) ? parsed : []);
    const job    = jobs.find(j =>
      j.id === dispatcherConfig.jobId || j.name === 'agentcomms-dispatcher'
    );
    return {
      ok:      true,
      enabled: job ? job.enabled !== false : null,
      jobId:   job ? job.id : dispatcherConfig.jobId,
      status:  job ? (job.status || 'ok') : 'unknown',
    };
  } catch (e) {
    return { ok: false, enabled: null, jobId: dispatcherConfig.jobId, status: 'error', error: e.message };
  }
}

function setDispatcherEnabled(enable) {
  if (!dispatcherConfig.jobId) {
    return { ok: false, error: 'Dispatcher not configured. Set jobId in config/dispatcher.json.' };
  }
  const cmd = enable ? 'enable' : 'disable';
  const bin = dispatcherConfig.openclawBin || 'openclaw';
  try {
    execSync(`${bin} cron ${cmd} ${dispatcherConfig.jobId}`, { encoding: 'utf8', timeout: 8000 });
    return { ok: true, enabled: enable };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function wakeAgent(agentId) {
  // Resolve inbox path: config/agent-dispatch.json → fallback to <root>/agents/<id>/inbox
  const inst           = defaultInstance();
  const dispatchPath   = path.join(inst.path, 'config', 'agent-dispatch.json');
  let inboxPath        = `agents/${agentId}/inbox`;
  let inboxAbsolute    = path.join(inst.path, 'agents', agentId, 'inbox');

  if (fs.existsSync(dispatchPath)) {
    try {
      const dispatch = JSON.parse(fs.readFileSync(dispatchPath, 'utf8'));
      const entry    = (dispatch.agents || []).find(a => a.id === agentId);
      if (entry && entry.inboxPath) {
        inboxPath     = entry.inboxPath;
        inboxAbsolute = entry.inboxPath;
      }
    } catch (_) {}
  }

  const wakeMessage = [
    `Check your AgentComms inbox at ${inboxAbsolute} for any new routing signals.`,
    `If inbox is empty, reply NO_REPLY and stop.`,
    `If there ARE new files: 1) Read the routing signal to find the thread folder.`,
    `2) Read the brief.md in that thread folder for the full task.`,
    `3) Complete the task as instructed.`,
    `4) Update the thread's status.md to done.`,
    `5) Move the inbox signal file to your processed/ folder.`,
  ].join(' ');

  try {
    const gwPayload = JSON.stringify({
      agentId,
      task:    wakeMessage,
      mode:    'run',
      runtime: 'subagent',
    });
    const safePayload = gwPayload.replace(/'/g, "'\\''");
    execSync(
      `curl -s -X POST http://localhost:18789/api/sessions/spawn -H 'Content-Type: application/json' -d '${safePayload}'`,
      { timeout: 8000 }
    );
    return { ok: true, message: `Wake signal sent to ${agentId}` };
  } catch (e) {
    // Degrade gracefully if Gateway is unreachable
    return { ok: false, error: `Gateway unreachable or error: ${e.message}` };
  }
}

// ─── Request Router ───────────────────────────────────────────────────────────

function handleRequest(req, res) {
  const urlObj   = new URL(req.url, 'http://localhost');
  const pathname = urlObj.pathname;

  res.setHeader('Access-Control-Allow-Origin', '*');

  // ── SSE ──
  if (pathname === '/events') {
    const instanceKey  = urlObj.searchParams.get('instance') || defaultInstance().key;
    const inst         = instanceByKey(instanceKey);
    const instancePath = inst ? inst.path : defaultInstance().path;

    res.writeHead(200, {
      'Content-Type':  'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection':    'keep-alive',
    });
    res.write('\n');

    const client = { res, instancePath, instanceKey };
    sseClients.add(client);

    try {
      const data = scanAgentComms(instancePath);
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    } catch (err) {
      console.error('Initial SSE error:', err.message);
    }

    req.on('close', () => sseClients.delete(client));
    return;
  }

  // ── Data snapshot ──
  if (pathname === '/data') {
    const instanceKey  = urlObj.searchParams.get('instance') || defaultInstance().key;
    const inst         = instanceByKey(instanceKey);
    const instancePath = inst ? inst.path : defaultInstance().path;
    try {
      const data        = scanAgentComms(instancePath);
      data.instanceKey  = instanceKey;
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(data));
    } catch (err) {
      res.writeHead(500);
      res.end(JSON.stringify({ error: err.message }));
    }
    return;
  }

  // ── Instances list ──
  if (pathname === '/instances' && req.method === 'GET') {
    const list = loadInstances().map(inst => {
      const mailbox = parseMailbox(inst.path);
      return {
        key:         inst.key,
        name:        inst.name,
        displayName: (mailbox && mailbox.mailboxName) ? mailbox.mailboxName : inst.name,
        path:        inst.path,
        builtin:     !!inst.builtin,
        exists:      !!safeStat(inst.path),
        mailbox,
      };
    });
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(list));
    return;
  }

  // ── Validate instance path ──
  if (pathname === '/instances/validate' && req.method === 'POST') {
    readBody(req).then(body => {
      const result = validateInstancePath(body.path || '');
      if (result.ok && result.resolvedPath) {
        const mailbox = parseMailbox(result.resolvedPath);
        if (mailbox) result.mailbox = mailbox;
      }
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(result));
    }).catch(e => {
      res.writeHead(400);
      res.end(JSON.stringify({ ok: false, error: e.message }));
    });
    return;
  }

  // ── Add instance ──
  if (pathname === '/instances/add' && req.method === 'POST') {
    readBody(req).then(body => {
      const { key, name, path: instPath, mailboxId } = body;
      if (!key || !name || !instPath) {
        res.writeHead(400);
        res.end(JSON.stringify({ ok: false, error: 'key, name, and path are required' }));
        return;
      }
      const check = validateInstancePath(instPath);
      if (!check.ok) {
        res.writeHead(400);
        res.end(JSON.stringify({ ok: false, error: check.error }));
        return;
      }
      const list = loadInstances();
      if (list.find(i => i.key === key)) {
        res.writeHead(400);
        res.end(JSON.stringify({ ok: false, error: `Key "${key}" already exists` }));
        return;
      }
      const entry = { key, name, path: check.resolvedPath };
      if (mailboxId) entry.mailboxId = mailboxId;
      list.push(entry);
      saveInstances(list);
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: true, agentCount: check.agentCount, version: check.version, warning: check.warning }));
    }).catch(e => {
      res.writeHead(400);
      res.end(JSON.stringify({ ok: false, error: e.message }));
    });
    return;
  }

  // ── Remove instance ──
  if (pathname === '/instances/remove' && req.method === 'POST') {
    readBody(req).then(body => {
      const { key } = body;
      const list    = loadInstances();
      const inst    = list.find(i => i.key === key);
      if (!inst) {
        res.writeHead(404);
        res.end(JSON.stringify({ ok: false, error: 'Instance not found' }));
        return;
      }
      if (inst.builtin) {
        res.writeHead(403);
        res.end(JSON.stringify({ ok: false, error: 'Cannot remove a built-in instance' }));
        return;
      }
      saveInstances(list.filter(i => i.key !== key));
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: true }));
      broadcastAll({ type: 'instances-changed' });
    }).catch(e => {
      res.writeHead(400);
      res.end(JSON.stringify({ ok: false, error: e.message }));
    });
    return;
  }

  // ── Switch instance (rewires watcher) ──
  if (pathname === '/switch-instance' && req.method === 'POST') {
    readBody(req).then(body => {
      const { key } = body;
      const inst = instanceByKey(key);
      if (!inst) {
        res.writeHead(404);
        res.end(JSON.stringify({ ok: false, error: 'Instance not found' }));
        return;
      }
      startWatcher(inst.path);

      // Push fresh data to SSE clients watching this instance
      try {
        const data       = scanAgentComms(inst.path);
        data.instanceKey = key;
        const msg = `data: ${JSON.stringify(data)}\n\n`;
        for (const client of sseClients) {
          if (client.instanceKey === key) {
            try { client.res.write(msg); } catch (_) {}
          }
        }
      } catch (err) {
        console.error('Switch-instance broadcast error:', err.message);
      }

      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: true, path: inst.path }));
    }).catch(e => {
      res.writeHead(400);
      res.end(JSON.stringify({ ok: false, error: e.message }));
    });
    return;
  }

  // ── Folder browser ──
  if (pathname === '/browse' && req.method === 'GET') {
    const reqPath  = urlObj.searchParams.get('path') || process.env.HOME || '/';
    const expanded = reqPath.replace(/^~/, process.env.HOME || '');
    try {
      if (!safeStat(expanded)) {
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Path not found' }));
        return;
      }
      const entries = safeReadDir(expanded)
        .filter(f => {
          try { return safeStat(path.join(expanded, f)).isDirectory() && !f.startsWith('.'); }
          catch { return false; }
        })
        .sort()
        .map(f => ({ name: f, path: path.join(expanded, f) }));

      const looksLikeAC = ['agents', 'threads', 'archive'].every(
        sub => !!safeStat(path.join(expanded, sub))
      );

      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({
        current: expanded,
        entries,
        looksLikeAC,
        parent: path.dirname(expanded),
      }));
    } catch (e) {
      res.writeHead(500);
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  // ── File serve ──
  if (pathname === '/file') {
    const filePath = urlObj.searchParams.get('path');
    if (!filePath) {
      res.writeHead(400);
      res.end('Missing path parameter');
      return;
    }
    const absPath = path.resolve(filePath);
    if (!isPathSafe(absPath)) {
      res.writeHead(403);
      res.end('Forbidden');
      return;
    }
    const stat = safeStat(absPath);
    if (!stat || !stat.isFile()) {
      res.writeHead(404);
      res.end('File not found.');
      return;
    }
    const ext = path.extname(absPath).toLowerCase();
    res.writeHead(200, {
      'Content-Type': getMime(ext),
      'Access-Control-Allow-Origin': '*',
    });
    fs.createReadStream(absPath).pipe(res);
    return;
  }

  // ── Dispatcher status ──
  if (pathname === '/dispatcher/status') {
    const status = getDispatcherStatus();
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(status));
    return;
  }

  // ── Dispatcher toggle ──
  if (pathname === '/dispatcher/toggle' && req.method === 'POST') {
    readBody(req).then(body => {
      const result = setDispatcherEnabled(body.enable);
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(result));
      if (result.ok) {
        // Broadcast to all SSE clients so every open tab updates
        broadcastAll({ type: 'dispatcher', enabled: result.enabled });
      }
    }).catch(e => {
      res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: false, error: e.message }));
    });
    return;
  }

  // ── Dispatcher wake ──
  if (pathname === '/dispatcher/wake' && req.method === 'POST') {
    readBody(req).then(body => {
      const { agentId } = body;
      if (!agentId) {
        res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ ok: false, error: 'agentId required' }));
        return;
      }
      const result = wakeAgent(agentId);
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(result));
    }).catch(e => {
      res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: false, error: e.message }));
    });
    return;
  }

  // ── Shutdown ──
  if (pathname === '/shutdown' && req.method === 'POST') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ status: 'shutting down' }));
    console.log('AgentComms Dashboard stopped.');
    setTimeout(() => process.exit(0), 100);
    return;
  }

  // ── Index ──
  if (pathname === '/' || pathname === '/index.html') {
    const indexPath = path.join(__dirname, 'index.html');
    const stat      = safeStat(indexPath);
    if (!stat || !stat.isFile()) {
      res.writeHead(404);
      res.end('index.html not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    fs.createReadStream(indexPath).pipe(res);
    return;
  }

  // ── 404 ──
  res.writeHead(404);
  res.end('Not found');
}

// ─── Main ─────────────────────────────────────────────────────────────────────

// Load dispatcher config at startup
loadDispatcherConfig();

const port = parseInt(process.env.AGENTCOMMS_PORT || process.argv[2], 10) || DEFAULT_PORT;

const defaultInst = defaultInstance();
const acStat      = safeStat(defaultInst.path);
if (!acStat || !acStat.isDirectory()) {
  console.warn(`Warning: AgentComms path not found: ${defaultInst.path}`);
  console.warn('Dashboard will load with empty data.');
} else {
  startWatcher(defaultInst.path);
}

const server = http.createServer(handleRequest);

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Error: Port ${port} is already in use.`);
    console.error(`Try: node server.js ${port + 1}`);
    process.exit(1);
  }
  throw err;
});

server.listen(port, '127.0.0.1', () => {
  console.log(`AgentComms Dashboard v0.8: http://localhost:${port}`);
  console.log(`Default instance: ${defaultInst.path}`);
});
