# Read-only status of what module.nix manages, one row per thing. Built by
# the downstream with the same settings it gives the module (harnesses, herdr),
# since the plan runs before any evaluation of the host's home.
{ pkgs, harnesses ? { }, herdr ? { } }:

let
  herdr' = { enable = false; plugins = [ ]; } // herdr;
  inherit (pkgs) lib;
  data = import ./harnesses.nix;
  forced = v: if v == null then "" else if v then "yes" else "no";
  opt = bin: { enable = null; acp = null; } // (harnesses.${bin} or { });
  bunVersion = (import ./bun.nix { inherit pkgs; }).version;
  herdrVersion = (import ./herdr.nix { inherit pkgs; }).version;
in
pkgs.writeShellApplication {
  name = "agent-camp-plan";
  text = ''
    ${builtins.readFile ./choice.sh}
    row() { printf '  [%s] %-13s %-48s %s\n' "$@"; }
    lookup="$HOME/.bun/bin:$HOME/.local/bin:$HOME/.local/share/fnm/aliases/default/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$(id -un)/bin:/opt/homebrew/bin:/usr/local/bin"
    choicef="$HOME/.config/agent-camp/harnesses"

    if bunbin="$(PATH="$lookup" command -v bun 2>/dev/null)"; then
      case "$(realpath "$bunbin")" in
        /nix/store/*) if [ "$("$bunbin" --version 2>/dev/null)" = "${bunVersion}" ]; then
                        row "✓" bun "bun ${bunVersion}" "in sync"
                      else
                        row "•" bun "bun ${bunVersion}" "$("$bunbin" --version 2>/dev/null) now · updated on switch"
                      fi ;;
        *) row "•" bun "bun ${bunVersion}" "hand-installed $bunbin wins on PATH · removed on switch" ;;
      esac
    else
      row "•" bun "bun ${bunVersion}" "install (home.packages)"
    fi
    if uvbin="$(PATH="$lookup" command -v uv 2>/dev/null)"; then
      case "$(realpath "$uvbin")" in
        /nix/store/*) row "✓" uv "uv ${pkgs.uv.version} (nixpkgs)" "in sync" ;;
        *) row "•" uv "uv ${pkgs.uv.version} (nixpkgs)" "hand-installed $uvbin wins on PATH · removed on switch" ;;
      esac
    else
      row "•" uv "uv ${pkgs.uv.version} (nixpkgs)" "install (home.packages)"
    fi
    fnmdir="''${FNM_DIR:-$HOME/.local/share/fnm}"
    fnmlbl="fnm ${pkgs.fnm.version} (nixpkgs) + node LTS under it"
    nodever="$("$fnmdir/aliases/default/bin/node" --version 2>/dev/null || true)"
    if [ -z "$(PATH="$lookup" command -v fnm 2>/dev/null || true)" ]; then
      row "•" fnm "$fnmlbl" "install (home.packages)''${nodever:+ · node $nodever already under fnm}"
    elif [ -z "$nodever" ]; then
      row "•" fnm "$fnmlbl" "no default node · fnm install --lts on switch"
    else
      shellnode="$(PATH="$lookup" command -v node 2>/dev/null || true)"
      case "$shellnode" in
        "$fnmdir"/*) row "✓" fnm "$fnmlbl" "node $nodever (fnm default)" ;;
        *) row "✓" fnm "$fnmlbl" "node $nodever (fnm default) · this shell still has $shellnode" ;;
      esac
    fi
    left=""
    [ -d "$HOME/.nvm" ] && left="$left ~/.nvm"
    [ -d "$HOME/Library/Application Support/fnm" ] && left="$left ~/Library/Application\ Support/fnm"
    for b in node npm npx; do
      case "$(readlink "$HOME/.local/bin/$b" 2>/dev/null)" in "$HOME"/.hermes/node/*) left="$left ~/.local/bin/$b" ;; esac
    done
    for b in uv uvx; do
      [ -f "$HOME/.local/bin/$b" ] && [ ! -L "$HOME/.local/bin/$b" ] && left="$left ~/.local/bin/$b"
    done
    if [ -n "$left" ]; then
      row "•" leftovers "nvm / old fnm / hermes node shims / uv installer" "removed on switch:$left"
    fi

    ${lib.optionalString herdr'.enable ''
      if command -v herdr >/dev/null 2>&1; then
        v="$(herdr --version 2>/dev/null | awk '{print $2}' || true)"
        case "$(realpath "$(command -v herdr)")" in /nix/store/*) where=nix ;; *) where="$(command -v herdr)" ;; esac
        if [ "$v" = "${herdrVersion}" ] && [ "$where" = nix ]; then
          row "✓" herdr "herdr ${herdrVersion} (release binary)" "in sync"
        else
          row "•" herdr "herdr ${herdrVersion} (release binary)" "found $v at $where · converge on switch"
        fi
      else
        row "•" herdr "herdr ${herdrVersion} (release binary)" "install (home.packages)"
      fi
      if [ -f "$HOME/.local/bin/herdr" ] && [ ! -L "$HOME/.local/bin/herdr" ]; then
        row "•" herdr-local "hand-installed ~/.local/bin/herdr" "removed on switch (nix owns herdr)"
      fi
      # The running server bakes HERDR_BIN_PATH into every pane and plugin
      # hook; one started from another copy fails once the switch removes it.
      # ponytail: read from this pane's env — run outside herdr nothing is checked.
      if [ -n "''${HERDR_BIN_PATH:-}" ]; then
        case "$(realpath "$HERDR_BIN_PATH" 2>/dev/null || echo "$HERDR_BIN_PATH")" in
          /nix/store/*) ;;
          *) row "•" herdr-server "running server uses $HERDR_BIN_PATH" "not nix's · restart when idle: herdr server stop; herdr" ;;
        esac
      fi
      ${lib.optionalString (herdr'.plugins != [ ]) ''installed="$(herdr plugin list 2>/dev/null || true)"''}
      ${lib.concatMapStringsSep "\n" (p: ''
        if printf '%s' "$installed" | grep -qF "github:${p.repo}@${p.rev}]"; then
          row "✓" ${p.id} "herdr plugin ${p.repo}" "@${builtins.substring 0 7 p.rev} in sync"
        elif printf '%s' "$installed" | grep -qF "github:${p.repo}@"; then
          row "•" ${p.id} "herdr plugin ${p.repo}" "other rev · reinstall @${builtins.substring 0 7 p.rev} on switch"
        elif printf '%s' "$installed" | grep -q "^- ${p.id}[ .]"; then
          row "•" ${p.id} "herdr plugin ${p.repo}" "installed from another source · replace @${builtins.substring 0 7 p.rev} on switch"
        else
          row "•" ${p.id} "herdr plugin ${p.repo}" "install @${builtins.substring 0 7 p.rev} on switch"
        fi
      '') herdr'.plugins}
    ''}
    integrations="${lib.optionalString herdr'.enable "$(herdr integration status 2>/dev/null || true)"}"

    # want KEY FORCED LABEL: prints yes, or the row for a no / no answer and returns 1.
    want() {
      case "$(decide "$1" "$2")" in
        yes) return 0 ;;
        no) row "✓" "$1" "$3" "$([ -n "$2" ] && echo "off (option)" || echo "opted out ($choicef)")" ;;
        *) row "•" "$1" "$3" "no answer, left alone · nix run from a terminal asks (or $1=yes|no in $choicef)" ;;
      esac
      return 1
    }
    # agent_row BIN PKG VIA HERDR-TARGET FORCED
    agent_row() {
      local bin="$1" pkg="$2" via="$3" tgt="$4" p ver lbl where
      p="$(PATH="$lookup" command -v "$bin" 2>/dev/null || true)"
      case "$via" in
        bun) lbl="$bin (bun add -g $pkg@latest)"
             ver="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$HOME/.bun/install/global/node_modules/$pkg/package.json" 2>/dev/null | head -1 || true)" ;;
        uv)  lbl="$bin (uv tool install $pkg@latest)"
             ver="$(${pkgs.uv}/bin/uv tool list 2>/dev/null | sed -n "s/^$pkg v//p" | head -1 || true)" ;;
        nix) lbl="$bin (nixpkgs $pkg)"
             case "$(realpath "$p" 2>/dev/null)" in /nix/store/*) ver="$("$p" --version 2>/dev/null | awk '{print $NF}' || true)" ;; *) ver="" ;; esac ;;
        *)   lbl="$bin (installed by hand)"; ver="" ;;
      esac
      if [ "$via" != "-" ]; then want "$bin" "$5" "$lbl" || return 0; fi
      if [ -z "$p" ] && [ -z "$ver" ]; then
        if [ "$via" = "-" ]; then row "•" "$bin" "$lbl" "not installed · its herdr hook follows once it is"
        else row "•" "$bin" "$lbl" "install on switch"; fi
        return 0
      fi
      if [ "$via" = nix ] && [ -n "$ver" ]; then where="$ver (nixpkgs)"
      elif [ -n "$ver" ]; then where="$ver via $via · latest on switch"
      elif [ "$via" = "-" ]; then where="$p"
      else where="install on switch (replaces $p)"; fi
      if [ "$bin" = claude ]; then
        case "$(readlink "$HOME/.local/bin/claude" 2>/dev/null)" in
          "$HOME"/.local/share/claude/versions/*) where="$where · native installer copy removed" ;;
        esac
      fi
      ${if herdr'.enable then ''
        if [ "$tgt" = "-" ]; then
          if [ -n "$ver" ]; then row "✓" "$bin" "$lbl" "$where"; else row "•" "$bin" "$lbl" "$where"; fi
        elif printf '%s' "$integrations" | grep -q "^$tgt: current"; then
          row "✓" "$bin" "$lbl" "$where · herdr hook current"
        else
          row "•" "$bin" "$lbl" "$where · herdr hook installed on switch"
        fi
      '' else ''
        : "$tgt"
        if [ -n "$ver" ]; then row "✓" "$bin" "$lbl" "$where"; else row "•" "$bin" "$lbl" "$where"; fi
      ''}
    }
    # acp_row BIN ACP-BIN ACP-PKG FORCED
    acp_row() {
      local lbl="$2 (bun add -g $3@latest)" ver
      want "$1-acp" "$4" "$lbl" || return 0
      ver="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$HOME/.bun/install/global/node_modules/$3/package.json" 2>/dev/null | head -1 || true)"
      if [ -n "$ver" ]; then row "✓" "$1-acp" "$lbl" "$ver via bun · latest on switch"; else row "•" "$1-acp" "$lbl" "install on switch"; fi
    }
    ${lib.concatMapStringsSep "\n" (a: ''
      agent_row ${a.bin} ${if a.pkg == null then "-" else a.pkg} ${if a.via == null then "-" else a.via} ${if a.integration == null then "-" else a.integration} '${forced (opt a.bin).enable}'
    '' + lib.optionalString (a.acp != null) ''
      acp_row ${a.bin} ${a.acp.bin} ${a.acp.pkg} '${forced (opt a.bin).acp}'
    '') data}
  '';
}
