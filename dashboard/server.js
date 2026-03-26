/**
 * AgentComms Dashboard — server.js
 * Zero external dependencies. Uses only Node.js built-ins.
 * Node.js >= 14 required.
 *
 * Usage:
 *   node server.js [port]
 *   Default port: 7842
 *
 * Config (edit these three constants to adapt for your team):
 *   AGENTCOMMS  — absolute path to your AgentComms folder
 *   AGENT_EMOJIS — map of agent names to display emojis
 *   DEFAULT_PORT — default port for the dashboard server
 */

'use strict';

const http = require('http');
const fs   = require('fs');
const path = require('path');

// ─── Config ───────────────────────────────────────────────────────────────────

// Path to your AgentComms folder. Defaults to the parent of this file's parent.
// Override here or set AGENTCOMMS_PATH env var.
const AGENTCOMMS = process.env.AGENTCOMMS_PATH
  || path.resolve(__dirname, '..');

// Map agent folder names to display emojis.
const AGENT_EMOJIS = {
  'ac-dev':    '👨🏽‍💻',
  'ac-orch':   '🎯',
  'ac-pm':     '📊',
  'ac-design': '👩🏽‍💻',
  'stratty':   '🎯',
  'archy':     '🏗️',
  'stacky':    '⚡',
  'kanby':     '📋',
  'marky':     '✍️',
  'example-agent': '🤖',
};

// Port can be specified via AGENTCOMMS_PORT env var, CLI arg, or defaults to 7843
// (using 7843 to avoid conflict with development instance at 7842)
const DEFAULT_PORT = 7843;

// ─── Helpers ──────────────────────────────────────────────────────────────────

function safeReadDir(dirPath) {
  try {
    return fs.readdirSync(dirPath);
  } catch (_) {
    return [];
  }
}

function safeStat(filePath) {
  try {
    return fs.statSync(filePath);
  } catch (_) {
    return null;
  }
}

function safeReadFile(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch (_) {
    return null;
  }
}

function relativeTime(mtimeMs) {
  const diffMs = Date.now() - mtimeMs;
  const diffSec = Math.floor(diffMs / 1000);
  if (diffSec < 60)      return `${diffSec}s ago`;
  if (diffSec < 3600)    return `${Math.floor(diffSec / 60)}m ago`;
  if (diffSec < 86400)   return `${Math.floor(diffSec / 3600)}h ago`;
  if (diffSec < 604800)  return `${Math.floor(diffSec / 86400)}d ago`;
  return `${Math.floor(diffSec / 604800)}w ago`;
}

function latestMtime(dirPath) {
  let latest = 0;
  function walk(p) {
    const stat = safeStat(p);
    if (!stat) return;
    if (stat.mtimeMs > latest) latest = stat.mtimeMs;
    if (stat.isDirectory()) {
      for (const entry of safeReadDir(p)) {
        walk(path.join(p, entry));
      }
    }
  }
  walk(dirPath);
  return latest;
}

function parseStatus(threadPath) {
  const statusFile = path.join(threadPath, 'status.md');
  const content = safeReadFile(statusFile);
  if (!content) return 'unknown';
  const match = content.match(/^status:\s*(.+)/im);
  return match ? match[1].trim().toLowerCase() : 'unknown';
}

