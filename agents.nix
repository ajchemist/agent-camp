# The agents agent-camp knows (data, imported by module.nix, the ask script and
# the plan). Each releases most days, so nothing is pinned: nixpkgs lags and a
# pinned version would be stale the day after. Installed from the agent's own
# registry, `<pkg>@latest` on every switch (a no-op when current).
#
#   bin          command name
#   pkg / via    `bun add -g <pkg>` (npm), `uv tool install <pkg>` (PyPI), or
#                pkgs.<pkg> (nix: no registry of its own; follows flake.lock);
#                pkg = null: agent-camp cannot install it, only its herdr hook
#   integration  `herdr integration install <target>` once bin exists, so a
#                restarted herdr resumes the agent's session; null = no target
#   acp          ACP adapter (how editors such as Emacs' agent-shell talk to
#                the agent), installed with `bun add -g`; null = none needed
#                (goose and kimi speak ACP themselves: `goose acp`, `kimi acp`);
#                acp.was: earlier package names of the same bin, removed once
#                the current one is in (both linking one bin, the last
#                `bun add` wins)
[
  { bin = "claude"; pkg = "@anthropic-ai/claude-code"; via = "bun"; integration = "claude";
    acp = { bin = "claude-agent-acp"; pkg = "@agentclientprotocol/claude-agent-acp"; }; }
  { bin = "codex"; pkg = "@openai/codex"; via = "bun"; integration = "codex";
    acp = { bin = "codex-acp"; pkg = "@agentclientprotocol/codex-acp"; was = [ "@zed-industries/codex-acp" ]; }; }
  { bin = "pi"; pkg = "@earendil-works/pi-coding-agent"; via = "bun"; integration = "pi";
    acp = { bin = "pi-acp"; pkg = "pi-acp"; }; }
  { bin = "omp"; pkg = "@oh-my-pi/pi-coding-agent"; via = "bun"; integration = "omp"; acp = null; }
  # goose ships release binaries only (no npm/PyPI); nixpkgs has it cached.
  { bin = "goose"; pkg = "goose-cli"; via = "nix"; integration = null; acp = null; }
  # Kimi Code CLI is PyPI only (the npm `kimi-cli` is an unrelated package).
  { bin = "kimi"; pkg = "kimi-cli"; via = "uv"; integration = "kimi"; acp = null; }
  # hermes is a venv install; agent-camp installs its herdr hook once it is there.
  { bin = "hermes"; pkg = null; via = null; integration = "hermes"; acp = null; }
]
