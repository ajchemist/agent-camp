# Curated agents: subagent profiles agent-camp ships. Each one is a single
# source (curated-agents/<name>/default.nix: description + prompt), rendered
# per harness by the adapters below into that harness's user-level agent dir.
#
# The prompt lands differently per harness: Claude Code and Kimi Code replace
# their default system prompt with it (Kimi gets `${base_prompt}` back in
# front), Codex adds it on top as developer instructions. pi has no built-in
# subagents, so it has no adapter yet.
#
# `defaults.<harness> = { model; effort; }` in a definition is that harness's
# default model and reasoning effort for the agent; unset keys are left out of
# the rendered file, so the harness picks as it would without them.
{ pkgs }:
let
  inherit (pkgs) lib;
  # The set keys of a harness's defaults, renamed to that harness's own field names.
  defaults = h: names: a: lib.mapAttrs' (k: v: lib.nameValuePair names.${k} v)
    (lib.filterAttrs (_: v: v != null) (a.defaults.${h} or { }));
  frontmatter = name: a: extra: "---\nname: ${name}\ndescription: ${builtins.toJSON a.description}\n"
    + lib.concatStrings (lib.mapAttrsToList (k: v: "${k}: ${v}\n") extra)
    + lib.optionalString (a.override or false) "override: true\n" + "---\n\n";
  agents = {
    ponytail = import ./ponytail { inherit pkgs; };
    designer = import ./designer { inherit pkgs; };
  };
in
{
  inherit agents;

  # The user-level instructions for the installed agents, given as
  # { <name> = <activation>; }: each agent's delegation rules, whose first rule
  # reads the activation from the line naming it here.
  instructions = activations: "# Curated agents\n\nagent-camp installed these subagents: "
    + lib.concatStringsSep ", " (lib.mapAttrsToList (n: v: "${n} `${v}`") activations)
    + ". Each section's first rule says where it applies.\n\n"
    + lib.concatMapStringsSep "\n" (n: agents.${n}.delegation) (lib.attrNames activations);

  # harness -> { default; file = name: home-relative path; render = name: agent: store file;
  #   copy = true: placed as a regular file, not a home.file symlink;
  #   replaces = { <built-in coding subagent> = its description; }: replaced by
  #   the curated agent under that name when `replaceBuiltins` is on;
  #   allow = permission rules the harness needs for any curated agent;
  #   instructions = home-relative file the installed agents' delegation rules
  #   go to (none: the harness has no user-level instructions file);
  #   instructionsShared = true: the user owns that file, so the rules go in a
  #   marked block the module rewrites, not a file of their own;
  #   hooks = the JSON file whose `hooks.SessionStart` takes the session hook
  #   (none: no hook that can add context at session start) }
  adapters = {
    claude = {
      default = true;
      file = name: ".claude/agents/${name}.md";
      # Agent frontmatter takes `model` and `effort` (code.claude.com/docs/en/sub-agents).
      render = name: a: pkgs.writeText "${name}.md" (frontmatter name a (defaults "claude" { model = "model"; effort = "effort"; } a) + a.prompt);
      # Claude Code asks before reading outside the workspace, and a headless
      # run (`claude -p`) is refused outright, so the agent would work without
      # its skills. The whole store: it is read-only, and the skill paths move
      # with every bump. Merged into ~/.claude/settings.json by the module.
      allow = [ "Read(//nix/store/**)" ];
      # User-level rules load in every session like ~/.claude/CLAUDE.md, which
      # stays the user's (code.claude.com/docs/en/memory#user-level-rules).
      instructions = ".claude/rules/agent-camp-curated-agents.md";
      # SessionStart stdout becomes context; merged like `allow`.
      hooks = ".claude/settings.json";
    };
    codex = {
      default = true;
      file = name: ".codex/agents/${name}.toml";
      # Codex skips an agent file that is a symlink ("agent type is currently
      # not available", codex-cli 0.160.1), so this one is copied.
      copy = true;
      render = name: a: (pkgs.formats.toml { }).generate "${name}.toml" ({
        inherit name;
        inherit (a) description;
        developer_instructions = a.prompt;
      } // defaults "codex" { model = "model"; effort = "model_reasoning_effort"; } a);
      # Codex reads one user-level file and includes nothing from it.
      instructions = ".codex/AGENTS.md";
      instructionsShared = true;
      # Plain SessionStart stdout is added as developer context
      # (learn.chatgpt.com/docs/hooks); Codex runs a hook once it is trusted.
      hooks = ".codex/hooks.json";
    };
    kimi = {
      default = false;
      file = name: ".agents/agents/${name}.md";
      # Kimi keeps its built-in unless the file says `override: true`.
      replaces.coder = "The default sub-agent, a general-purpose software engineering assistant that can read and write files, execute commands, search code, and land concrete changes.";
      render = name: a: pkgs.writeText "${name}.md" (frontmatter name a { } + "\${base_prompt}\n\n" + a.prompt);
      # No instructions or hooks: kimi-cli 1.52 reads AGENTS.md only from the
      # project (root to working dir), and drops SessionStart hook output.
    };
  };
}
