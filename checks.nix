# Everything that would otherwise first fail on a deploy host, checked at
# build time: the activation shell, the answer-file logic, what the module
# installs by default, and the downstream scripts. `nix flake check` runs
# these on each system before CI deploys anything.
{ pkgs, mkHome, module, ciSettings }:

let
  inherit (pkgs) lib;
  homeWith = modules: (mkHome ([ module ] ++ modules)).config;
  bare = homeWith [ ];
  ci = homeWith [ ciSettings ];
  # The CI set has no plugins; give the lint one so that path is checked too.
  withPlugin = homeWith [ ciSettings { agent-camp.herdr.plugins = [{ id = "p"; repo = "owner/repo"; rev = "0000000"; }]; } ];
  names = c: map (p: p.pname or p.name) c.home.packages;

  # Each agent-camp activation step as the switch runs it, with HM's `run`
  # (dry-run aware wrapper) stubbed, so shellcheck sees the generated shell.
  steps = [ "fnmNode" "runtimeLeftovers" "agentClis" "herdrLocalCopy" "herdrPlugins" "herdrIntegrations" ];
  activationScript = c: pkgs.writeText "agent-camp-activation.sh" (''
    #!/usr/bin/env bash
    set -eu
    run() { "$@"; }
  '' + lib.concatMapStringsSep "\n" (n: c.home.activation.${n}.data)
    (lib.filter (n: c.home.activation ? ${n}) steps));
in
{
  # Generated activation shell parses and lints, with and without the CI set.
  activation-shellcheck = pkgs.runCommand "agent-camp-activation-shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
    shellcheck -s bash -S warning ${activationScript bare}
    shellcheck -s bash -S warning ${activationScript withPlugin}
    touch $out
  '';

  # choice.sh: no file, the pre-rename file, yes/no, last answer wins, a forced option wins.
  choice = pkgs.runCommand "agent-camp-choice" { } ''
    export HOME=$PWD
    . ${./choice.sh}
    t() { [ "$1" = "$2" ] || { echo "FAIL: $3: got '$1', want '$2'"; exit 1; }; }
    t "$(decide claude "")" "" "no answer file"
    mkdir -p .config/agent-camp
    echo pi=yes > .config/agent-camp/agents
    t "$(decide pi "")" yes "pre-rename answer file read while harnesses is missing"
    printf 'claude=yes\ncodex=no\nclaude-acp=yes\nclaude=no\n' > .config/agent-camp/harnesses
    t "$(decide claude "")" no "last answer wins"
    t "$(decide codex "")" no "no"
    t "$(decide claude-acp "")" yes "acp key is its own"
    t "$(decide pi "")" "" "unanswered"
    t "$(decide codex yes)" yes "forced option wins"
    touch $out
  '';

  # Importing the module alone installs the runtime and no agent or herdr;
  # the CI set brings goose (nixpkgs) and herdr; an unknown agent is refused.
  defaults =
    let
      bareNames = names bare;
      ciNames = names ci;
      # Home Manager throws on a failed assertion; tryEval sees that.
      renamed = (homeWith [{ agent-camp.agents.goose.enable = true; }]).agent-camp.harnesses.goose.enable;
      refused = !(builtins.tryEval (mkHome [ module { agent-camp.harnesses.nope.enable = true; } ]).activationPackage.drvPath).success;
    in
    assert lib.assertMsg (lib.all (n: lib.elem n bareNames) [ "bun" "fnm" "uv" ]) "runtime missing: ${toString bareNames}";
    assert lib.assertMsg (!lib.elem "goose-cli" bareNames && !lib.elem "herdr" bareNames) "installed without a yes: ${toString bareNames}";
    assert lib.assertMsg (!(bare.home.activation ? herdrPlugins)) "herdr steps without herdr.enable";
    assert lib.assertMsg (lib.elem "goose-cli" ciNames && lib.elem "herdr" ciNames) "CI set incomplete: ${toString ciNames}";
    assert lib.assertMsg refused "unknown harness accepted";
    assert lib.assertMsg renamed "agent-camp.agents no longer reaches agent-camp.harnesses";
    pkgs.runCommand "agent-camp-defaults" { } "touch $out";

  # The scripts a downstream runs (shellcheck runs as part of their build).
  ask = import ./ask.nix { inherit pkgs; };
  plan = import ./plan.nix { inherit pkgs; inherit (ciSettings.agent-camp) harnesses herdr; };
}
