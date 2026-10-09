# Code changes need an approved issue (tinycast convention)

Status: accepted (2026-10-07). Adopted from [abue-ammar/tinycast](https://github.com/abue-ammar/tinycast) (`.github/workflows/triage.yml`, `coauthors.yml`).

**Approval is one thing everywhere: a maintainer adds the `approved` label to an issue.** No PR from a human or a bot exists for unapproved work.

- **Gate**: on `pull_request_target`, a PR from anyone other than OWNER/MEMBER/COLLABORATOR that doesn't `Closes #n` an `approved` issue is commented on and closed (`not_planned`). Docs-only diffs (`*.md`, `docs/`) are exempt. No checkout, API calls only, so `_target` is safe for forks.
- **Reopen**: labelling an issue `approved` reopens the PRs that link it, but only the ones the gate itself closed. A maintainer's close stays final.
- **First touch**: every new issue gets a comment saying not to write code before `approved`.
- **AI co-authors**: a PR whose commits carry an AI `Co-authored-by:` trailer fails, with a fix-up recipe in a single comment kept up to date.
- **Templates**: the PR template leads with `Closes #`, and blank issues are disabled.
- **Labels**: `approved` is a decision ("we'll do this"). It is orthogonal to `ready-for-agent`/`ready-for-human` ("who does it"), and both may be on the same issue.
- **Bots**: bump PRs (ADR 0001) are only opened after `approved`, so they obey the same rule. Because `GITHUB_TOKEN` events start no workflows, the gate never runs on them anyway.

## Considered options

- Merge-is-approval for bot PRs: rejected for a single rule people and bots both follow, at the cost of one extra click.
- `ready-for-*` doubling as approval: rejected, because it conflates "decided" with "who".

## Spreading it

The gate is meant for every repo the maintainer runs. It ships in two parts, neither in agent-camp:

- **Reusable workflows** for the gate and the co-author check live once in the public repo `ajchemist/.github`, versioned by tag. Each repo calls them with a few `uses: ajchemist/.github/...@v1` lines and per-repo inputs (`docs-paths`, `approval-label`). A fix lands once and reaches every repo. `pull_request_target` callers pass their event context and permissions to the called workflow, so the gate works unchanged.
- **A skill** in `ajchemist/skills` (a user-scope skill since ADR 0004, not pinned per repo) explores a target repo and writes the caller lines, PR template, CONTRIBUTING section and `approved` label to fit it. It never copies the gate logic.
