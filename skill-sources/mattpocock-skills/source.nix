# mattpocock/skills, pinned by the release's commit. Bump with
# `ci/bump.py mattpocock-skills` (rev and hash from the latest release).
{ pkgs }:
let
  version = "1.3.1";
in
{
  inherit version;
  src = pkgs.fetchFromGitHub {
    name = "mattpocock-skills-${version}";
    owner = "mattpocock";
    repo = "skills";
    rev = "24fe0ef7737efae15c87225755e9f6f5965e4888";
    hash = "sha256-/mAmj7QFdyOWhLmy3Rt2/Hfsh5qwirTRax7hmQffFdo=";
  };
}
