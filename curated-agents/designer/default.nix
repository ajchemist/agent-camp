# The designer curated agent: one agent for a product's visual design
# (typography, spacing, layout, motion) through DESIGN.md. It routes itself
# between modes and skills; the main agent picks the mode and the instance
# (see delegation.md). Skills come from four pinned upstreams plus this
# directory's own skills/, all read as plain files.
{ pkgs }:
let
  src = name: (import ./sources/${name}.nix { inherit pkgs; }).src;
in
{
  # Per-harness default model and effort, unset = the harness default, e.g.
  # claude = { model = "opus"; effort = "high"; }; codex = { model = "<codex model>"; effort = "high"; };
  defaults = { };
  # The module's activation default: "global", "opt-in" or "off".
  activation = "global";
  delegation = builtins.readFile ./delegation.md;
  description = "Owns a product's visual design through DESIGN.md (typography, spacing, layout, motion): extracts a design language from references, writes DESIGN.md, builds it, or critiques a build against it. Delegate design work by its delegation rules in your instructions, unless they are switched off.";
  prompt = builtins.replaceStrings
    [ "@EMIL@" "@IMPECCABLE@" "@TASTE@" "@GSAP@" "@OWN@" ]
    [
      "${src "emil"}/skills"
      "${src "impeccable"}/plugin/skills/impeccable"
      "${src "taste"}/skills"
      "${src "gsap"}/skills"
      "${./skills}"
    ]
    (builtins.readFile ./prompt.md);
}
