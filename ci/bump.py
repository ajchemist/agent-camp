#!/usr/bin/env python3
"""Bump a pinned tool to upstream's latest release: version and every hash.

Usage: bump.py <bun|herdr|ponytail|mattpocock-skills>   (prints the new version, or nothing if already current)
Hashes are the sha256 of each release asset, downloaded and converted to SRI.
ponytail and mattpocock-skills are source trees (fetchFromGitHub): the release's commit, and the
hash from `nix flake prefetch`, so those need nix on PATH.
"""
import base64, hashlib, json, os, re, subprocess, sys, urllib.request

TOOLS = {  # file, repo, tag prefix, asset URL suffix (bun ships zips)
    "bun": ("bun.nix", "oven-sh/bun", "bun-v", ".zip"),
    "herdr": ("herdr.nix", "herdrdev/herdr", "v", ""),
    "ponytail": ("curated-agents/ponytail/source.nix", "DietrichGebert/ponytail", "v", None),
    "mattpocock-skills": ("skill-sources/mattpocock-skills/source.nix", "mattpocock/skills", "v", None),
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
    if ext is None:  # source tree: pin the tag's commit
        rev = json.loads(fetch(f"https://api.github.com/repos/{repo}/commits/{tag}"))["sha"]
        hash_ = json.loads(subprocess.run(["nix", "flake", "prefetch", "--json", f"github:{repo}/{rev}"],
                                          check=True, capture_output=True, text=True).stdout)["hash"]
        src = re.sub(r'rev = "[0-9a-f]{40}"', f'rev = "{rev}"', src)
        src = re.sub(r'hash = "sha256-[^"]+"', f'hash = "{hash_}"', src)
    for asset, old in re.findall(r'asset = "([^"]+)"; hash = "([^"]+)"', src):
        blob = fetch(f"https://github.com/{repo}/releases/download/{tag}/{asset}{ext}")
        src = src.replace(old, "sha256-" + base64.b64encode(hashlib.sha256(blob).digest()).decode())
    open(path, "w").write(src)
    print(latest)

if __name__ == "__main__":
    main()
