# Stable workflow skills belong at user scope, including the reusable skills
# invoked by entry points such as grill-me, triage and implement.
{ pkgs }:
(import ./source.nix { inherit pkgs; }) // {
  skills = [
    "ask-matt" "code-review" "codebase-design" "diagnosing-bugs"
    "domain-modeling" "grill-with-docs" "implement" "implement-spec"
    "improve-codebase-architecture" "pr" "prototype" "research" "retro"
    "setup-matt-pocock-skills" "tdd" "to-spec" "to-tickets" "triage"
    "wayfinder" "wizard"
    "grill-me" "grilling" "handoff" "teach" "to-questionnaire" "wait-what"
    "writing-for-agents"
  ];
}
