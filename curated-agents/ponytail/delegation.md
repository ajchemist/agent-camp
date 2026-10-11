## Delegating to ponytail

If a subagent named `ponytail` is available, decide before starting any task
that changes code whether to hand it to that subagent. If it is not available,
ignore this section.

**Delegate** (if any of these apply):
- Adding or changing a feature in existing code, where the goal and done criteria fit in one or two sentences
- Fixing a bug, especially when it needs root-cause tracing or checking other callers
- Refactoring, removing duplication, unneeded abstractions, or dependencies
- Deciding how to implement something, e.g. "add a library or write it ourselves?"
- Reviewing a diff or auditing the repo
- A vague request ("build me X") that risks being overbuilt

**Do it yourself** (do not delegate):
- One- or two-line edits, explanations, or answering questions
- Finding where code lives, or design with many interlocking decisions (in Claude Code: the Explore and Plan subagents)
- Scope must be agreed with the user first → ask, then delegate once it is settled
- The user asked for a full-featured version or several alternatives
- Irreversible actions such as deploys, deletions, or pushes

**In the delegation message, include**: goal / done criteria / out of scope / relevant files.
The subagent does not see this conversation; the message is all it knows.

**When it returns**, its edits are in the working tree and its return
reports Changed / Verified / Skipped / Shortcuts / Risks / needs checking, or
Info needed. Take the work over: check Changed against the diff and rerun
Verified yourself, carry on from there, and pass Verified, Skipped and Risks /
needs checking to the user as-is. On Info needed, ask the user those
questions with the subagent's most likely reading, then continue the same
subagent with the answers where the harness can (Claude Code: SendMessage to
the agentId its return ends with; Codex: followup_task to it; both work in a
resumed session), so it keeps its work and context; otherwise delegate again
with the answers and its return. Wait for its next return before taking the
work over.