function detectAgents(threadPath) {
  const agents = new Set();
  const files = safeReadDir(threadPath);
  for (const file of files) {
    const content = safeReadFile(path.join(threadPath, file));
    if (!content) continue;
    // Look for agent name patterns in file content
    const agentMatches = content.match(/\b(ac-dev|ac-orch|ac-pm|ac-design|stratty|archy|stacky|kanby|marky|example-agent)\b/gi);
    if (agentMatches) {
      for (const a of agentMatches) agents.add(a.toLowerCase());
    }
    // Also look for "From: X" patterns
    const fromMatch = content.match(/^From:\s*([^\n|→]+)/gim);
    if (fromMatch) {
      for (const m of fromMatch) {
        const name = m.replace(/^From:\s*/i, '').trim().toLowerCase()
          .replace(/[^a-z0-9-]/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
        if (name) agents.add(name);
      }
    }
  }
  return Array.from(agents);
}

// ─── Data Scanner ─────────────────────────────────────────────────────────────

function scanAgentComms() {
  const agentsDir   = path.join(AGENTCOMMS, 'agents');
  const threadsDir  = path.join(AGENTCOMMS, 'threads');
  const archiveDir  = path.join(AGENTCOMMS, 'archive');

  const now = Date.now();
  const sevenDays = 7 * 24 * 60 * 60 * 1000;

  // ── Agents ──
  const agents = [];
  for (const agentName of safeReadDir(agentsDir).sort()) {
    const agentPath  = path.join(agentsDir, agentName);
    const stat = safeStat(agentPath);
    if (!stat || !stat.isDirectory()) continue;

    const inboxPath     = path.join(agentPath, 'inbox');
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

    const lastMtime = latestMtime(agentPath);
    const isActive  = lastMtime > (now - sevenDays) || inboxFiles.length > 0;

    agents.push({
      name:           agentName,
      emoji:          AGENT_EMOJIS[agentName] || '🤖',
      inboxCount:     inboxFiles.length,
      inboxFiles,
      processedFiles,
      processedCount: safeReadDir(processedPath).filter(f => f !== '.keep' && !f.startsWith('.')).length,
      lastMtime,
      lastActive:     lastMtime > 0 ? relativeTime(lastMtime) : 'never',
      isActive,
    });
  }

  // ── Threads ──
  const threads = [];

  function scanThreadDir(dirPath, zone) {
    for (const slug of safeReadDir(dirPath).sort()) {
      const tp = path.join(dirPath, slug);
      const stat = safeStat(tp);
      if (!stat || !stat.isDirectory()) continue;

      const rawStatus = parseStatus(tp);
      const status = zone === 'archive' && rawStatus === 'unknown' ? 'archived' : rawStatus;

      const files = safeReadDir(tp).filter(f => !f.startsWith('.')).map(f => ({
        name: f,
        path: path.join(tp, f),
      }));

      const lastMtime = latestMtime(tp);

      threads.push({
        slug,
        zone,
        status,
        date:        slug.slice(0, 10),
        files,
        agents:      detectAgents(tp),
        lastMtime,
        lastActive:  lastMtime > 0 ? relativeTime(lastMtime) : 'never',
      });
    }
  }

  scanThreadDir(threadsDir, 'threads');
  scanThreadDir(archiveDir, 'archive');

  // ── Stats ──
  const activeAgents = agents.filter(a => a.isActive).length;
  const inFlight     = agents.reduce((sum, a) => sum + a.inboxCount, 0);
  const threadsOpen  = threads.filter(t =>
    t.zone === 'threads' && t.status !== 'done' && t.status !== 'archived'
  ).length;
  const archived     = threads.filter(t =>
    t.zone === 'archive' || t.status === 'done'
  ).length;

  return { agents, threads, stats: { activeAgents, inFlight, threadsOpen, archived } };
}

// ─── SSE clients ──────────────────────────────────────────────────────────────

const sseClients = new Set();

function broadcastUpdate() {
  if (sseClients.size === 0) return;
  try {
    const data = JSON.stringify(scanAgentComms());
    const msg  = `data: ${data}\n\n`;
    for (const res of sseClients) {
      try { res.write(msg); } catch (_) {}
    }
  } catch (err) {
    console.error('Broadcast error:', err.message);
  }
}

// Debounce file-watch events
let broadcastTimer = null;
function debouncedBroadcast() {
  if (broadcastTimer) clearTimeout(broadcastTimer);
  broadcastTimer = setTimeout(broadcastUpdate, 300);
}

// ─── File Watcher ─────────────────────────────────────────────────────────────

function startWatcher() {
  // Watch with recursive if supported (Node 19.1+ on macOS/Windows)
  // Fall back to non-recursive on older Node/Linux
  try {
    fs.watch(AGENTCOMMS, { recursive: true }, (eventType, filename) => {
      if (filename && !filename.includes('.DS_Store')) {
        debouncedBroadcast();
      }
    });
  } catch (_) {
    // Fallback: watch top-level directories
    for (const sub of ['agents', 'threads', 'archive']) {
      const subPath = path.join(AGENTCOMMS, sub);
      if (safeStat(subPath)) {
        try {
          fs.watch(subPath, { recursive: false }, debouncedBroadcast);
        } catch (_) {}
      }
    }
  }
}

// ─── Path Security ────────────────────────────────────────────────────────────

function isPathSafe(requestedPath) {
  const resolved  = path.resolve(requestedPath);
  const agentsDir = path.resolve(AGENTCOMMS);
  // Also allow dashboard/ files themselves
  const dashDir   = path.resolve(__dirname);
  return resolved.startsWith(agentsDir + path.sep) ||
         resolved.startsWith(dashDir   + path.sep) ||
         resolved === agentsDir;
}

// ─── MIME helper ─────────────────────────────────────────────────────────────

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
    '.svg':  'image/svg+xml',
  };
  return map[ext] || 'application/octet-stream';
}

