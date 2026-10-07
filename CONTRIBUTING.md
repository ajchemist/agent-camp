# Contributing to agent-camp

## Before submitting

- **A linked issue marked `approved`.** Put `Closes #<number>` in the PR description. A PR that
  doesn't close an `approved` issue is closed automatically the moment it opens. It reopens on its
  own when the linked issue is approved; if the link was missing, fix it and reopen the PR.
  Anyone may open the PR, not only the issue's author. Docs-only changes (`*.md`, `docs/`) skip
  the check.
- Commits must not credit an AI tool as a co-author (`Co-authored-by:` trailers); a check fails
  the PR if they do.
- `nix flake check` passes.

Why: [docs/adr/0002-approved-issue-gate.md](docs/adr/0002-approved-issue-gate.md).
