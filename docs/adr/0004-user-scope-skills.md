# User-scope skills: nix pins, the skills CLI lays out

Status: accepted (2026-10-09).

A skill about how someone works (grilling, spec and ticket flows, handoffs) is not about any one repository. Putting it in each repository's `skills-lock.json` or plugin settings mixes personal workflow into the codebase and its history. Those skills go to user scope; a repository keeps only skills about itself.

- **Nix decides what and which version.** `skill-sources/<name>/source.nix` pins the upstream release by commit and hash. It is a pinned tool under ADR 0001 (briefing, update ticket, bump PR).
- **The skills CLI does the layout.** Activation runs `skills add <store path> -g -a <agent>… -s <skill>… -y` (CLI version pinned). The CLI copies to `~/.agents/skills`, symlinks the other agents' dirs and records the store path as a local source in `~/.agents/.skill-lock.json`. The option for where skills go, `agents`, takes the CLI's agent IDs as they are.
- **Re-applied only on a nix change.** A source is added again only when its pin, skill list or agent list changes (`~/.local/state/agent-camp/skills/<name>`). Between changes the host may diverge; the next change overwrites what came from that source.
- **The copies stay read-only.** They keep the store's mode, which marks them as nix's. Taking one over means `skills add` from another source or `skills remove`, documented in the README.
- **Cleanup by provenance.** Skills whose recorded source is a store path and that no source lists any more are removed. Skills from any other source are never touched.
- **Default: user-invoked only.** mattpocock/skills' 16 `disable-model-invocation: true` skills, for `claude-code` and `codex`. They take no context until typed. Model-invoked skills load into every session at user scope, so they stay with a repository or a curated agent (ADR 0003).

## Considered options

- The skills CLI alone (`add` from GitHub, `update -g`): rejected, nothing pins a version and a rename upstream goes unnoticed.
- Nix alone (`home.file` links per agent dir): rejected, it would re-implement the CLI's per-agent layout, which is the part worth reusing.
- `skills add` on every switch: rejected, it would wipe every local change on each switch, not only when nix moves.
- Making the copies writable: rejected, an in-place edit would look like a takeover but vanish on the next nix change without warning.
