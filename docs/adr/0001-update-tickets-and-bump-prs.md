# Update tickets per pinned tool, closed by automated bump PRs

Status: accepted (2026-10-07). Defaults chosen in one grilling session; any line may be revisited.

The daily briefing (`ci/updates.py`) already compares every tool with upstream. We turn it into work items:

1. **Scope**: only pinned tools get an update ticket: `bun` (bun.nix) and `herdr` (herdr.nix). @latest tools (agent CLIs and ACP adapters) stay briefing-only: a new release needs no commit, and the weekly e2e in ci.yml already catches breakage.
2. **goose is excluded**: its pin is nixpkgs through `flake.lock` → nix-basecamp. Bumping it means `nix flake update basecamp`, which moves everything, and upstream releases often aren't in nixpkgs yet. It stays a briefing row; the lock is nix-basecamp's job.
3. **One open ticket per tool**: found by labels `update` + `update:<tool>`, never by title (humans may edit titles). When upstream moves again, the same ticket's title and body are rewritten (`0.9.1 → 0.9.3`). A new major version only adds a warning line, not a new ticket.
4. **Auto-close**: if the pin already equals upstream while a ticket is open (bumped without referencing it), the workflow comments and closes it.
5. **Triage**: tickets open with `needs-triage`. They are not approved yet (see ADR 0002).
6. **Approval = the `approved` label on the ticket** (ADR 0002). Only once a ticket is `approved` does automation open one bump PR (`Closes #n`), and it updates that PR whenever the ticket is bumped. Merging is review, not approval. Version and hashes are computed by a script, not an agent, because they are deterministic (bun: SHASUMS256.txt → SRI; herdr: `nix store prefetch-file`). An agent (Claude Code Action) steps in only when ci.yml fails on the bump PR. Nothing auto-merges.

## Considered options

- Ticket per tool+major version: rejected, the "keep bumping the open ticket" flow covers it.
- Hidden body markers to find tickets: rejected for labels, which are visible and filterable.
- Maintainer hand-writes bump PRs: workable, but hash updates are mechanical toil.
- Agent writes every bump: unnecessary when a script is deterministic. The agent is reserved for the non-deterministic case (broken CI).

## Open defaults (not asked; change freely)

- Agent auth: the `CLAUDE_CODE_OAUTH_TOKEN` repo secret. Without it a red bump PR simply waits for a human.
- The repo setting "Allow GitHub Actions to create and approve pull requests" is on (needed for `gh pr create` with `GITHUB_TOKEN`).
- Bump PR branch: `update/<tool>`, force-pushed when upstream moves again, so there is one PR per ticket.
- Workflow token needs `issues: write`, `contents: write`, `pull-requests: write`, `actions: write`.
- CI on bump PRs: a PR opened with `GITHUB_TOKEN` fires no `pull_request` run, so the workflow runs `gh workflow run ci.yml --ref update/<tool>` (dispatch is exempt from that rule). The result lands on the head commit and shows on the PR. No PAT or App needed.
