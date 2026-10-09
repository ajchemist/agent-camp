# agent-camp

English · [한국어](README.ko.md)

agent-camp installs harnesses (coding-agent CLIs), their ACP adapters, and
[herdr](https://herdr.dev) through a Home Manager module on top of
[nix-basecamp](https://github.com/ajchemist/nix-basecamp). It installs no
harness you did not say yes to. Curated agents and user-scope skills, which are
only files for the harnesses, are on by default and can be switched off.

```
nix-basecamp   nixpkgs, Home Manager / nix-darwin builders
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
   (`true`/`false`). The pre-rename `agent-camp.agents` still works, with a warning.
2. Otherwise the host's answer in `~/.config/agent-camp/harnesses`
   (`claude=yes`, `claude-acp=no`, one per line). The ask script moves a
   pre-rename `~/.config/agent-camp/agents` there once.
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
| `ponytail` | a senior engineer that reads [ponytail](https://github.com/DietrichGebert/ponytail)'s skills from a pinned store path, without installing them as skills | claude, codex |

```nix
agent-camp.curated-agents.ponytail.harnesses.kimi = true;  # also ~/.agents/agents/ponytail.md
agent-camp.curated-agents.ponytail.enable = false;         # or none at all
```

Files: claude `~/.claude/agents/<name>.md`, codex `~/.codex/agents/<name>.toml`,
kimi `~/.agents/agents/<name>.md`. pi has no built-in subagents, so it gets none yet.

## User-scope skills

Skills that are about how you work, not about one repository, live at user
scope instead of in each repository's `skills-lock.json` or plugin settings
([ADR 0004](docs/adr/0004-user-scope-skills.md)). Nix pins each source in
`skill-sources/<name>/source.nix`; the [skills CLI](https://github.com/vercel-labs/skills)
lays them out: `skills add <store path> -g -a <agent>… -s <skill>…` copies each
skill to `~/.agents/skills` and symlinks it into the other agents (with only
non-universal agents such as `claude-code`, it copies straight into theirs).

| source | default skills | default agents |
|---|---|---|
| `mattpocock-skills` ([mattpocock/skills](https://github.com/mattpocock/skills)) | the 16 user-invoked ones (`disable-model-invocation: true`): grill-me, to-spec, to-tickets, handoff, … | `claude-code`, `codex` |

```nix
agent-camp.skills.mattpocock-skills.skills = [ "grill-me" "to-spec" ];       # fewer
agent-camp.skills.mattpocock-skills.agents = [ "claude-code" "codex" "kimi-code-cli" ];  # the skills CLI's agent IDs
agent-camp.skills.mattpocock-skills.enable = false;                          # none
```

The model-invoked ones (tdd, diagnosing-bugs, code-review, …) are left out
because at user scope they sit in every session's skill list; add them to
`skills` if you want that.

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

## Using it

```nix
inputs.agent-camp = {
  url = "github:ajchemist/agent-camp";
  inputs.basecamp.follows = "basecamp";
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
  - the module in a real Home Manager / nix-darwin build;
  - shellcheck over the activation steps it generates;
  - the answer-file logic (`choice.sh`);
  - that importing the module alone installs no harness and no herdr, and
    that an unknown harness is refused;
  - the ask and plan scripts.
- **deploy**: runs only after both systems pass check. claude, codex, pi and
  goose, each with its adapter, plus herdr, are deployed onto the runner with
  `lib.ciSettings`. Every command must run, and each ACP agent must complete
  initialize (`ci/acp-initialize.py`). A second deploy must succeed, then the
  plan reads the result.

emacs-camp's CI deploys the same set and drives each adapter through
agent-shell.
