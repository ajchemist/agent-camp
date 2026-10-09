# ponytail upstream (DietrichGebert/ponytail), pinned by the release's commit:
# the curated agent reads its skills/ from this store path. Bump with
# `ci/bump.py ponytail` (rev and hash from the latest release).
{ pkgs }:
let
  version = "5.1.0";
in
{
  inherit version;
  src = pkgs.fetchFromGitHub {
    name = "ponytail-${version}";
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "9cc65d03aa2da1db7121b912d03596409ee340b8";
    hash = "sha256-diYM3gqcEboVi7OQff/SvlE0TKAIPTJDIggX7rZWslY=";
  };
}
