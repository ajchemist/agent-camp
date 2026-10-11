# pbakaus/impeccable, pinned by the skill-v4.5.2 release's commit.
# The designer curated agent reads its skills from this store path.
{ pkgs }:
let
  version = "4.5.2";
in
{
  inherit version;
  src = pkgs.fetchFromGitHub {
    name = "impeccable-${version}";
    owner = "pbakaus";
    repo = "impeccable";
    rev = "d631a8827f99414d2b6daba4ef08b7f8701751d7";
    hash = "sha256-0QpNzNnSon34/VVPPaitnSTBjpu9qJGXJzCJctS4gM0=";
  };
}
