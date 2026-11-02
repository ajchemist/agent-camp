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
in
{
  agents = {
    ponytail = import ./ponytail { inherit pkgs; };
    designer = import ./designer { inherit pkgs; };
  };

  # harness -> { default; file = name: home-relative path; render = name: agent: store file;
  #   copy = true: placed as a regular file, not a home.file symlink;
  #   replaces = { <built-in coding subagent> = its description; }: replaced by
  #   the curated agent under that name when `replaceBuiltins` is on;
  #   allow = permission rules the harness needs for any curated agent }
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
    };
    kimi = {
      default = false;
      file = name: ".agents/agents/${name}.md";
      # Kimi keeps its built-in unless the file says `override: true`.
      replaces.coder = "The default sub-agent, a general-purpose software engineering assistant that can read and write files, execute commands, search code, and land concrete changes.";
      render = name: a: pkgs.writeText "${name}.md" (frontmatter name a { } + "\${base_prompt}\n\n" + a.prompt);
    };
  };
}
