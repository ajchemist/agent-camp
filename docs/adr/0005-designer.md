# The designer curated agent: one agent, modes, several upstreams

Status: proposed (2026-10-11).

`designer` is the second curated agent (ADR 0003): a design engineer for a
product's typography, spacing, layout and motion, carried through DESIGN.md.
It extends ADR 0003 in four places.

- **One agent, modes inside.** The work spans reference analysis, writing
  DESIGN.md, building, and critique. They share one prompt and one set of
  skills, so they are one agent; the delegation message names the mode, and
  the mode decides which skills it reads and which files it may write
  (DESIGN.md only in `direction`, source only in `build`, nothing but a
  critique file in `critique`). Claude Code subagents cannot start
  subagents, so the agent routes among skills and the main agent routes
  among instances: a `build` instance is continued across rounds (Info
  needed, fixes); every `critique` is a fresh instance, which is what keeps a
  critique independent of the build it judges.
- **Several upstreams.** `curated-agents/designer/sources/<name>.nix` pins
  each one (Emil Kowalski's skills, Impeccable, Taste, GSAP's skills); the
  prompt names each by its own placeholder. Each is its own pinned tool
  under ADR 0001 (`designer-<name>` in the briefing, its own update ticket
  and bump PR).
- **Upstreams without releases.** Three of the four tag nothing. They are
  pinned by commit and versioned `0-unstable-<commit date>`; the briefing
  compares against the default branch's head, and a bump moves to it. Two
  commits on the same day look like one version until a later day's commit.
- **The agent's own skills.** What no upstream covers (CSS-native motion,
  type and spacing scales) lives in `curated-agents/designer/skills/` and is
  read from the store like the rest. Browser support for CSS motion moves
  faster than any upstream would track, which is why that one is kept here.

Also: `replaceBuiltins` may be on for one agent at most; two would write the
same built-in's file.

## Considered options

- One agent per stage (reference analyst, writer, builder, verifier), as
  first sketched: rejected. The stages share skills and DESIGN.md as their
  contract, and four descriptions would sit in every session's agent list.
  Independence of critique comes from a fresh instance, not a second
  definition.
- The designer as the main agent (`claude --agent designer`), so it can
  interview the user itself: rejected for now. A subagent returns its
  questions as Info needed and is continued with the answers, which keeps
  its context; and there is no Codex equivalent to rely on.
- Installing Impeccable's hooks so the detector runs on every edit: rejected,
  hooks are harness-wide and would reach every session. `critique` runs the
  detector itself.
- Upstream DESIGN.md writers (Impeccable `document`, Taste's stitch skill):
  not used as writers. DESIGN.md follows Impeccable's format (the DESIGN.md
  spec plus a `## Motion` section) so Impeccable can read it, and only
  `direction` mode writes it.
