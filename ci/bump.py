#!/usr/bin/env python3
"""Bump a pinned tool to upstream's latest release: version and every hash.

Usage: bump.py <bun|herdr>   (prints the new version, or nothing if already current)
Hashes are the sha256 of each release asset, downloaded and converted to SRI.
"""
import base64, hashlib, json, os, re, sys, urllib.request

TOOLS = {  # file, repo, tag prefix, asset URL suffix (bun ships zips)
    "bun": ("bun.nix", "oven-sh/bun", "bun-v", ".zip"),
    "herdr": ("herdr.nix", "herdrdev/herdr", "v", ""),
}

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "agent-camp"})
    if "api.github.com" in url and os.environ.get("GITHUB_TOKEN"):
        req.add_header("Authorization", "Bearer " + os.environ["GITHUB_TOKEN"])
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()

def main():
    path, repo, prefix, ext = TOOLS[sys.argv[1]]
    src = open(path).read()
    current = re.search(r'version = "([^"]+)"', src).group(1)
    tag = json.loads(fetch(f"https://api.github.com/repos/{repo}/releases/latest"))["tag_name"]
    latest = tag.removeprefix(prefix)
    if latest == current:
        return
    src = src.replace(f'version = "{current}"', f'version = "{latest}"', 1)
    for asset, old in re.findall(r'asset = "([^"]+)"; hash = "([^"]+)"', src):
        blob = fetch(f"https://github.com/{repo}/releases/download/{tag}/{asset}{ext}")
        src = src.replace(old, "sha256-" + base64.b64encode(hashlib.sha256(blob).digest()).decode())
    open(path, "w").write(src)
    print(latest)

if __name__ == "__main__":
    main()
