# emilkowalski/skills, pinned by commit (no releases upstream).
# The designer curated agent reads its skills from this store path.
{ pkgs }:
let
  version = "0-unstable-2026-10-02";
in
{
  inherit version;
  src = pkgs.fetchFromGitHub {
    name = "emil-${version}";
    owner = "emilkowalski";
    repo = "skills";
    rev = "e8a175de22ae1e49370fc144c1f3bb9aeedf988d";
    hash = "sha256-FG1zm/Vr00QAvpSA6uuVbPJrOjFj2W+F1SAChlJOGMk=";
  };
}
