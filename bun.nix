# bun, pinned ahead of nixpkgs (data, not a module — imported by module.nix
# and the plan). nixpkgs sits weeks behind bun's releases and the agent CLIs
# (omp: `Bun runtime must be >= 1.3.14`) track the newest one, so the version
# lives here. Same prebuilt zips nixpkgs' bun unpacks, just a newer tag.
# Bump: change version, then
#   nix hash convert --hash-algo sha256 --to sri <hex from SHASUMS256.txt of the release>
{ pkgs }:
let
  version = "1.4.2";
  hashes = {
    aarch64-darwin = { asset = "bun-darwin-aarch64"; hash = "sha256-kJh6OhbX21VtiGrD1VHnttPt8KHPQ6yu1iLoZ2vh0S8="; };
    x86_64-linux = { asset = "bun-linux-x64-baseline"; hash = "sha256-xngEDxT+BEDrg503y9DOTAUaMtpygGrJfeamqra/co8="; };
  };
  h = hashes.${pkgs.stdenv.hostPlatform.system} or (throw "bun: no hash for ${pkgs.stdenv.hostPlatform.system} in bun.nix");
in
pkgs.bun.overrideAttrs (old: {
  inherit version;
  src = pkgs.fetchurl {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/${h.asset}.zip";
    inherit (h) hash;
  };
})
