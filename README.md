# agent-camp

[한국어](README.ko.md)

agent-camp installs harnesses (coding-agent CLIs), their ACP adapters, and
[herdr](https://herdr.dev) through a Home Manager module. It installs no
harness you did not say yes to. Curated agents and user-scope skills, which are
only files for the harnesses, are on by default and can be switched off.

```
upstream       nixpkgs, Home Manager, nix-darwin (your flake.lock pins them)
agent-camp     harnesses + ACP adapters + herdr, and the bun/fnm/uv they need
emacs-camp     agent-shell talks to the adapters (CI uses agent-camp)
your flake     which harnesses, herdr config, agent config files
```

## Harnesses

| bin | installed with | ACP adapter (`<bin>-acp`) | herdr hook |
|---|---|---|---|
| claude | `bun add -g @anthropic-ai/claude-code` | `claude-agent-acp` | yes |
| codex | `bun add -g @openai/codex` | `codex-acp` | yes |
| pi | `bun add -g @earendil-works/pi-coding-agent` | `pi-acp` | yes |
| omp | `bun add -g @oh-my-pi/pi-coding-agent` | none | yes |
| goose | nixpkgs `goose-cli` | built in (`goose acp`) | no |
| kimi | `uv tool install kimi-cli` | built in (`kimi acp`) | yes |
| hermes | by hand | none | yes |

The harnesses release almost daily, so nothing is pinned: every switch runs
`<pkg>@latest`, which is a no-op when current. ACP adapters are what editors
use to talk to a harness (Emacs' agent-shell, Zed); they are separate packages
and separate answers.

## What gets installed

Importing the module installs bun (pinned ahead of nixpkgs), fnm with one LTS
node, and uv. Each harness and each adapter is then decided per host:

1. A Nix option, if the downstream set one:
   `agent-camp.harnesses.<bin>.enable` and `agent-camp.harnesses.<bin>.acp`
   (`true`/`false`).
2. Otherwise the host's answer in `~/.config/agent-camp/harnesses`
   (`claude=yes`, `claude-acp=no`, one per line).
3. No answer: not installed.

The answers come from `agent-camp-ask` (`lib.ask`), a checklist that a
downstream `nix run` app runs before its build. It shows only undecided items,
with nothing preselected. Unticked items are recorded as `no`. Without a
terminal it asks nothing and records nothing, so a non-interactive run
installs only what the options force.

herdr is opt-in: `agent-camp.herdr.enable = true` installs its release binary,
the plugins listed in `agent-camp.herdr.plugins` (pinned by commit), and an
integration hook for every installed harness that has one, so a restarted herdr
server resumes each harness's session. herdr's own `config.toml` stays with the
downstream.

## Curated agents

Subagent profiles agent-camp ships, one source each in `curated-agents/`,
rendered per harness ([ADR 0003](docs/adr/0003-curated-agents.md)):

| agent | what it is | default harnesses |
|---|---|---|
| `ponytail` | a senior engineer that reads [ponytail](https://github.com/DietrichGebert/ponytail)'s skills from a pinned store path, without installing them as skills; it edits your working tree and the main agent takes its work over | claude, codex |
| `designer` | a design engineer for typography, spacing, layout and motion through DESIGN.md, in four modes (reference, direction, build, critique); reads [Emil Kowalski](https://github.com/emilkowalski/skills), [Impeccable](https://github.com/pbakaus/impeccable), [Taste](https://github.com/Leonxlnx/taste-skill) and [GSAP](https://github.com/greensock/gsap-skills) skills plus its own ([ADR 0005](docs/adr/0005-designer.md)) | claude, codex |

```nix
agent-camp.curated-agents.ponytail.harnesses.kimi = true;  # also ~/.agents/agents/ponytail.md
agent-camp.curated-agents.ponytail.replaceBuiltins = true; # also replace built-in coding subagents (kimi `coder`); one agent at most
agent-camp.curated-agents.ponytail.activation = "off";     # or none at all (see Activation)
```

Files: claude `~/.claude/agents/<name>.md`, codex `~/.codex/agents/<name>.toml`,
kimi `~/.agents/agents/<name>.md`. pi has no built-in subagents, so it gets none yet.

How ponytail was built and checked: [docs/curated-agent-workflow.md](docs/curated-agent-workflow.md).
What each harness loads and how to leave it out: [docs/harness-context.md](docs/harness-context.md).

### Activation

An installed agent is delegated to only where its delegation rules
(`curated-agents/<name>/delegation.md`) are in the main agent's instructions
and switched on. Three layers decide, the same way for every curated agent.
A later layer wins: **session over repository over module**.

1. **Module**, at deploy time: `agent-camp.curated-agents.<name>.activation`.

   | value | what is installed | the rules are on |
   |---|---|---|
   | `global` (designer's default) | the agent, and its rules in each harness's user-level instructions | in every repository, unless its `AGENTS.md` switches them off |
   | `opt-in` (ponytail's default) | the same | only where a repository's `AGENTS.md` switches them on, or carries the rules itself (pasted, as before) |
   | `off` | nothing | nowhere |

   `enable = false`, the older option, is the same as `"off"`.

   The rules go where each harness reads user-level instructions, without
   taking over a file you write:

   - claude: `~/.claude/rules/agent-camp-curated-agents.md`, a file of the
     module's own. Claude Code loads user rules in every session beside
     `~/.claude/CLAUDE.md`, which stays yours.
   - codex: a marked block (`<!-- agent-camp curated agents: begin … end -->`)
     at the end of `~/.codex/AGENTS.md`, rewritten on every switch and removed
     when no agent is installed. Codex reads only that one file and includes
     nothing from it. The rest of the file stays as you wrote it; edits inside
     the block are lost. If the file is a link (for example to a shared
     `~/.agents/AGENTS.md`), the switch leaves it alone and warns: add the
     rules where the link points yourself. A `~/.codex/AGENTS.override.md`
     replaces `AGENTS.md`, block and all.
   - kimi: none. kimi-cli reads `AGENTS.md` only inside the project, so an
     agent installed for kimi is used only in a repository whose `AGENTS.md`
     carries its rules.

2. **Repository**: one line in its `AGENTS.md`, the same shape for every agent:

   ```
   curated-agents: designer off
   curated-agents: ponytail on
   ```

   The rules' first paragraph tells the main agent to obey it. The line is a
   rule the model follows, not an enforcement. In Claude Code the enforced
   form is a deny rule in the repository's `.claude/settings.json`, which
   Claude Code enforces whatever the model reads:

   ```json
   { "permissions": { "deny": ["Agent(designer)"] } }
   ```

   Codex and kimi have no per-agent deny.

3. **Session**: `AGENT_CAMP_DISABLE_AGENTS="designer,ponytail" claude` (comma or
   space separated). A session-start hook the module installs
   (`~/.local/share/agent-camp/session-start`) prints "Do not delegate to the
   designer subagent in this session" for each name, and the harness adds that
   to the context. It disables only; it cannot switch an agent on.

   - claude: in `~/.claude/settings.json` `hooks.SessionStart`, merged like the
     read rule below. It runs on start, resume, `/clear` and compaction.
   - codex: in `~/.codex/hooks.json` `hooks.SessionStart`, merged the same way.
     Codex runs a hook only once you trust it: open `/hooks` in the TUI once
     after the first switch. The hook's command is a fixed path, so the trust
     lasts across switches, including ones that change what the script prints.
   - kimi: none. kimi-cli runs SessionStart hooks but drops their output.

   Both hooks are installed while any curated agent goes to that harness.

| | module (user-level rules) | repository line | enforced repository deny | session variable |
|---|---|---|---|---|
| claude | yes | yes | `Agent(<name>)` | yes |
| codex | yes, unless `~/.codex/AGENTS.md` is a link | yes | no | yes, once the hook is trusted |
| kimi | no | only where `AGENTS.md` carries the rules | no | no |

### Claude Code read rule

Claude Code asks before a read outside the workspace, and a headless run
(`claude -p`) refuses it, so a curated agent could not read its skills. While
any curated agent goes to Claude Code, a switch puts `Read(//nix/store/**)` in
`permissions.allow` of `~/.claude/settings.json`. Claude Code writes that file
too, so the module does not own it:

- Only `permissions.allow` changes: the rules the module added last time
  (recorded in `~/.local/state/agent-camp/claude-allow`) come out, the current
  ones go in after yours. Every other key and rule stays as it was.
- The file is written only when the rules change. Disabling every curated
  agent for Claude Code removes them.
- The session hook goes into `hooks.SessionStart` the same way (state in
  `claude-session-start`), and Codex's into `~/.codex/hooks.json`
  (`codex-session-start`).
- A file that is a link or not valid JSON is left alone, with a warning.

Worth knowing:

- A write passes the whole file through `jq`, so its formatting becomes jq's
  (two-space indent, the same as Claude Code's).
- Delete the rule by hand and it stays deleted until the rules change, or
  until you delete the state file.
- A rule you had added yourself that equals the module's counts as the
  module's, and goes when the module removes its rules.
- Claude Code writing the file during a switch can lose that one write.

## User-scope skills

Skills that are about how you work, not about one repository, live at user
scope instead of in each repository's `skills-lock.json` or plugin settings
([ADR 0004](docs/adr/0004-user-scope-skills.md)). Nix pins each source in
`skill-sources/<name>/source.nix`; the [skills CLI](https://github.com/vercel-labs/skills)
lays them out: `skills add <store path> -g -a <agent>… -s <skill>…` copies each
skill to `~/.agents/skills` and symlinks it into the other agents (global installs
keep `~/.agents/skills` even for `claude-code` alone).

| source | default skills | default agents |
|---|---|---|
| `mattpocock-skills` ([mattpocock/skills](https://github.com/mattpocock/skills)) | all 27 stable engineering/productivity skills, including grilling and other workflow dependencies | `claude-code`, `codex` |

```nix
agent-camp.skills.mattpocock-skills.skills = [ "grill-me" "to-spec" ];       # fewer
agent-camp.skills.mattpocock-skills.agents = [ "claude-code" "codex" "kimi-code-cli" ];  # the skills CLI's agent IDs
agent-camp.skills.mattpocock-skills.enable = false;                          # none
```

Reusable skills (grilling, tdd, domain-modeling, …) are included so workflow
entry points can run. These model-invoked skills appear in every session's skill
list. The Vercel skills CLI installs the pinned upstream files unchanged.

**What nix owns, and what you may change locally.**

- A switch runs `skills add` for a source only when its pin, skill list or
  agent list changed (last applied: `~/.local/state/agent-camp/skills/<name>`).
  Between those changes the installed copies are yours to override.
- The copies are read-only on purpose: they are nix's state. To change one,
  take it over instead of editing in place: `bunx skills add <owner/repo> -g -s <skill>`
  from GitHub (then `bunx skills update -g` works for it), or
  `bunx skills remove -g <skill>` and install your own.
- The next nix change to that source (a bump, or an edit to its options)
  adds the source again and **overwrites your takeover** with the pinned
  version. Take it out of `agent-camp.skills.<name>.skills` to keep yours.
- Skills a store path put there that are no longer listed are removed.
  Skills from any other source (the lock file's `source` is not `/nix/store/…`)
  are never touched.

**Per-source views, for a harness that takes a whole directory.** Each switch
rebuilds `~/.local/share/agent-camp/skills/<name>/`: symlinks to just that
source's skills in `~/.agents/skills`. It is derived, never edited, and
deleted with no loss. Hermes reads no other agent's directory and each
profile is its own home, so a profile (the default one included) opts in
through its `config.yaml`:

```yaml
skills:
  external_dirs: ["~/.local/share/agent-camp/skills/mattpocock-skills"]
```

## Using it

```nix
inputs.agent-camp = {
  url = "github:ajchemist/agent-camp";
  # one pin for every flake: point these at your own inputs
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
  inputs.nix-darwin.follows = "nix-darwin";
};

# in a Home Manager configuration
imports = [ agent-camp.homeModules.default ];
agent-camp.herdr.enable = true;
agent-camp.harnesses.claude = { enable = true; acp = true; };  # optional: force instead of asking
```

In the downstream's apps:

- `${agent-camp.lib.ask { inherit pkgs; }}/bin/agent-camp-ask` before the build.
- `${agent-camp.lib.plan { inherit pkgs; harnesses = …; herdr = …; }}/bin/agent-camp-plan`
  for read-only status rows. Pass it the same settings as the module.

Evaluate the home with `--impure` so the module can read the answer file. Only
nixpkgs-installed harnesses (goose) need it at evaluation time.

## Superseded copies

Whatever the module installs replaces what another installer left on the
host. On switch it removes: a hand-installed `~/.bun/bin/bun`, `~/.nvm`, fnm's
old macOS root, hermes' node shims, uv's standalone binaries, global npm
copies of the harnesses under fnm's node, Claude Code's native installer copy,
goose's download-script binary, and a hand-installed `~/.local/bin/herdr`.

## CI

`.github/workflows/ci.yml` runs on Ubuntu and macOS:

- **check**: every output evaluates. Then each system builds all of its
  checks (`checks.nix`) before anything is deployed:
  - the module in a real Home Manager / nix-darwin build (`ci/fixture.nix`,
    straight from the upstream builders);
  - shellcheck over the activation steps it generates;
  - the answer-file logic (`choice.sh`);
  - that importing the module alone installs no harness and no herdr, and
    that an unknown harness is refused;
  - what each curated agent's activation puts in each harness's user-level
    instructions and hook files;
  - the ask and plan scripts.
- **deploy**: runs only after both systems pass check. claude, codex, pi and
  goose, each with its adapter, plus herdr, are deployed onto the runner with
  `lib.ciSettings`. Every command must run, and each ACP agent must complete
  initialize (`ci/acp-initialize.py`). A second deploy must succeed, then the
  plan reads the result.

emacs-camp's CI deploys the same set and drives each adapter through
agent-shell.
