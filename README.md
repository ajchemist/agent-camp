# agent-camp

English · [한국어](README.ko.md)

agent-camp installs coding-agent CLIs, their ACP adapters, and
[herdr](https://herdr.dev) through a Home Manager module on top of
[nix-basecamp](https://github.com/ajchemist/nix-basecamp). It installs nothing
you did not say yes to.

```
nix-basecamp   nixpkgs, Home Manager / nix-darwin builders
agent-camp     agent CLIs + ACP adapters + herdr, and the bun/fnm/uv they need
emacs-camp     agent-shell talks to the adapters (CI uses agent-camp)
your flake     which agents, herdr config, agent config files
```

## Agents

| bin | installed with | ACP adapter (`<bin>-acp`) | herdr hook |
|---|---|---|---|
| claude | `bun add -g @anthropic-ai/claude-code` | `claude-agent-acp` | yes |
| codex | `bun add -g @openai/codex` | `codex-acp` | yes |
| pi | `bun add -g @earendil-works/pi-coding-agent` | `pi-acp` | yes |
| omp | `bun add -g @oh-my-pi/pi-coding-agent` | none | yes |
| goose | nixpkgs `goose-cli` | built in (`goose acp`) | no |
| kimi | `uv tool install kimi-cli` | built in (`kimi acp`) | yes |
| hermes | by hand | none | yes |

The agents release almost daily, so nothing is pinned: every switch runs
`<pkg>@latest`, which is a no-op when current. ACP adapters are what editors
use to talk to an agent (Emacs' agent-shell, Zed); they are separate packages
and separate answers.

## What gets installed

Importing the module installs bun (pinned ahead of nixpkgs), fnm with one LTS
node, and uv. Each agent and each adapter is then decided per host:

1. A Nix option, if the downstream set one:
   `agent-camp.agents.<bin>.enable` and `agent-camp.agents.<bin>.acp`
   (`true`/`false`).
2. Otherwise the host's answer in `~/.config/agent-camp/agents`
   (`claude=yes`, `claude-acp=no`, one per line).
3. No answer: not installed.

The answers come from `agent-camp-ask` (`lib.ask`), a checklist that a
downstream `nix run` app runs before its build. It shows only undecided items,
with nothing preselected. Unticked items are recorded as `no`. Without a
terminal it asks nothing and records nothing, so a non-interactive run
installs only what the options force.

herdr is opt-in: `agent-camp.herdr.enable = true` installs its release binary,
the plugins listed in `agent-camp.herdr.plugins` (pinned by commit), and an
integration hook for every installed agent that has one, so a restarted herdr
server resumes each agent's session. herdr's own `config.toml` stays with the
downstream.

## Using it

```nix
inputs.agent-camp = {
  url = "github:ajchemist/agent-camp";
  inputs.basecamp.follows = "basecamp";
};

# in a Home Manager configuration
imports = [ agent-camp.homeModules.default ];
agent-camp.herdr.enable = true;
agent-camp.agents.claude = { enable = true; acp = true; };  # optional: force instead of asking
```

In the downstream's apps:

- `${agent-camp.lib.ask { inherit pkgs; }}/bin/agent-camp-ask` before the build.
- `${agent-camp.lib.plan { inherit pkgs; agents = …; herdr = …; }}/bin/agent-camp-plan`
  for read-only status rows. Pass it the same settings as the module.

Evaluate the home with `--impure` so the module can read the answer file. Only
nixpkgs-installed agents (goose) need it at evaluation time.

## Superseded copies

Whatever the module installs replaces what another installer left on the
host. On switch it removes: a hand-installed `~/.bun/bin/bun`, `~/.nvm`, fnm's
old macOS root, hermes' node shims, uv's standalone binaries, global npm
copies of the agents under fnm's node, Claude Code's native installer copy,
goose's download-script binary, and a hand-installed `~/.local/bin/herdr`.

## CI

`.github/workflows/ci.yml` runs on Ubuntu and macOS:

- **check**: every output evaluates. Then each system builds all of its
  checks (`checks.nix`) before anything is deployed:
  - the module in a real Home Manager / nix-darwin build;
  - shellcheck over the activation steps it generates;
  - the answer-file logic (`choice.sh`);
  - that importing the module alone installs no agent and no herdr, and
    that an unknown agent is refused;
  - the ask and plan scripts.
- **deploy**: runs only after both systems pass check. claude, codex, pi and
  goose, each with its adapter, plus herdr, are deployed onto the runner with
  `lib.ciSettings`. Every command must run, and each ACP agent must complete
  initialize (`ci/acp-initialize.py`). A second deploy must succeed, then the
  plan reads the result.

emacs-camp's CI deploys the same set and drives each adapter through
agent-shell.
