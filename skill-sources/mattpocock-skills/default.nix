# mattpocock/skills at user scope: by default only the skills its plugin marks
# `disable-model-invocation: true`. They cost no context until typed, so they
# can sit in every harness; the model-invoked ones (tdd, grilling, …) are left
# for a repository or a curated agent to choose.
{ pkgs }:
(import ./source.nix { inherit pkgs; }) // {
  skills = [
    "ask-matt" "grill-with-docs" "implement" "implement-spec"
    "improve-codebase-architecture" "retro" "setup-matt-pocock-skills"
    "to-spec" "to-tickets" "triage" "wayfinder"
    "grill-me" "handoff" "teach" "to-questionnaire" "wait-what"
  ];
}
