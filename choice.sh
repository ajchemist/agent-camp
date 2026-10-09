# The host's answers: ~/.config/agent-camp/harnesses, `<bin>=yes|no` and
# `<bin>-acp=yes|no`, one per line. Last answer wins; anything else is
# undecided. Shared by the ask script, the plan and the activation.
agent_choice() {
  sed -n "s/^$1=//p" "$HOME/.config/agent-camp/harnesses" 2>/dev/null | tail -1 || true
}
# decide KEY FORCED: a Nix option set to true/false (FORCED = yes|no) wins over the file.
decide() { if [ -n "$2" ]; then echo "$2"; else agent_choice "$1"; fi; }
