#!/usr/bin/env bash
# Install agent-camp on the CI runner the way a downstream would: a plain
# Home Manager / nix-darwin configuration (ci/fixture.nix) plus this module
# with lib.ciSettings (claude, codex, pi, goose, each with its ACP adapter, and
# herdr), for the runner's user. Then check that every one of them runs.
# Exports AGENT_CAMP_PATH for later steps.
#   Linux: Home Manager -> activate it.
#   macOS: nix-darwin with Home Manager -> activate it (sudo).
set -euo pipefail
user="$(id -un)"
flake="${AGENT_CAMP_FLAKE:-$(pwd)}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
t0=$SECONDS

case "$(uname -s)" in
  Linux)
    out="$(nix build --impure --no-link --print-out-paths --expr "
      let f = builtins.getFlake \"path:$flake\"; x = import $flake/ci/fixture.nix { inherit (f.inputs) nixpkgs home-manager nix-darwin; }; in
      (x.home {
        user = \"$user\"; homeDirectory = \"$HOME\";
        modules = [ f.homeModules.default f.lib.ciSettings ];
      }).activationPackage")"
    "$out/activate"
    ;;
  Darwin)
    top="$(nix build --impure --no-link --print-out-paths --expr "
      let f = builtins.getFlake \"path:$flake\"; x = import $flake/ci/fixture.nix { inherit (f.inputs) nixpkgs home-manager nix-darwin; }; in
      (x.darwin {
        user = \"$user\";
        modules = [ { home-manager.sharedModules = [ f.homeModules.default f.lib.ciSettings ]; } ];
      }).system")"
    for f in /etc/bashrc /etc/zshrc /etc/zshenv; do
      if [ -f "$f" ] && [ ! -L "$f" ]; then sudo mv "$f" "$f.before-nix-darwin"; fi
    done
    sudo -H nix-env --profile /nix/var/nix/profiles/system --set "$top"
    sudo -H "$top/activate"
    ;;
esac
deployed=$((SECONDS - t0))

p="$HOME/.bun/bin:$HOME/.local/share/fnm/aliases/default/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$user/bin:$PATH"
echo "AGENT_CAMP_PATH=$p" >> "${GITHUB_ENV:-/dev/null}"
{
  echo "### deploy ($(uname -s)): $deployed s"
  echo "| command | version |"; echo "|---|---|"
} >> "$summary"
fail=0
# Adapters have no --version of their own; their package.json says it.
for c in claude codex pi goose herdr claude-agent-acp codex-acp pi-acp; do
  if ! PATH="$p" command -v "$c" >/dev/null; then
    echo "::error::$c not on PATH after deploy"; fail=1; continue
  fi
  case "$c" in
    *-acp) v="$(realpath "$(PATH="$p" command -v "$c")")" ;;
    *) v="$(PATH="$p" "$c" --version 2>&1 | head -1)" || { echo "::error::$c --version failed: $v"; fail=1; } ;;
  esac
  echo "| $c | $v |" >> "$summary"
done
exit "$fail"
