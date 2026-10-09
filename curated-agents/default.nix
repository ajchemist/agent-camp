# Curated agents: subagent profiles agent-camp ships. Each one is a single
# source (curated-agents/<name>/default.nix: description + prompt), rendered
# per harness by the adapters below into that harness's user-level agent dir.
#
# The prompt lands differently per harness: Claude Code and Kimi Code replace
# their default system prompt with it (Kimi gets `${base_prompt}` back in
# front), Codex adds it on top as developer instructions. pi has no built-in
# subagents, so it has no adapter yet.
{ pkgs }:
let
  inherit (pkgs) lib;
  frontmatter = name: a: "---\nname: ${name}\ndescription: ${builtins.toJSON a.description}\n---\n\n";
in
{
  agents = {
    ponytail = import ./ponytail { inherit pkgs; };
  };

  # harness -> { default; file = name: home-relative path; render = name: agent: home.file entry }
  adapters = {
    claude = {
      default = true;
      file = name: ".claude/agents/${name}.md";
      render = name: a: { text = frontmatter name a + a.prompt; };
    };
    codex = {
      default = true;
      file = name: ".codex/agents/${name}.toml";
      render = name: a: {
        source = (pkgs.formats.toml { }).generate "${name}.toml" {
          inherit name;
          inherit (a) description;
          developer_instructions = a.prompt;
        };
      };
    };
    kimi = {
      default = false;
      file = name: ".agents/agents/${name}.md";
      render = name: a: { text = frontmatter name a + "\${base_prompt}\n\n" + a.prompt; };
    };
  };
}
