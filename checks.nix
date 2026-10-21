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
  steps = [ "fnmNode" "runtimeLeftovers" "agentClis" "userSkills" "curatedAgentCopies" "curatedClaudePermissions" "herdrLocalCopy" "herdrPlugins" "herdrIntegrations" ];
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

  # choice.sh: no file, yes/no, last answer wins, a forced option wins.
  choice = pkgs.runCommand "agent-camp-choice" { } ''
    export HOME=$PWD
    . ${./choice.sh}
    t() { [ "$1" = "$2" ] || { echo "FAIL: $3: got '$1', want '$2'"; exit 1; }; }
    t "$(decide claude "")" "" "no answer file"
    mkdir -p .config/agent-camp
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
      refused = !(builtins.tryEval (mkHome [ module { agent-camp.harnesses.nope.enable = true; } ]).activationPackage.drvPath).success;
    in
    assert lib.assertMsg (lib.all (n: lib.elem n bareNames) [ "bun" "fnm" "uv" ]) "runtime missing: ${toString bareNames}";
    assert lib.assertMsg (!lib.elem "goose-cli" bareNames && !lib.elem "herdr" bareNames) "installed without a yes: ${toString bareNames}";
    assert lib.assertMsg (!(bare.home.activation ? herdrPlugins)) "herdr steps without herdr.enable";
    assert lib.assertMsg (lib.elem "goose-cli" ciNames && lib.elem "herdr" ciNames) "CI set incomplete: ${toString ciNames}";
    assert lib.assertMsg refused "unknown harness accepted";
    pkgs.runCommand "agent-camp-defaults" { } "touch $out";

  # Curated agents: ponytail lands for claude and codex by default, kimi only
  # when asked, nothing when disabled; kimi's built-in coder is replaced only
  # with replaceBuiltins; every skill path in a rendered prompt
  # is a file in the pinned upstream.
  curated =
    let
      all = [ ".agents/agents/ponytail.md" ".claude/agents/ponytail.md" ".codex/agents/ponytail.toml" ];
      # Linked through home.file, or copied by the curatedAgentCopies step.
      files = c: lib.filter (f: c.home.file ? ${f} || lib.hasInfix "\"$HOME/${f}\"" c.home.activation.curatedAgentCopies.data) all;
      curated = import ./curated-agents { inherit pkgs; };
      rendered = lib.mapAttrsToList (_: ad: ad.render "ponytail" curated.agents.ponytail) curated.adapters;
      withKimi = homeWith [{ agent-camp.curated-agents.ponytail.harnesses.kimi = true; }];
      off = homeWith [{ agent-camp.curated-agents.ponytail.enable = false; }];
      kimiCoder = homeWith [{ agent-camp.curated-agents.ponytail = { harnesses.kimi = true; replaceBuiltins = true; }; }];
      want = [ ".claude/agents/ponytail.md" ".codex/agents/ponytail.toml" ];
    in
    assert lib.assertMsg (files bare == want) "default curated files: ${toString (files bare)}";
    assert lib.assertMsg (!(bare.home.file ? ".codex/agents/ponytail.toml")) "codex agent is a symlink again (codex skips those)";
    assert lib.assertMsg (lib.elem ".agents/agents/ponytail.md" (files withKimi)) "kimi opt-in wrote nothing";
    assert lib.assertMsg (files off == [ ]) "disabled curated agent still installed: ${toString (files off)}";
    assert lib.assertMsg (!(withKimi.home.file ? ".agents/agents/coder.md")) "kimi coder replaced without replaceBuiltins";
    pkgs.runCommand "agent-camp-curated" { } ''
      for f in ${toString rendered}; do
        paths=$(grep -o '/nix/store/[^ `"]*/SKILL.md' "$f" | sort -u)
        [ -n "$paths" ] || { echo "FAIL: no skill paths in $f"; exit 1; }
        for p in $paths; do [ -f "$p" ] || { echo "FAIL: $f names missing $p"; exit 1; }; done
      done
      grep -q '^\''${base_prompt}' ${withKimi.home.file.".agents/agents/ponytail.md".source} || { echo "FAIL: kimi prompt lacks base_prompt"; exit 1; }
      f=${kimiCoder.home.file.".agents/agents/coder.md".source}
      grep -q '^name: coder$' "$f" && grep -q '^override: true$' "$f" && grep -q '^\''${base_prompt}' "$f" || { echo "FAIL: kimi coder override malformed"; exit 1; }

      # Claude read rules: added next to the user's own, each naming a real
      # directory; gone when disabled, the user's rules and keys kept.
      export HOME=$PWD
      run() { "$@"; }
      mkdir -p .claude && echo '{"permissions":{"allow":["mine"]},"x":1}' > .claude/settings.json
      ${bare.home.activation.curatedClaudePermissions.data}
      ${pkgs.jq}/bin/jq -e '.x == 1 and .permissions.allow[0] == "mine" and (.permissions.allow | length) == 2' .claude/settings.json >/dev/null || { echo "FAIL: rule not added beside the user's"; cat .claude/settings.json; exit 1; }
      d=$(${pkgs.jq}/bin/jq -r '.permissions.allow[1] | capture("^Read\\(/(?<p>.*)/\\*\\*\\)$").p' .claude/settings.json)
      [ -d "$d" ] || { echo "FAIL: rule names missing $d"; exit 1; }
      ${off.home.activation.curatedClaudePermissions.data}
      ${pkgs.jq}/bin/jq -e '.permissions.allow == ["mine"]' .claude/settings.json >/dev/null || { echo "FAIL: disable left rules behind"; cat .claude/settings.json; exit 1; }
      touch $out
    '';

  # User-scope skills: stable workflows and their reusable dependencies exist
  # in the pinned upstream source; disabling a source
  # leaves no `skills add` for it.
  skills =
    let
      sources = (import ./skill-sources { inherit pkgs; }).sources;
      off = homeWith [{ agent-camp.skills.mattpocock-skills.enable = false; }];
      adds = c: lib.hasInfix "skills_cli add" c.home.activation.userSkills.data;
      views = c: lib.hasInfix ''$views/mattpocock-skills"'' c.home.activation.userSkills.data;
    in
    assert lib.assertMsg (lib.all (k: lib.elem k sources.mattpocock-skills.skills)
      [ "grill-me" "grilling" "domain-modeling" "tdd" "research" "prototype" ]) "workflow dependencies missing";
    assert lib.assertMsg (adds bare) "default skills not added";
    assert lib.assertMsg (!adds off) "disabled skill source still added";
    assert lib.assertMsg (views bare) "no view for a wanted skill source";
    assert lib.assertMsg (!views off) "view for a disabled skill source";
    pkgs.runCommand "agent-camp-skills" { } ''
      ${lib.concatStrings (lib.mapAttrsToList (n: src: lib.concatMapStrings (k: ''
        f=$(find ${src.src} -path "*/${k}/SKILL.md" | head -1)
        [ -n "$f" ] || { echo "FAIL: ${n}: no ${k}/SKILL.md"; exit 1; }
      '') src.skills) sources)}
      ${lib.concatStrings (lib.mapAttrsToList (n: src: ''
        for category in engineering productivity; do
          for f in ${src.src}/skills/$category/*/SKILL.md; do
            k=$(basename "$(dirname "$f")")
            case " ${lib.concatStringsSep " " src.skills} " in
              *" $k "*) ;;
              *) echo "FAIL: ${n}: stable skill $k omitted from defaults"; exit 1 ;;
            esac
          done
        done
      '') sources)}
      touch $out
    '';

  # The scripts a downstream runs (shellcheck runs as part of their build).
  ask = import ./ask.nix { inherit pkgs; };
  plan = import ./plan.nix { inherit pkgs; inherit (ciSettings.agent-camp) harnesses herdr; };
}
