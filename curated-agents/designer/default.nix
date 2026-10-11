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
  description = "Owns a product's visual design through DESIGN.md (typography, spacing, layout, motion): extracts a design language from references, writes DESIGN.md, builds it, or critiques a build against it. Delegate only when the repository's AGENTS.md has delegation rules for it.";
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
