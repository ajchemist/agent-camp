# The ponytail curated agent: a senior engineer that loads ponytail's skills
# as plain files from the pinned upstream instead of having them installed.
{ pkgs }:
let
  upstream = import ./source.nix { inherit pkgs; };
in
{
  # Per-harness default model and effort, unset = the harness default, e.g.
  # claude = { model = "opus"; effort = "high"; }; codex = { model = "<codex model>"; effort = "high"; };
  defaults = { };
  description = "Carries out scoped code changes (implementation, bug fixes, refactoring, diff review, repo audit) as the smallest complete change, never cutting safety. Delegate only when the repository's AGENTS.md has delegation rules for it.";
  prompt = builtins.replaceStrings [ "@SKILLS@" ] [ "${upstream.src}/skills" ] (builtins.readFile ./prompt.md);
}
