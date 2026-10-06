# Asks which agents and ACP adapters this host wants, once each, and records
# the answers in ~/.config/agent-camp/agents (choice.sh). Run it from the
# downstream's `nix run` app before the build: Home Manager activation has no
# terminal (nix-darwin runs it through `launchctl asuser`). One gum checklist
# for everything undecided, nothing preselected: an unticked item is recorded
# as no. Esc records nothing. Without a terminal nothing is asked or
# recorded, so nothing is installed (the non-interactive default).
{ pkgs }:

let
  inherit (pkgs) lib;
  data = import ./agents.nix;
  items = lib.concatMap (a:
    lib.optional (a.pkg != null) "${a.bin}  ${a.via}: ${a.pkg}"
    ++ lib.optional (a.acp != null) "${a.bin}-acp  bun: ${a.acp.pkg} (ACP adapter, for editors)") data;
in
pkgs.writeShellApplication {
  name = "agent-camp-ask";
  runtimeInputs = [ pkgs.gum ];
  text = ''
    ${builtins.readFile ./choice.sh}
    choice="$HOME/.config/agent-camp/agents"
    mkdir -p "$(dirname "$choice")"; touch "$choice"
    undecided=()
    for a in ${lib.escapeShellArgs items}; do
      case "$(agent_choice "''${a%% *}")" in yes|no) ;; *) undecided+=("$a") ;; esac
    done
    [ "''${#undecided[@]}" -gt 0 ] || exit 0
    if ! ( : </dev/tty ) 2>/dev/null; then
      echo "agent-camp: undecided, not installed: ''${undecided[*]%% *} — run from a terminal to choose, or add <key>=yes|no to $choice" >&2
    elif sel="$(gum choose --no-limit --header "agent-camp: install on this host (space toggles, enter submits)" \
                  "''${undecided[@]}" </dev/tty 2>/dev/tty)"; then
      echo "agent-camp: recorded in $choice:"
      for a in "''${undecided[@]}"; do
        if printf '%s\n' "$sel" | grep -qxF "$a"; then echo "''${a%% *}=yes"; else echo "''${a%% *}=no"; fi
      done | tee -a "$choice" | sed 's/^/  /'
    else
      echo "agent-camp: nothing recorded; asked again next run" >&2
    fi
  '';
}
