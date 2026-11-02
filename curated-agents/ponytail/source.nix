# ponytail upstream (DietrichGebert/ponytail), pinned by the release's commit:
# the curated agent reads its skills/ from this store path. Bump with
# `ci/bump.py ponytail` (rev and hash from the latest release).
{ pkgs }:
let
  version = "5.3.3";
in
{
  inherit version;
  src = pkgs.fetchFromGitHub {
    name = "ponytail-${version}";
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "7801d061243d7b753bad0e0b3c057cd250b11755";
    hash = "sha256-CY0EifTY0UVc6/FPGVJjEfYEf/8QLsINQmoYYKZYh98=";
  };
}
