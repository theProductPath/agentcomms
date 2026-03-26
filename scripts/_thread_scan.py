#!/usr/bin/env python3
# _thread_scan.py <threads_dir> [agent_filter]
# Prints open (non-terminal) threads in the given directory.
# With agent_filter: prints comma-separated short slugs of threads involving that agent.

import os, re, sys

TERMINAL = {'done', 'closed', 'archived', 'pending-archive', 'complete'}

def is_terminal(sf):
    try:
        with open(sf) as fh:
            raw = fh.read().lower()
        for line in raw.splitlines():
            if re.match(r'[\*#\s\-]*status[\*\s]*:', line):
                for t in TERMINAL:
                    if t in line:
                        return True
            if re.match(r'#.*thread status:\s*(closed|done|archived|complete)', line):
                return True
            if re.match(r'overall.*:\s*done', line):
                return True
    except:
        pass
    return False

def get_label(sf):
    try:
        with open(sf) as fh:
            for line in fh:
                line = line.strip()
                if re.match(r'\*\*[Ss]tatus\*\*:', line):
                    return re.sub(r'\*\*[Ss]tatus\*\*:\s*', '', line).strip()
                if re.match(r'[Ss]tatus:\s', line):
                    return re.sub(r'[Ss]tatus:\s*', '', line).strip()
    except:
        pass
    return ''

def thread_involves_agent(thread_slug, thread_path, agent):
    """Check if agent appears in thread slug or any file in the thread."""
    agent_lower = agent.lower()
    if agent_lower in thread_slug.lower():
        return True
    try:
        for fname in os.listdir(thread_path):
            if agent_lower in fname.lower():
                return True
            fpath = os.path.join(thread_path, fname)
            if fname.endswith('.md') and os.path.isfile(fpath):
                try:
                    content = open(fpath).read(2000).lower()
                    if agent_lower in content:
                        return True
                except:
                    pass
    except:
        pass
    return False

threads_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
agent_filter = sys.argv[2] if len(sys.argv) > 2 else None

open_threads = []
if os.path.isdir(threads_dir):
    for thread in sorted(os.listdir(threads_dir)):
        td = os.path.join(threads_dir, thread)
        if not os.path.isdir(td):
            continue
        sf = os.path.join(td, 'status.md')
        if os.path.isfile(sf) and is_terminal(sf):
            continue
        if agent_filter and not thread_involves_agent(thread, td, agent_filter):
            continue
        label = get_label(sf) if os.path.isfile(sf) else ''
        # Short slug: strip date prefix for compact display
        short = re.sub(r'^\d{4}-\d{2}-\d{2}_', '', thread)
        open_threads.append((thread, short, label))

if agent_filter:
    # Compact comma-separated output for inline column
    if open_threads:
        print(', '.join(s for _, s, _ in open_threads[:3]) + (f' +{len(open_threads)-3}' if len(open_threads) > 3 else ''))
    # No output = no threads (caller handles)
else:
    if open_threads:
        for thread, short, label in open_threads:
            suffix = f' — {label}' if label else ''
            print(f'  📂 {thread}{suffix}')
    else:
        print('  (no open threads)')
