# herdr: upstream release binary, pinned. nixpkgs' pkgs.herdr lags (0.9.0) and
# overriding its version means a from-source build (rust + zig + llvm, GiBs of
# downloads on every machine) because nothing is in the binary cache.
# Bump: change version, then `nix store prefetch-file <url>` for each hash.
{ pkgs }:
let
  inherit (pkgs) lib stdenvNoCC fetchurl;
  version = "0.9.5";
  bins = {
    aarch64-darwin = { asset = "herdr-macos-aarch64"; hash = "sha256-+3fCIyoFqANUITgsiUOS9BdOTjihjkivPdApAVfDp+I="; };
    x86_64-linux = { asset = "herdr-linux-x86_64"; hash = "sha256-FNnovItKngEY13wyJm921GHwm0A0LrI3UpYL2J9Zkp0="; };
  };
  bin = bins.${stdenvNoCC.hostPlatform.system}
    or (throw "herdr: no release binary for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "herdr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${version}/${bin.asset}";
    inherit (bin) hash;
  };

  dontUnpack = true;
  # Linux release is static-pie; macOS is a plain Mach-O. Nothing to patch.
  dontFixup = true;

  installPhase = ''
    install -Dm755 "$src" "$out/bin/herdr"
  '';

  meta = {
    description = "Agent multiplexer that lives in your terminal";
    homepage = "https://herdr.dev";
    mainProgram = "herdr";
    platforms = builtins.attrNames bins;
  };
}
