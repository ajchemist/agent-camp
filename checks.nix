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
  steps = [ "fnmNode" "runtimeLeftovers" "agentClis" "userSkills" "curatedAgentCopies" "curatedInstructions" "curatedSettings" "herdrLocalCopy" "herdrPlugins" "herdrIntegrations" ];
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

  # Curated agents: each lands for claude and codex by default, kimi only
  # when asked, nothing when disabled; kimi's built-in coder is replaced only
  # with replaceBuiltins; every store file a rendered prompt names exists
  # (skills and their playbooks, in the pinned upstreams or the agent's own).
  curated =
    let
      curated = import ./curated-agents { inherit pkgs; };
      names = lib.attrNames curated.agents;
      all = n: [ ".agents/agents/${n}.md" ".claude/agents/${n}.md" ".codex/agents/${n}.toml" ];
      # Linked through home.file, or copied by the curatedAgentCopies step.
      files = c: n: lib.filter (f: c.home.file ? ${f} || lib.hasInfix "\"$HOME/${f}\"" c.home.activation.curatedAgentCopies.data) (all n);
      rendered = lib.concatMap (n: lib.mapAttrsToList (_: ad: ad.render n curated.agents.${n}) curated.adapters) names;
      withKimi = homeWith [{ agent-camp.curated-agents.ponytail.harnesses.kimi = true; }];
      off = homeWith [{ agent-camp.curated-agents = lib.genAttrs names (_: { enable = false; }); }];
      kimiCoder = homeWith [{ agent-camp.curated-agents.ponytail = { harnesses.kimi = true; replaceBuiltins = true; }; }];
      twoReplacers = !(builtins.tryEval (mkHome [ module { agent-camp.curated-agents = lib.genAttrs names (_: { replaceBuiltins = true; }); } ]).activationPackage.drvPath).success;
    in
    assert lib.all (n: lib.assertMsg (files bare n == [ ".claude/agents/${n}.md" ".codex/agents/${n}.toml" ])
      "default curated files for ${n}: ${toString (files bare n)}") names;
    assert lib.all (n: lib.assertMsg (!(bare.home.file ? ".codex/agents/${n}.toml")) "codex agent ${n} is a symlink again (codex skips those)") names;
    assert lib.assertMsg (lib.elem ".agents/agents/ponytail.md" (files withKimi "ponytail")) "kimi opt-in wrote nothing";
    assert lib.all (n: lib.assertMsg (files off n == [ ]) "disabled curated agent ${n} still installed: ${toString (files off n)}") names;
    assert lib.assertMsg (!(withKimi.home.file ? ".agents/agents/coder.md")) "kimi coder replaced without replaceBuiltins";
    assert lib.assertMsg twoReplacers "two agents replacing one built-in accepted";
    pkgs.runCommand "agent-camp-curated" { } ''
      for f in ${toString rendered}; do
        grep -q '/nix/store/[^ `"]*/SKILL.md' "$f" || { echo "FAIL: no skill paths in $f"; exit 1; }
        # `<name>` placeholders are for the agent to fill in, not files.
        paths=$(grep -o '/nix/store/[^ `"<]*\.md' "$f" | sort -u)
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
      ${bare.home.activation.curatedSettings.data}
      ${pkgs.jq}/bin/jq -e '.x == 1 and .permissions.allow[0] == "mine" and (.permissions.allow | length) == 2' .claude/settings.json >/dev/null || { echo "FAIL: rule not added beside the user's"; cat .claude/settings.json; exit 1; }
      d=$(${pkgs.jq}/bin/jq -r '.permissions.allow[1] | capture("^Read\\(/(?<p>.*)/\\*\\*\\)$").p' .claude/settings.json)
      [ -d "$d" ] || { echo "FAIL: rule names missing $d"; exit 1; }
      ${off.home.activation.curatedSettings.data}
      ${pkgs.jq}/bin/jq -e '.permissions.allow == ["mine"]' .claude/settings.json >/dev/null || { echo "FAIL: disable left rules behind"; cat .claude/settings.json; exit 1; }
      touch $out
    '';

  # Activation (#25). For each value, what each harness's user-level
  # instructions carry: claude a rules file of the module's own, codex a marked
  # block in the user's ~/.codex/AGENTS.md (the user's text kept, a link left
  # alone), kimi nothing (no user-level file). The defaults; the repository
  # line opening every delegation rules file; the session hook in claude's
  # and codex's hook files and nowhere else, gone with the last agent.
  activation =
    let
      curated = import ./curated-agents { inherit pkgs; };
      names = lib.attrNames curated.agents;
      jq = "${pkgs.jq}/bin/jq";
      # Only agent n, set to value v, for claude, codex and kimi.
      only = n: v: homeWith [{ agent-camp.curated-agents = lib.genAttrs names (m:
        if m == n then { activation = v; harnesses.kimi = true; } else { activation = "off"; }); }];
      claudeRules = c: c.home.file.".claude/rules/agent-camp-curated-agents.md".text or "";
      section = n: "## Delegating to ${n}\n";
      cases = lib.concatMap (n: map (v: { inherit n v; c = only n v; }) [ "global" "opt-in" "off" ]) names;
      legacyOff = homeWith [{ agent-camp.curated-agents = lib.genAttrs names (_: { enable = false; }); }];
      noHook = c: !(c.home.file ? ".local/share/agent-camp/session-start");
    in
    assert lib.assertMsg (bare.agent-camp.curated-agents.designer.activation == "global") "designer default is not global";
    assert lib.assertMsg (bare.agent-camp.curated-agents.ponytail.activation == "opt-in") "ponytail default is not opt-in";
    assert lib.all ({ n, v, c }: lib.assertMsg (if v == "off" then claudeRules c == ""
      else lib.hasInfix (section n) (claudeRules c) && lib.hasInfix "${n} `${v}`" (claudeRules c))
      "claude rules for ${n} ${v}: ${claudeRules c}") cases;
    assert lib.all ({ n, v, c }: lib.assertMsg (lib.all (f: !lib.hasPrefix ".agents/" f || lib.hasPrefix ".agents/agents/" f) (lib.attrNames c.home.file))
      "kimi got user-level instructions for ${n} ${v}") cases;
    assert lib.all (a: lib.assertMsg (!(a ? instructions) && !(a ? hooks)) "kimi adapter grew instructions or hooks: update this check") [ curated.adapters.kimi ];
    assert lib.all (n: lib.assertMsg (lib.hasPrefix "## Delegating to ${n}\n\n**On or off**: the line `curated-agents: ${n} off`" curated.agents.${n}.delegation
      && lib.hasInfix "`curated-agents: ${n} on`" curated.agents.${n}.delegation) "${n}/delegation.md does not open with the repository line") names;
    assert lib.assertMsg (claudeRules legacyOff == "" && noHook legacyOff) "enable = false still installs rules or the hook";
    assert lib.assertMsg (!noHook bare && lib.all ({ v, c, ... }: (v == "off") == noHook c) cases) "session hook script placed wrongly";
    pkgs.runCommand "agent-camp-activation" { } ''
      export HOME=$PWD
      run() { "$@"; }
      fail() { echo "FAIL: $*"; exit 1; }
      ${lib.concatMapStrings ({ n, v, c }: ''
        # ${n} ${v}: codex's block, beside the user's own text.
        rm -rf .codex .claude .local; mkdir -p .codex; echo mine > .codex/AGENTS.md
        ${c.home.activation.curatedInstructions.data}
        ${c.home.activation.curatedInstructions.data}
        head -1 .codex/AGENTS.md | grep -qx mine || fail "codex: user text lost (${n} ${v})"
        if [ ${v} = off ]; then
          [ "$(cat .codex/AGENTS.md)" = mine ] || fail "codex: ${n} off still writes"
        else
          [ "$(grep -c '^## Delegating to ${n}$' .codex/AGENTS.md)" = 1 ] || fail "codex: ${n} ${v} block missing or doubled"
          grep -qF '${n} `${v}`' .codex/AGENTS.md || fail "codex: ${n} ${v} activation not named"
          ${legacyOff.home.activation.curatedInstructions.data}
          [ "$(cat .codex/AGENTS.md)" = mine ] || fail "codex: block not removed after ${n} ${v}"
        fi
        # The session hook: in claude's settings and codex's hooks, not kimi's.
        ${c.home.activation.curatedSettings.data}
        for f in .claude/settings.json .codex/hooks.json; do
          if [ ${v} = off ]; then [ ! -e $f ] || fail "$f written for ${n} off"
          else ${jq} -e '[.hooks.SessionStart[].hooks[].command | select(endswith("/.local/share/agent-camp/session-start"))] | length == 1' $f >/dev/null || fail "no session hook in $f (${n} ${v})"
          fi
        done
        ! grep -rq session-start .kimi .agents 2>/dev/null || fail "kimi got the session hook"
      '') cases}

      # A link is left alone; the hook leaves the user's own hooks when it goes.
      rm -rf .codex .claude .local; mkdir -p .codex .claude; echo theirs > target; ln -s ../target .codex/AGENTS.md
      echo '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"mine"}]}]}}' > .claude/settings.json
      ${bare.home.activation.curatedInstructions.data}
      [ "$(cat target)" = theirs ] && [ -L .codex/AGENTS.md ] || fail "linked AGENTS.md written through"
      ${bare.home.activation.curatedSettings.data}
      ${jq} -e '.hooks.SessionStart | length == 2 and .[0].hooks[0].command == "mine"' .claude/settings.json >/dev/null || fail "hook not added after the user's"
      ${legacyOff.home.activation.curatedSettings.data}
      ${jq} -e '.hooks.SessionStart == [{"hooks":[{"type":"command","command":"mine"}]}]' .claude/settings.json >/dev/null || fail "hook left behind or user's hook lost"

      # The hook prints a notice per named agent, nothing without the variable.
      h=${bare.home.file.".local/share/agent-camp/session-start".source}
      [ -z "$($h < /dev/null)" ] || fail "notice without AGENT_CAMP_DISABLE_AGENTS"
      msg=$(AGENT_CAMP_DISABLE_AGENTS="designer, ponytail" $h < /dev/null)
      [ "$(printf '%s\n' "$msg" | grep -c 'Do not delegate to the')" = 2 ] && printf '%s' "$msg" | grep -q 'the designer subagent' || fail "notice: $msg"
      touch $out
    '';

  # Per-harness default model and effort: set ones land in the claude
  # frontmatter and the codex TOML (kimi takes none); unset renders as before.
  curated-defaults =
    let
      inherit (import ./curated-agents { inherit pkgs; }) adapters;
      plain = { description = "d"; prompt = "p"; };
      set = plain // { defaults = { claude = { model = "opus"; effort = "high"; }; codex = { model = "m"; effort = "low"; }; kimi = { model = "k"; }; }; };
      unset = plain // { defaults = { claude = { model = null; }; }; };
      r = h: a: adapters.${h}.render "t" a;
      # The codex file as it was rendered before defaults existed.
      codexBefore = (pkgs.formats.toml { }).generate "t.toml" { name = "t"; description = "d"; developer_instructions = "p"; };
    in
    pkgs.runCommand "agent-camp-curated-defaults" { } ''
      printf -- '---\nname: t\ndescription: "d"\neffort: high\nmodel: opus\n---\n\np' | cmp - ${r "claude" set} || { echo "FAIL: claude defaults"; exit 1; }
      grep -qx 'model = "m"' ${r "codex" set} && grep -qx 'model_reasoning_effort = "low"' ${r "codex" set} || { echo "FAIL: codex defaults"; cat ${r "codex" set}; exit 1; }
      cmp ${r "kimi" set} ${r "kimi" plain} || { echo "FAIL: kimi got defaults"; exit 1; }
      for a in ${r "claude" plain} ${r "claude" unset}; do
        printf -- '---\nname: t\ndescription: "d"\n---\n\np' | cmp - $a || { echo "FAIL: claude without defaults changed"; exit 1; }
      done
      cmp ${codexBefore} ${r "codex" plain} && cmp ${codexBefore} ${r "codex" unset} || { echo "FAIL: codex without defaults changed"; exit 1; }
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
