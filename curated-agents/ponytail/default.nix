# The ponytail curated agent: a senior engineer that loads ponytail's skills
# as plain files from the pinned upstream instead of having them installed.
{ pkgs }:
let
  upstream = import ./source.nix { inherit pkgs; };
in
{
  description = "Senior engineer for implementation, fixes, refactors and code review. Delegate coding work that should land as the smallest complete change.";
  prompt = builtins.replaceStrings [ "@SKILLS@" ] [ "${upstream.src}/skills" ] (builtins.readFile ./prompt.md);
}