// ─── Request Router ───────────────────────────────────────────────────────────

function handleRequest(req, res) {
  const urlObj = new URL(req.url, `http://localhost`);
  const pathname = urlObj.pathname;

  // ── SSE ──
  if (pathname === '/events') {
    res.writeHead(200, {
      'Content-Type':  'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection':    'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write('\n'); // flush headers
    sseClients.add(res);

    // Send initial state immediately
    try {
      const data = JSON.stringify(scanAgentComms());
      res.write(`data: ${data}\n\n`);
    } catch (err) {
      console.error('Initial SSE error:', err.message);
    }

    req.on('close', () => sseClients.delete(res));
    return;
  }

  // ── Data snapshot ──
  if (pathname === '/data') {
    try {
      const data = JSON.stringify(scanAgentComms());
      res.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8',
        'Access-Control-Allow-Origin': '*',
      });
      res.end(data);
    } catch (err) {
      res.writeHead(500);
      res.end(JSON.stringify({ error: err.message }));
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

  // ── Shutdown endpoint ──
  if (pathname === '/shutdown') {
    if (req.method !== 'POST') {
      res.writeHead(405);
      res.end('Method not allowed');
      return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ status: 'shutting down' }));
    console.log('AgentComms Dashboard stopped.');
    setTimeout(() => process.exit(0), 100);
    return;
  }

  // ── Serve index.html ──
  if (pathname === '/' || pathname === '/index.html') {
    const indexPath = path.join(__dirname, 'index.html');
    const stat = safeStat(indexPath);
    if (!stat || !stat.isFile()) {
      res.writeHead(404);
      res.end('index.html not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    fs.createReadStream(indexPath).pipe(res);
    return;
  }

  // 404
  res.writeHead(404);
  res.end('Not found');
}

// ─── Main ─────────────────────────────────────────────────────────────────────

const port = parseInt(process.env.AGENTCOMMS_PORT || process.argv[2], 10) || DEFAULT_PORT;

// Validate AGENTCOMMS path
const acStat = safeStat(AGENTCOMMS);
if (!acStat || !acStat.isDirectory()) {
  console.warn(`Warning: AgentComms path not found: ${AGENTCOMMS}`);
  console.warn('Dashboard will load with empty data.');
  console.warn('Update the AGENTCOMMS constant in server.js to your actual path.');
} else {
  startWatcher();
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
  console.log(`AgentComms Dashboard: http://localhost:${port}`);
  console.log(`Watching: ${AGENTCOMMS}`);
});
