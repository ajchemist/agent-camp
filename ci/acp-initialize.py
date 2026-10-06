#!/usr/bin/env python3
"""Start each deployed ACP agent and complete the initialize exchange.

    python3 ci/acp-initialize.py

ACP is JSON-RPC over stdio, one message per line. initialize comes before
authentication, so no account is needed. Exits 1 if any agent fails to
answer with a protocolVersion within the timeout.
"""
import json, subprocess, sys, threading

AGENTS = {
    "claude": ["claude-agent-acp"],
    "codex": ["codex-acp"],
    "pi": ["pi-acp"],
    "goose": ["goose", "acp"],
}
TIMEOUT = 60

def initialize(cmd):
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True)
    req = {"jsonrpc": "2.0", "id": 1, "method": "initialize",
           "params": {"protocolVersion": 1, "clientCapabilities": {}}}
    p.stdin.write(json.dumps(req) + "\n"); p.stdin.flush()
    result = {}
    def read():
        for line in p.stdout:
            try:
                msg = json.loads(line)
            except ValueError:
                continue  # an adapter may log to stdout before it answers
            if msg.get("id") == 1:
                result.update(msg); return
    t = threading.Thread(target=read, daemon=True); t.start(); t.join(TIMEOUT)
    p.kill()
    err = p.stderr.read()[-2000:] if not result else ""
    return result, err

failed = []
for name, cmd in AGENTS.items():
    res, err = initialize(cmd)
    version = res.get("result", {}).get("protocolVersion")
    if version is None:
        failed.append(name)
        print(f"acp[{name}]: FAILED: {res.get('error') or 'no answer'}\n{err}")
    else:
        print(f"acp[{name}]: initialized, protocolVersion {version}")
sys.exit(1 if failed else 0)
