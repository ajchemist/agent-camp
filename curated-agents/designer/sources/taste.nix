# Leonxlnx/taste-skill, pinned by commit (no releases upstream).
# The designer curated agent reads its skills from this store path.
{ pkgs }:
let
  version = "0-unstable-2026-10-09";
in
{
  inherit version;
  src = pkgs.fetchFromGitHub {
    name = "taste-${version}";
    owner = "Leonxlnx";
    repo = "taste-skill";
    rev = "717446e07a78d4e6d7918b1fde1a263378eebac9";
    hash = "sha256-IOK0JfY1DtWLs9QZbvBTf1WlnR3BgySlBxMe/QJ4iRM=";
  };
}
