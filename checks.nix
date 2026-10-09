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

  # Curated agents: ponytail lands for claude and codex by default, kimi only
  # when asked, nothing when disabled; every skill path in a rendered prompt
  # is a file in the pinned upstream.
  curated =
    let
      files = c: lib.filter (f: lib.hasSuffix "/ponytail.md" f || lib.hasSuffix "/ponytail.toml" f) (lib.attrNames c.home.file);
      withKimi = homeWith [{ agent-camp.curated-agents.ponytail.harnesses.kimi = true; }];
      off = homeWith [{ agent-camp.curated-agents.ponytail.enable = false; }];
      want = [ ".claude/agents/ponytail.md" ".codex/agents/ponytail.toml" ];
    in
    assert lib.assertMsg (lib.sort (a: b: a < b) (files bare) == want) "default curated files: ${toString (files bare)}";
    assert lib.assertMsg (lib.elem ".agents/agents/ponytail.md" (files withKimi)) "kimi opt-in wrote nothing";
    assert lib.assertMsg (files off == [ ]) "disabled curated agent still installed: ${toString (files off)}";
    pkgs.runCommand "agent-camp-curated" { } ''
      for f in ${bare.home.file.".claude/agents/ponytail.md".source} ${bare.home.file.".codex/agents/ponytail.toml".source} ${withKimi.home.file.".agents/agents/ponytail.md".source}; do
        paths=$(grep -o '/nix/store/[^ `"]*/SKILL.md' "$f" | sort -u)
        [ -n "$paths" ] || { echo "FAIL: no skill paths in $f"; exit 1; }
        for p in $paths; do [ -f "$p" ] || { echo "FAIL: $f names missing $p"; exit 1; }; done
      done
      grep -q '^\''${base_prompt}' ${withKimi.home.file.".agents/agents/ponytail.md".source} || { echo "FAIL: kimi prompt lacks base_prompt"; exit 1; }
      touch $out
    '';

  # The scripts a downstream runs (shellcheck runs as part of their build).
  ask = import ./ask.nix { inherit pkgs; };
  plan = import ./plan.nix { inherit pkgs; inherit (ciSettings.agent-camp) harnesses herdr; };
}
