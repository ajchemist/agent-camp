#!/usr/bin/env python3
"""Daily update briefing: one Markdown table of every CLI agent-camp tracks.

Usage: updates.py <harnesses.json> <goose nixpkgs version> [--tickets]
@latest tools (npm, PyPI) have nothing pinned: the row says what the next
switch installs. Pinned tools (bun, herdr, the ponytail curated agent's upstream,
the user-scope skill sources, goose via flake.lock) are compared.
--tickets keeps one update ticket per pinned tool (docs/adr/0001).
"""
import json, os, re, subprocess, sys, urllib.request
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

PONYTAIL = "curated-agents/ponytail/source.nix"
MATTPOCOCK = "skill-sources/mattpocock-skills/source.nix"

def pinned(path):
    return re.search(r'version = "([^"]+)"', open(path).read()).group(1)

def age(ts):
    days = (datetime.now(timezone.utc) - datetime.fromisoformat(ts.replace("Z", "+00:00"))).days
    return "today" if days == 0 else f"{days}d ago"

def main():
    harnesses, goose_nix = json.load(open(sys.argv[1])), sys.argv[2]
    rows = []  # (tool, source, current, latest, released, status)

    def row(tool, source, current, fetch):
        try:
            latest, ts = fetch()
        except Exception as e:  # one dead registry must not hide the rest
            rows.append((tool, source, current, "?", "?", f"⚠️ {e}"))
            return None
        fresh = (datetime.now(timezone.utc) - datetime.fromisoformat(ts.replace("Z", "+00:00"))).days < 1
        if current == "@latest":
            status = "🆕 new in 24h" if fresh else "—"
        else:
            status = "✅ current" if current == latest else "⬆️ bump"
        rows.append((tool, source, current, latest, age(ts), status))
        return latest

    for a in harnesses:
        if a["via"] == "bun":
            row(a["bin"], f"npm `{a['pkg']}`", "@latest", lambda p=a["pkg"]: npm(p))
        elif a["via"] == "uv":
            row(a["bin"], f"PyPI `{a['pkg']}`", "@latest", lambda p=a["pkg"]: pypi(p))
        elif a["via"] == "nix":
            row(a["bin"], "nixpkgs (flake.lock)", goose_nix, lambda: gh("block/goose", "v"))
        if a["acp"]:
            row(a["acp"]["bin"], f"npm `{a['acp']['pkg']}`", "@latest", lambda p=a["acp"]["pkg"]: npm(p))
    # goose is pinned too, but through nix-basecamp's nixpkgs: briefing only (ADR 0001).
    tickets = {
        "bun": (pinned("bun.nix"), row("bun", "bun.nix (pinned)", pinned("bun.nix"), lambda: gh("oven-sh/bun", "bun-v"))),
        "herdr": (pinned("herdr.nix"), row("herdr", "herdr.nix (pinned)", pinned("herdr.nix"), lambda: gh("herdrdev/herdr", "v"))),
        "ponytail": (pinned(PONYTAIL), row("ponytail", "curated agent upstream (pinned)", pinned(PONYTAIL), lambda: gh("DietrichGebert/ponytail", "v"))),
        "mattpocock-skills": (pinned(MATTPOCOCK), row("mattpocock-skills", "user-scope skills (pinned)", pinned(MATTPOCOCK), lambda: gh("mattpocock/skills", "v"))),
    }

    print(f"## agent-camp update briefing — {datetime.now(timezone.utc):%Y-%m-%d}\n")
    print("| Tool | Source | Current | Latest | Released | Status |")
    print("|---|---|---|---|---|---|")
    for r in rows:
        print("| " + " | ".join(r) + " |")
    print("\n`@latest` tools update on the next switch; ⬆️ rows need a pin bump.")
    if "--tickets" in sys.argv:
        for tool, (current, latest) in tickets.items():
            if latest:  # an unreachable upstream leaves the ticket as it is
                sync_ticket(tool, current, latest)

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout

def sync_ticket(tool, current, latest):
    """One open update ticket per pinned tool: open it, rewrite it as upstream moves, close it once caught up."""
    found = json.loads(run("gh", "issue", "list", "--state", "open", "--label", "update",
                           "--label", f"update:{tool}", "--json", "number,title,labels"))
    issue = found[0] if found else None
    if current == latest:
        if issue:
            run("gh", "issue", "close", str(issue["number"]), "--comment", f"{tool} is pinned at {current}, upstream's latest. Closing.")
        return
    title = f"Bump {tool} {current} → {latest}"
    major = "" if current.split(".")[0] == latest.split(".")[0] else "\n\n> [!WARNING]\n> Major version change."
    body = (f"Upstream {tool} is at **{latest}**; this repo pins **{current}**.{major}\n\n"
            "Label this `approved` and automation opens the bump PR (`bump.yml`). "
            "Kept up to date by the daily update briefing; one ticket per tool (docs/adr/0001).")
    if not issue:
        print(run("gh", "issue", "create", "--title", title, "--body", body,
                  "--label", "update", "--label", f"update:{tool}", "--label", "needs-triage"), file=sys.stderr)
        return
    if issue["title"] == title:
        return
    n = str(issue["number"])
    run("gh", "issue", "edit", n, "--title", title, "--body", body)
    run("gh", "issue", "comment", n, "--body", f"Upstream moved to {latest}.")
    if any(l["name"] == "approved" for l in issue["labels"]):
        run("gh", "workflow", "run", "bump.yml", "-f", f"tool={tool}")

if __name__ == "__main__":
    main()
