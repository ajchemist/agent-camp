#!/usr/bin/env python3
"""Daily update briefing: one Markdown table of every CLI agent-camp tracks.

Usage: updates.py <agents.json> <goose nixpkgs version>
@latest tools (npm, PyPI) have nothing pinned: the row says what the next
switch installs. Pinned tools (bun, herdr, goose via flake.lock) are compared.
"""
import json, os, re, sys, urllib.request
from datetime import datetime, timezone

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "agent-camp"})
    if "api.github.com" in url and os.environ.get("GITHUB_TOKEN"):
        req.add_header("Authorization", "Bearer " + os.environ["GITHUB_TOKEN"])
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def npm(pkg):
    d = get("https://registry.npmjs.org/" + pkg.replace("/", "%2f"))
    v = d["dist-tags"]["latest"]
    return v, d["time"][v]

def pypi(pkg):
    d = get(f"https://pypi.org/pypi/{pkg}/json")
    v = d["info"]["version"]
    return v, d["releases"][v][0]["upload_time_iso_8601"]

def gh(repo, prefix):
    d = get(f"https://api.github.com/repos/{repo}/releases/latest")
    return d["tag_name"].removeprefix(prefix), d["published_at"]

def pinned(path):
    return re.search(r'version = "([^"]+)"', open(path).read()).group(1)

def age(ts):
    days = (datetime.now(timezone.utc) - datetime.fromisoformat(ts.replace("Z", "+00:00"))).days
    return "today" if days == 0 else f"{days}d ago"

def main():
    agents, goose_nix = json.load(open(sys.argv[1])), sys.argv[2]
    rows = []  # (tool, source, current, latest, released, status)

    def row(tool, source, current, fetch):
        try:
            latest, ts = fetch()
        except Exception as e:  # one dead registry must not hide the rest
            rows.append((tool, source, current, "?", "?", f"⚠️ {e}"))
            return
        fresh = (datetime.now(timezone.utc) - datetime.fromisoformat(ts.replace("Z", "+00:00"))).days < 1
        if current == "@latest":
            status = "🆕 new in 24h" if fresh else "—"
        else:
            status = "✅ current" if current == latest else "⬆️ bump"
        rows.append((tool, source, current, latest, age(ts), status))

    for a in agents:
        if a["via"] == "bun":
            row(a["bin"], f"npm `{a['pkg']}`", "@latest", lambda p=a["pkg"]: npm(p))
        elif a["via"] == "uv":
            row(a["bin"], f"PyPI `{a['pkg']}`", "@latest", lambda p=a["pkg"]: pypi(p))
        elif a["via"] == "nix":
            row(a["bin"], "nixpkgs (flake.lock)", goose_nix, lambda: gh("block/goose", "v"))
        if a["acp"]:
            row(a["acp"]["bin"], f"npm `{a['acp']['pkg']}`", "@latest", lambda p=a["acp"]["pkg"]: npm(p))
    row("bun", "bun.nix (pinned)", pinned("bun.nix"), lambda: gh("oven-sh/bun", "bun-v"))
    row("herdr", "herdr.nix (pinned)", pinned("herdr.nix"), lambda: gh("herdrdev/herdr", "v"))

    print(f"## agent-camp update briefing — {datetime.now(timezone.utc):%Y-%m-%d}\n")
    print("| Tool | Source | Current | Latest | Released | Status |")
    print("|---|---|---|---|---|---|")
    for r in rows:
        print("| " + " | ".join(r) + " |")
    print("\n`@latest` tools update on the next switch; ⬆️ rows need a pin bump.")

if __name__ == "__main__":
    main()
