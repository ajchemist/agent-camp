# Home Manager module for agent-camp: coding-agent CLIs, their ACP adapters,
# herdr, and the bun/fnm/uv runtime they need. Importing it installs that
# runtime and nothing else: an agent or adapter is installed only when the
# host answered yes (~/.config/agent-camp/agents, see choice.sh and the ask
# script in flake.nix) or the downstream forces it with the options below.
{ lib, config, pkgs, ... }:

let
  cfg = config.agent-camp;
  agents = import ./agents.nix;
  bun = import ./bun.nix { inherit pkgs; };
  herdr = import ./herdr.nix { inherit pkgs; };
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # null = the choice file decides; true/false = forced. As the shell sees it.
  forced = v: if v == null then "" else if v then "yes" else "no";
  opt = bin: cfg.agents.${bin} or { enable = null; acp = null; };

  # Only `via = "nix"` agents need the answer at eval time (home.packages).
  # The file is read under impure evaluation (the downstream's apps); pure
  # evaluation (flake check) has no builtins.currentSystem and reads nothing.
  choiceFile = "${config.home.homeDirectory}/.config/agent-camp/agents";
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
    agents = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Install this agent CLI. null: the host's answer in ~/.config/agent-camp/agents (<bin>=yes|no); no answer means not installed.";
          };
          acp = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Install this agent's ACP adapter (agents.nix). null: the host's answer (<bin>-acp=yes|no); no answer means not installed.";
          };
        };
      });
      default = { };
      example = lib.literalExpression ''{ claude = { enable = true; acp = true; }; }'';
      description = "Per-agent overrides of the host's answers, keyed by bin (agents.nix).";
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
  };

  config = lib.mkMerge [
    {
      assertions = [{
        assertion = lib.all (b: lib.any (a: a.bin == b) agents) (lib.attrNames cfg.agents);
        message = "agent-camp.agents: unknown agent (known: ${lib.concatMapStringsSep ", " (a: a.bin) agents})";
      }];

      home.packages = [
        # The agents release daily and want the newest bun (omp: `Bun runtime
        # must be >= 1.3.14`), so bun is pinned ahead of nixpkgs in bun.nix.
        bun
        # node is not optional: the codex/pi launchers and the ACP adapters are
        # `#!/usr/bin/env node` scripts. It comes from fnm (one LTS, see fnmNode).
        pkgs.fnm
        # `uv tool install` for the PyPI-only agents (kimi).
        pkgs.uv
      ] ++ map (a: pkgs.${a.pkg}) (lib.filter (a: a.via == "nix" && wants a) agents)
        ++ lib.optional cfg.herdr.enable herdr;

      # One fnm root on every OS (fnm would pick ~/Library/Application Support
      # on macOS), so activation, shells and plans name the same path. The
      # default node and bun's global bin are on PATH for anything started
      # from a login environment, including hooks with a bare PATH.
      home.sessionVariables.FNM_DIR = "$HOME/.local/share/fnm";
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
      # binaries. ~/.bun/install/global stays: the agents live there.
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

      # The agents and adapters the host said yes to (or the options force).
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
        '') (lib.filter (a: a.via == "bun") agents)}
        ${lib.concatMapStringsSep "\n" (a: ''
          if [ "$(decide ${a.bin} '${forced (opt a.bin).enable}')" = yes ]; then
            run ${pkgs.uv}/bin/uv tool install ${a.pkg}@latest \
              || echo "agent-camp ${a.bin}: uv tool install ${a.pkg}@latest failed (see above); rest of the switch continues" >&2
          fi
        '') (lib.filter (a: a.via == "uv") agents)}
        ${lib.concatMapStringsSep "\n" (a: ''
          if [ "$(decide ${a.bin}-acp '${forced (opt a.bin).acp}')" = yes ]; then
            run ${bun}/bin/bun add -g ${a.acp.pkg}@latest \
              || echo "agent-camp ${a.bin}-acp: bun add -g ${a.acp.pkg}@latest failed (see above); rest of the switch continues" >&2
          fi
        '') (lib.filter (a: a.acp != null) agents)}
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
      home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "installPackages" ] ''
        installed="$(PATH="${pluginPath}:$PATH" herdr plugin list 2>/dev/null || true)"
        ${lib.concatMapStringsSep "\n" (p: ''
          if ! printf '%s' "$installed" | grep -qF "github:${p.repo}@${p.rev}]"; then
            run env PATH="${pluginPath}:$PATH" herdr plugin install ${lib.escapeShellArg p.repo} --ref ${p.rev} -y \
              || echo "herdr plugin ${p.id}: install failed (see above); rest of the switch continues, rerun later" >&2
          fi
        '') cfg.herdr.plugins}
      '';

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
        ${lib.concatMapStringsSep "\n" (a: "hook ${a.integration} ${a.bin}") (lib.filter (a: a.integration != null) agents)}
      '';
    })
  ];
}
