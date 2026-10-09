# User-scope skill sources: upstreams pinned by nix (skill-sources/<name>/),
# laid out by the skills CLI (vercel-labs/skills), which copies each skill to
# ~/.agents/skills and symlinks it into every harness it is asked for.
{ pkgs }:
{
  # ponytail: pinned by hand, not in the briefing; bump when `skills add` changes behaviour.
  cli = "skills@1.7.1";
  sources = {
    mattpocock-skills = import ./mattpocock-skills { inherit pkgs; };
  };
}
