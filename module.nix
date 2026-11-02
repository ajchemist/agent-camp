# Home Manager module for agent-camp: harnesses (coding-agent CLIs), their ACP
# adapters, herdr, and the bun/fnm/uv runtime they need. Importing it installs
# that runtime and nothing else: a harness or adapter is installed only when the
# host answered yes (~/.config/agent-camp/harnesses, see choice.sh and the ask
# script in flake.nix) or the downstream forces it with the options below.
{ lib, config, pkgs, ... }:

let
  cfg = config.agent-camp;
  harnesses = import ./harnesses.nix;
  curated = import ./curated-agents { inherit pkgs; };
  # `enable = false` is the older spelling of activation "off".
  on = n: cfg.curated-agents.${n}.enable && cfg.curated-agents.${n}.activation != "off";
  # The agents installed for harness h: { <name> = <activation>; }.
  installedFor = h: lib.mapAttrs (n: _: cfg.curated-agents.${n}.activation)
    (lib.filterAttrs (n: _: on n && cfg.curated-agents.${n}.harnesses.${h}) curated.agents);
  # Their delegation rules, for the harness's user-level instructions ("" for none).
  instructionsFor = h: lib.optionalString (installedFor h != { }) (curated.instructions (installedFor h));
  # The session hook: one fixed path, so a harness that trusts a hook by its
  # definition (Codex) keeps trusting it across switches.
  sessionHook = ".local/share/agent-camp/session-start";
  hookAdapters = lib.filterAttrs (h: ad: ad ? hooks && installedFor h != { }) curated.adapters;
  # Every curated agent file to place: { path (home-relative), src, copy }, plus
  # one per built-in subagent it replaces (keeping the built-in's description).
  curatedFiles = lib.concatLists (lib.mapAttrsToList (name: a:
    lib.optionals (on name) (lib.concatLists (lib.mapAttrsToList (h: ad:
      lib.optionals cfg.curated-agents.${name}.harnesses.${h} (map ({ n, agent }: { path = ad.file n; src = ad.render n agent; copy = ad.copy or false; })
        ([{ n = name; agent = a; }] ++ lib.optionals cfg.curated-agents.${name}.replaceBuiltins
          (lib.mapAttrsToList (b: description: { n = b; agent = a // { inherit description; override = true; }; }) (ad.replaces or { }))))
    ) curated.adapters))) curated.agents);
  # Claude Code permission rules, while any curated agent goes to claude.
  claudeAllow = lib.optionals (installedFor "claude" != { }) curated.adapters.claude.allow;
  skillSources = import ./skill-sources { inherit pkgs; };
  wantedSkills = lib.filterAttrs (_: o: o.enable) cfg.skills;
  bun = import ./bun.nix { inherit pkgs; };
  herdr = import ./herdr.nix { inherit pkgs; };
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # null = the choice file decides; true/false = forced. As the shell sees it.
  forced = v: if v == null then "" else if v then "yes" else "no";
  opt = bin: cfg.harnesses.${bin} or { enable = null; acp = null; };

  # Only `via = "nix"` harnesses need the answer at eval time (home.packages).
  # The file is read under impure evaluation (the downstream's apps); pure
  # evaluation (flake check) has no builtins.currentSystem and reads nothing.
  choiceFile = "${config.home.homeDirectory}/.config/agent-camp/harnesses";
  choices = if builtins ? currentSystem && builtins.pathExists choiceFile
    then lib.splitString "\n" (builtins.readFile choiceFile) else [ ];
  wants = a: let e = (opt a.bin).enable; in
    if e != null then e else lib.last ([ "" ] ++ lib.filter (lib.hasPrefix "${a.bin}=") choices) == "${a.bin}=yes";

  # Where an agent CLI can already be: bun's global bin, hand installers
  # (~/.local/bin), the nix profiles, brew. The HM activation PATH has none of
  # them, so presence checks run with this PATH rather than the ambient one.
  lookupPath = "$HOME/.bun/bin:$HOME/.local/bin:$HOME/.local/share/fnm/aliases/default/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$(id -un)/bin:/opt/homebrew/bin:/usr/local/bin";

  # What `herdr plugin install` needs (plugins are Rust). A release carrying
  # prebuilt binaries + SHA256SUMS is just downloaded; a rev without one falls
  # back to a source build, which needs a C linker: the HM activation PATH has
  # no /usr/bin, so add it (Xcode CLT `cc` on macOS); on Linux ship gcc.
  pluginPath = lib.makeBinPath ([ herdr pkgs.git pkgs.cargo pkgs.rustc pkgs.curl ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.gcc)
    + lib.optionalString isDarwin ":/usr/bin:/bin";
in
{
  options.agent-camp = {
    harnesses = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Install this harness. null: the host's answer in ~/.config/agent-camp/harnesses (<bin>=yes|no); no answer means not installed.";
          };
          acp = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Install this harness's ACP adapter (harnesses.nix). null: the host's answer (<bin>-acp=yes|no); no answer means not installed.";
          };
        };
      });
      default = { };
      example = lib.literalExpression ''{ claude = { enable = true; acp = true; }; }'';
      description = "Per-harness overrides of the host's answers, keyed by bin (harnesses.nix).";
    };
    herdr = {
      enable = lib.mkEnableOption "herdr (release binary), its plugins, and an integration hook per installed agent";
      plugins = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            id = lib.mkOption { type = lib.types.str; };
            repo = lib.mkOption { type = lib.types.str; description = "`herdr plugin install` source, owner/repo[/subdir]."; };
            rev = lib.mkOption { type = lib.types.str; description = "Commit to pin; reinstalled whenever the installed rev differs."; };
          };
        });
        default = [ ];
        description = "herdr plugins, pinned by commit.";
      };
    };
    curated-agents = lib.mapAttrs (name: a: {
      activation = lib.mkOption {
        type = lib.types.enum [ "global" "opt-in" "off" ];
        default = a.activation;
        description = ''
          How far the ${name} curated agent reaches. "global": installed, and its
          delegation rules (curated-agents/${name}/delegation.md) go to each
          harness's user-level instructions, on in every repository whose
          AGENTS.md lacks `curated-agents: ${name} off`. "opt-in": the same, but
          on only where AGENTS.md has `curated-agents: ${name} on` or the rules
          themselves. "off": nothing installed.
        '';
      };
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Older switch for the ${name} curated agent: false is the same as activation = \"off\".";
      };
      replaceBuiltins = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Also write the ${name} agent under the name of each built-in coding subagent of the harnesses below (adapter `replaces`, e.g. kimi `coder`), replacing it.";
      };
      harnesses = lib.mapAttrs (h: ad: lib.mkOption {
        type = lib.types.bool;
        default = ad.default;
        description = "Write the ${name} agent to ~/${ad.file name}.";
      }) curated.adapters;
    }) curated.agents;
    skills = lib.mapAttrs (name: src: {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install skills from ${name} (skill-sources/${name}) at user scope with the skills CLI.";
      };
      skills = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = src.skills;
        description = "Skill names to install from ${name}.";
      };
      agents = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "claude-code" "codex" ];
        description = "Agents to link the skills into, as the skills CLI names them (`skills add --agent`).";
      };
    }) skillSources.sources;
  };

  config = lib.mkMerge [
    {
      assertions = [{
        assertion = lib.all (b: lib.any (a: a.bin == b) harnesses) (lib.attrNames cfg.harnesses);
        message = "agent-camp.harnesses: unknown harness (known: ${lib.concatMapStringsSep ", " (a: a.bin) harnesses})";
      } {
        # Each would write the same built-in's file.
        assertion = lib.count (n: on n && cfg.curated-agents.${n}.replaceBuiltins) (lib.attrNames curated.agents) <= 1;
        message = "agent-camp.curated-agents: replaceBuiltins is on for more than one agent; only one can take a built-in's place.";
      }];

      home.packages = [
        # The harnesses release daily and want the newest bun (omp: `Bun runtime
        # must be >= 1.3.14`), so bun is pinned ahead of nixpkgs in bun.nix.
        bun
        # node is not optional: the codex/pi launchers and the ACP adapters are
        # `#!/usr/bin/env node` scripts. It comes from fnm (one LTS, see fnmNode).
        pkgs.fnm
        # `uv tool install` for the PyPI-only harnesses (kimi).
        pkgs.uv
      ] ++ map (a: pkgs.${a.pkg}) (lib.filter (a: a.via == "nix" && wants a) harnesses)
        ++ lib.optional cfg.herdr.enable herdr;

      # Curated agents, one file per harness that wants each; their delegation
      # rules where the harness has a user-level file of its own for them; the
      # session hook where a harness runs it.
      home.file = lib.listToAttrs (map (p: lib.nameValuePair p.path { source = p.src; })
        (lib.filter (p: !p.copy) curatedFiles))
        // lib.mapAttrs' (h: ad: lib.nameValuePair ad.instructions { text = instructionsFor h; })
          (lib.filterAttrs (h: ad: ad ? instructions && !(ad.instructionsShared or false) && instructionsFor h != "") curated.adapters)
        // lib.optionalAttrs (hookAdapters != { }) {
          # AGENT_CAMP_DISABLE_AGENTS="designer,ponytail": a notice per name.
          ${sessionHook}.source = pkgs.writeShellScript "agent-camp-session-start" ''
            IFS=', ' read -ra names <<< "''${AGENT_CAMP_DISABLE_AGENTS:-}"
            for n in "''${names[@]}"; do
              case "$n" in ""|*[!A-Za-z0-9_.-]*) continue ;; esac
              echo "agent-camp: AGENT_CAMP_DISABLE_AGENTS switches $n off for this session. Do not delegate to the $n subagent in this session, whatever AGENTS.md or your other instructions say."
            done
          '';
        };

      # The delegation rules in a user-level file the user owns (Codex's
      # ~/.codex/AGENTS.md): a marked block at its end, rewritten on every
      # switch and removed when no agent is installed. The rest of the file
      # stays as it is; a link is left alone.
      home.activation.curatedInstructions = lib.hm.dag.entryAfter [ "linkGeneration" ] (let
        awk = "${pkgs.gawk}/bin/awk";
      in ''
        begin='<!-- agent-camp curated agents: begin (rewritten on every switch) -->' end='<!-- agent-camp curated agents: end -->'
        # put_block FILE [RULES]: the block holds RULES' text, or goes.
        put_block() {
          local f="$1" want="''${2:-}" cur="" kept new sep=""
          if [ -L "$f" ]; then
            [ -z "$want" ] || echo "agent-camp: $f is a link, not adding the curated agents' delegation rules" >&2
            return 0
          fi
          [ ! -f "$f" ] || cur=$(cat "$f")
          # The file without the block and without trailing blank lines.
          kept=$(printf '%s\n' "$cur" | ${awk} -v b="$begin" -v e="$end" '
            $0 == b { s = 1; next } $0 == e { s = 0; next } s { next }
            /^[[:space:]]*$/ { blank = blank $0 "\n"; next }
            { printf "%s%s\n", blank, $0; blank = "" }')
          new="$kept"
          if [ -n "$want" ]; then
            [ -z "$kept" ] || sep=$'\n\n'
            new="$kept$sep$begin"$'\n'"$(cat "$want")"$'\n'"$end"
          fi
          [ "$new" != "$cur" ] || return 0
          if [ -z "$new" ]; then
            run rm -f "$f"
          else
            run mkdir -p "$(dirname "$f")"
            printf '%s\n' "$new" | run tee "$f" >/dev/null
          fi
        }
        ${lib.concatStrings (lib.mapAttrsToList (h: ad: ''
          put_block "$HOME/${ad.instructions}" ${lib.optionalString (instructionsFor h != "") (pkgs.writeText "agent-camp-${h}-instructions.md" (instructionsFor h))}
        '') (lib.filterAttrs (_: ad: ad.instructionsShared or false) curated.adapters))}
      '');

      # The adapters that need a regular file get a copy, read-only like the
      # links. A copy an earlier switch placed and nothing wants now is removed.
      home.activation.curatedAgentCopies = lib.hm.dag.entryAfter [ "linkGeneration" ] (let
        copies = lib.filter (p: p.copy) curatedFiles;
      in ''
        state="$HOME/.local/state/agent-camp/curated-copies"
        wanted="${lib.concatMapStringsSep " " (p: p.path) copies}"
        if [ -f "$state" ]; then
          while IFS= read -r p; do
            case " $wanted " in *" $p "*) ;; *) [ ! -f "$HOME/$p" ] || [ -L "$HOME/$p" ] || run rm -f "$HOME/$p" ;; esac
          done < "$state"
        fi
        ${lib.concatMapStrings (p: ''
          cmp -s ${p.src} "$HOME/${p.path}" || run install -D -m 0444 ${p.src} "$HOME/${p.path}"
        '') copies}
        run mkdir -p "$(dirname "$state")"
        printf '%s\n' $wanted | run tee "$state" >/dev/null
      '');

      # Lists in JSON files the harnesses also write: the claude curated agents'
      # permission rules in ~/.claude/settings.json, and the session hook in
      # each hook file. Only the entries this step added are touched. The last
      # set is kept in state, so a bump or a disable replaces it.
      home.activation.curatedSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (let
        jq = "${pkgs.jq}/bin/jq";
        hookEntry = [{ hooks = [{ type = "command"; command = "${config.home.homeDirectory}/${sessionHook}"; timeout = 10; }]; }];
      in ''
        # merge FILE STATE-NAME PATH WANT: the list at PATH (a jq path array)
        # keeps its other entries and holds WANT's after them.
        merge() {
          local settings="$1" state="$HOME/.local/state/agent-camp/$2" p="$3" want="$4" old cur new
          old=$(cat "$state" 2>/dev/null || echo '[]')
          if [ "$want" != "$old" ] || { [ "$want" != '[]' ] && [ ! -e "$settings" ]; }; then
            cur='{}'
            [ ! -s "$settings" ] || cur=$(cat "$settings")
            if [ -L "$settings" ]; then
              echo "agent-camp: $settings is a link, not adding the curated agents' entries: $want" >&2
            elif new=$(printf '%s' "$cur" | ${jq} --argjson p "$p" --argjson old "$old" --argjson want "$want" \
                '((getpath($p) // []) - $old) as $k | setpath($p; $k + ($want - $k))'); then
              run mkdir -p "$(dirname "$settings")" "$(dirname "$state")"
              printf '%s\n' "$new" | run tee "$settings" >/dev/null
              printf '%s\n' "$want" | run tee "$state" >/dev/null
            else
              echo "agent-camp: $settings is not valid JSON, not adding the curated agents' entries: $want" >&2
            fi
          fi
        }
        merge "$HOME/.claude/settings.json" claude-allow '["permissions","allow"]' ${lib.escapeShellArg (builtins.toJSON claudeAllow)}
        ${lib.concatStrings (lib.mapAttrsToList (h: ad: ''
          merge "$HOME/${ad.hooks}" ${h}-session-start '["hooks","SessionStart"]' ${lib.escapeShellArg (builtins.toJSON (lib.optionals (hookAdapters ? ${h}) hookEntry))}
        '') (lib.filterAttrs (_: ad: ad ? hooks) curated.adapters))}
      '');

      # User-scope skills (skill-sources/): nix pins each source, the skills CLI
      # copies the skills to ~/.agents/skills and links them into each agent.
      # A source is added again only when its pin, skills or agents change, so
      # local changes last until then. Skills whose recorded source is a store
      # path no longer wanted are removed; skills from anywhere else are left.
      home.activation.userSkills = lib.hm.dag.entryAfter [ "agentClis" ] (let
        jq = "${pkgs.jq}/bin/jq";
        nixOwned = ''.skills | to_entries[] | select(.value.source | startswith("/nix/store/")) | .key'';
      in ''
        state="$HOME/.local/state/agent-camp/skills" lock="$HOME/.agents/.skill-lock.json"
        skills_cli() { run env PATH="${bun}/bin:$HOME/.local/share/fnm/aliases/default/bin:$PATH" bun x ${skillSources.cli} "$@"; }
        nix_owned() { [ -f "$lock" ] && ${jq} -r '${nixOwned}' "$lock" || true; }
        mkdir -p "$state"
        # drop NAMES...: remove those of NAMES the store put there, in one call.
        drop() {
          local s gone=()
          for s in $(nix_owned); do case " $* " in *" $s "*) gone+=("$s") ;; esac; done
          [ "''${#gone[@]}" -eq 0 ] || skills_cli remove -g -y "''${gone[@]}" \
            || echo "agent-camp skills: could not remove ''${gone[*]} (see above)" >&2
        }
        wanted="${lib.concatStringsSep " " (lib.concatMap (o: o.skills) (lib.attrValues wantedSkills))}" unwanted=()
        for s in $(nix_owned); do
          case " $wanted " in *" $s "*) ;; *) unwanted+=("$s") ;; esac
        done
        [ "''${#unwanted[@]}" -eq 0 ] || drop "''${unwanted[@]}"
        ${lib.concatStringsSep "
" (lib.mapAttrsToList (name: o: let
          src = skillSources.sources.${name}.src;
          sig = "${src} ${lib.concatStringsSep "," o.agents} ${lib.concatStringsSep "," o.skills}";
        in ''
          if [ "$(cat "$state/${name}" 2>/dev/null || true)" != ${lib.escapeShellArg sig} ]; then
            # Drop the old copies first, so an agent taken off the list loses its links.
            drop ${lib.concatStringsSep " " o.skills}
            if skills_cli add ${src} -g ${lib.concatMapStringsSep " " (a: "-a ${a}") o.agents} ${lib.concatMapStringsSep " " (k: "-s ${k}") o.skills} -y; then
              echo ${lib.escapeShellArg sig} | run tee "$state/${name}" >/dev/null
            else
              echo "agent-camp skills ${name}: skills add failed (see above); retried next switch" >&2
            fi
          fi
        '') wantedSkills)}
        ${lib.concatMapStringsSep "
" (n: ''rm -f "$state/${n}"'') (lib.attrNames (lib.filterAttrs (_: o: !o.enable) cfg.skills))}
        # One view per source: links to just its skills in ~/.agents/skills, for
        # harnesses that take a whole directory (hermes' skills.external_dirs).
        # Derived, never edited: rebuilt from scratch on every switch.
        views="$HOME/.local/share/agent-camp/skills"
        run rm -rf "$views"
        ${lib.concatStringsSep "
" (lib.mapAttrsToList (name: o: ''
          run mkdir -p "$views/${name}"
          for k in ${lib.concatStringsSep " " o.skills}; do run ln -s "$HOME/.agents/skills/$k" "$views/${name}/$k"; done
        '') wantedSkills)}
      '');

      # One fnm root on every OS (fnm would pick ~/Library/Application Support
      # on macOS), so activation, shells and plans name the same path. The
      # default node and bun's global bin are on PATH for anything started
      # from a login environment, including hooks with a bare PATH.
      home.sessionVariables.FNM_DIR = "$HOME/.local/share/fnm";
      # designer runs Impeccable's engine from the pinned store path; without
      # this it checks for updates and writes ~/.impeccable/update-check.json
      # whatever IMPECCABLE_HOME says. Its staleness check writes
      # ~/.impeccable/staleness-check.json unless pointed elsewhere, and its
      # telemetry is off by the maintainer's choice.
      home.sessionVariables.IMPECCABLE_NO_UPDATE_CHECK = lib.mkIf (on "designer") "1";
      home.sessionVariables.IMPECCABLE_STALENESS_CACHE = lib.mkIf (on "designer") "$HOME/.cache/impeccable/staleness-check.json";
      home.sessionVariables.IMPECCABLE_NO_TELEMETRY = lib.mkIf (on "designer") "1";
      home.sessionVariables.DO_NOT_TRACK = lib.mkIf (on "designer") "1";
      home.sessionPath = [ "$HOME/.bun/bin" "$HOME/.local/share/fnm/aliases/default/bin" ];

      # node for the agent CLIs, from fnm, only while fnm has no default yet:
      # agent-camp puts one node on the machine and never touches which one
      # after that — picking versions is what fnm is for.
      home.activation.fnmNode = lib.hm.dag.entryAfter [ "installPackages" ] ''
        export FNM_DIR="$HOME/.local/share/fnm"
        if ! ${pkgs.fnm}/bin/fnm default >/dev/null 2>&1; then
          run ${pkgs.fnm}/bin/fnm install --lts \
            && run ${pkgs.fnm}/bin/fnm default lts-latest \
            || echo "fnm: could not install the LTS node (see above); codex, pi and the ACP adapters need one, rerun later" >&2
        fi
      '';

      # bun and uv are nix's now. Copies earlier installers left would shadow
      # or confuse them: the hand-installed ~/.bun/bin/bun (+ bunx, completions),
      # ~/.nvm, fnm's pre-FNM_DIR root, hermes' node shims, uv's standalone
      # binaries. ~/.bun/install/global stays: the harnesses live there.
      home.activation.runtimeLeftovers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f "$HOME/.bun/bin/bun" ] && [ ! -L "$HOME/.bun/bin/bun" ]; then
          run rm -v "$HOME/.bun/bin/bun"
          [ -L "$HOME/.bun/bin/bunx" ] && run rm -v "$HOME/.bun/bin/bunx"
          [ -e "$HOME/.bun/_bun" ] && run rm -v "$HOME/.bun/_bun"
        fi
        [ -d "$HOME/.nvm" ] && run rm -rf "$HOME/.nvm"
        [ -d "$HOME/Library/Application Support/fnm" ] && run rm -rf "$HOME/Library/Application Support/fnm"
        for b in node npm npx; do
          case "$(readlink "$HOME/.local/bin/$b" 2>/dev/null)" in "$HOME"/.hermes/node/*) run rm -v "$HOME/.local/bin/$b" ;; esac
        done
        for b in uv uvx; do
          [ -f "$HOME/.local/bin/$b" ] && [ ! -L "$HOME/.local/bin/$b" ] && run rm -v "$HOME/.local/bin/$b"
        done
        true
      '';

      # The harnesses and adapters the host said yes to (or the options force).
      # `<pkg>@latest` every switch: installs when missing, upgrades when
      # behind, no-op when current — never an older version over a hand
      # `bun update -g`. Copies from other installers are superseded and go:
      # global packages under fnm's default node, Claude Code's native
      # installer, goose's download script.
      home.activation.agentClis = lib.hm.dag.entryAfter [ "fnmNode" ] ''
        npmg="$HOME/.local/share/fnm/aliases/default"
        ${builtins.readFile ./choice.sh}
        ${lib.concatMapStringsSep "\n" (a: ''
          if [ "$(decide ${a.bin} '${forced (opt a.bin).enable}')" = yes ]; then
            if run ${bun}/bin/bun add -g ${a.pkg}@latest; then
              case "$(readlink "$npmg/bin/${a.bin}" 2>/dev/null)" in
                ../lib/node_modules/${a.pkg}/*|"$npmg"/lib/node_modules/${a.pkg}/*) run rm -v "$npmg/bin/${a.bin}" ;;
              esac
              [ ! -d "$npmg/lib/node_modules/${a.pkg}" ] || run rm -rf "$npmg/lib/node_modules/${a.pkg}"
            else
              echo "agent-camp ${a.bin}: bun add -g ${a.pkg}@latest failed (see above); rest of the switch continues" >&2
            fi
          fi
        '') (lib.filter (a: a.via == "bun") harnesses)}
        ${lib.concatMapStringsSep "\n" (a: ''
          if [ "$(decide ${a.bin} '${forced (opt a.bin).enable}')" = yes ]; then
            run ${pkgs.uv}/bin/uv tool install ${a.pkg}@latest \
              || echo "agent-camp ${a.bin}: uv tool install ${a.pkg}@latest failed (see above); rest of the switch continues" >&2
          fi
        '') (lib.filter (a: a.via == "uv") harnesses)}
        ${lib.concatMapStringsSep "\n" (a: ''
          if [ "$(decide ${a.bin}-acp '${forced (opt a.bin).acp}')" = yes ]; then
            run ${bun}/bin/bun add -g ${a.acp.pkg}@latest \
              || echo "agent-camp ${a.bin}-acp: bun add -g ${a.acp.pkg}@latest failed (see above); rest of the switch continues" >&2
            ${lib.concatMapStringsSep "\n" (was: ''
              [ ! -d "$HOME/.bun/install/global/node_modules/${a.acp.pkg}" ] || [ ! -d "$HOME/.bun/install/global/node_modules/${was}" ] \
                || run ${bun}/bin/bun remove -g ${was}
            '') (a.acp.was or [ ])}
          fi
        '') (lib.filter (a: a.acp != null) harnesses)}
        if [ "$(decide claude '${forced (opt "claude").enable}')" = yes ] && [ -x "$HOME/.bun/bin/claude" ]; then
          case "$(readlink "$HOME/.local/bin/claude" 2>/dev/null)" in
            "$HOME"/.local/share/claude/versions/*) run rm -v "$HOME/.local/bin/claude"; run rm -rf "$HOME/.local/share/claude" ;;
          esac
        fi
        if [ "$(decide goose '${forced (opt "goose").enable}')" = yes ] && [ -f "$HOME/.local/bin/goose" ] && [ ! -L "$HOME/.local/bin/goose" ]; then
          run rm -v "$HOME/.local/bin/goose"
        fi
      '';
    }

    (lib.mkIf cfg.herdr.enable {
      # A hand-installed herdr in ~/.local/bin would shadow nix's and drift.
      home.activation.herdrLocalCopy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f "$HOME/.local/bin/herdr" ] && [ ! -L "$HOME/.local/bin/herdr" ]; then
          run rm -v "$HOME/.local/bin/herdr"
        fi
      '';

      # PATH is scoped to these commands only: exporting it would leak /usr/bin
      # into later HM steps, which then pick BSD readlink over GNU (`-e` fails).
      home.activation.herdrPlugins = lib.mkIf (cfg.herdr.plugins != [ ]) (lib.hm.dag.entryAfter [ "installPackages" ] ''
        installed="$(PATH="${pluginPath}:$PATH" herdr plugin list 2>/dev/null || true)"
        ${lib.concatMapStringsSep "\n" (p: ''
          if ! printf '%s' "$installed" | grep -qF "github:${p.repo}@${p.rev}]"; then
            run env PATH="${pluginPath}:$PATH" herdr plugin install ${lib.escapeShellArg p.repo} --ref ${p.rev} -y \
              || echo "herdr plugin ${p.id}: install failed (see above); rest of the switch continues, rerun later" >&2
          fi
        '') cfg.herdr.plugins}
      '');

      # Integration hooks let a restarted herdr server resume each agent's own
      # session instead of leaving a dead pane. One per agent whose CLI is
      # present, whenever herdr does not report it `current`.
      home.activation.herdrIntegrations = lib.hm.dag.entryAfter [ "agentClis" ] ''
        integrations="$(${herdr}/bin/herdr integration status 2>/dev/null || true)"
        # herdr refuses to write into an agent config dir that does not exist
        # yet (pi and omp create theirs on first run), so create the directory
        # herdr names in its status line first.
        hook() {
          local tgt="$1" bin="$2" line dir
          if ! PATH="${lookupPath}" command -v "$bin" >/dev/null 2>&1; then return 0; fi
          line="$(printf '%s' "$integrations" | grep "^$tgt: " || true)"
          case "$line" in "$tgt: current"*) return 0 ;; esac
          dir="$(printf '%s' "$line" | sed -n 's/.*(\(.*\))$/\1/p' || true)"
          if [ -n "$dir" ]; then run mkdir -p "$(dirname "$dir")"; fi
          run ${herdr}/bin/herdr integration install "$tgt" \
            || echo "herdr integration $tgt: install failed (see above); rest of the switch continues" >&2
        }
        ${lib.concatMapStringsSep "\n" (a: "hook ${a.integration} ${a.bin}") (lib.filter (a: a.integration != null) harnesses)}
      '';
    })
  ];
}
