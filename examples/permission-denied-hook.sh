#!/usr/bin/env bash
# PermissionDenied hook: log every auto-mode block, and push headless ones to the phone with a
# proposed rule. Never blocks; always exits 0.
# Env: NTFY_TOPIC (e.g. https://ntfy.sh/<long-random>), KEEPER_URL (optional, e.g. https://keeper.tailnet)
set -u
LOG="${PERM_LOG:-$HOME/.local/state/claude/permission-denials.jsonl}"
mkdir -p "$(dirname "$LOG")"
IN=$(mktemp); trap 'rm -f "$IN"' EXIT
cat > "$IN"   # capture stdin before the heredoc below takes it

python3 - "$LOG" "$IN" <<'PY' 2>/dev/null
import json, sys, datetime, os, subprocess, urllib.request
p = json.load(open(sys.argv[2]))  # payload is untrusted data: never splice it into code
rec = {"ts": datetime.datetime.now().isoformat(), **{k: p.get(k) for k in
       ("session_id", "cwd", "tool_name", "tool_input", "reason", "permission_mode")}}
s = json.dumps(rec)[:8000]
open(sys.argv[1], "a").write(s + "\n")

# Interactive sessions already show the block; push only for unattended runs.
if os.environ.get("CLAUDE_HEADLESS") != "1" and not p.get("agent_id"):
    sys.exit(0)
call = json.dumps(p.get("tool_input"))[:300]
title = f"Blocked: {p.get('tool_name')} in {os.path.basename(p.get('cwd') or '?')}"
body = f"{call}\nReason: {(p.get('reason') or '')[:200]}"
headers = {"Title": title}
keeper = os.environ.get("KEEPER_URL")
if keeper:
    req = urllib.request.Request(f"{keeper}/propose", method="POST",
        data=json.dumps({"kind": "prose", "blocked": call, "why": p.get("reason"),
                         "text": f"(draft) Allow exactly: {call}"}).encode(),
        headers={"Content-Type": "application/json"})
    rid = json.load(urllib.request.urlopen(req, timeout=5))["id"]
    headers["Actions"] = f"view, Review rule, {keeper}/rule/{rid}"
topic = os.environ.get("NTFY_TOPIC")
if topic:
    urllib.request.urlopen(urllib.request.Request(topic, data=body.encode(), headers=headers), timeout=5)
PY
exit 0
