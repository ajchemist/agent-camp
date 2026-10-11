# greensock/gsap-skills, pinned by commit (no releases upstream).
# The designer curated agent reads its skills from this store path.
{ pkgs }:
let
  version = "0-unstable-2026-04-21";
in
{
  inherit version;
  src = pkgs.fetchFromGitHub {
    name = "gsap-${version}";
    owner = "greensock";
    repo = "gsap-skills";
    rev = "aed9cfd3277740755f6bfc1155c7aa645403b760";
    hash = "sha256-dAjDpjKP16Lw7sFjfaH6UjWy+2y9hPVLCO9CEaaZni4=";
  };
}
