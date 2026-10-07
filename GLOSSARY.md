# Glossary

**Pinned tool**: a tool whose version is written in this repo (`bun.nix`, `herdr.nix`, or nixpkgs through `flake.lock`). Moving it forward takes a commit.
_Avoid_: locked tool, fixed tool

**@latest tool**: a tool installed as `<pkg>@latest` on every switch. Nothing in the repo names its version, so there is nothing to bump.
_Avoid_: unpinned tool

**Briefing**: the daily table comparing every tracked tool with its upstream, left in the workflow run summary.
_Avoid_: update matrix, report

**Update ticket**: the one open GitHub issue per pinned tool saying "upstream is ahead of our pin". A newer upstream release rewrites the same ticket, so it never spawns a second one. It closes when the pin catches up.
_Avoid_: bump issue, update issue

**Bump**: a change that moves a pinned tool's version (and hashes) forward.

**Bump PR**: the pull request that carries a bump and closes its update ticket. Opened by automation only after its update ticket is approved.
_Avoid_: update PR, release PR

**Approved**: a maintainer's `approved` label on an issue, which is the only green light to write code for it. A reply, a reaction or a merge is not approval.
_Avoid_: accepted, greenlit

**Gate**: the automation that closes a PR which links no approved issue, and reopens it once the issue is approved.
