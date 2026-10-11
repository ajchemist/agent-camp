# Workflow: from an upstream skill set to a curated agent that gets used

How `ponytail` went from an upstream repository to a subagent that both Claude
Code and Codex actually delegate to. Follow the same steps for the next curated
agent. The design itself is [ADR 0003](adr/0003-curated-agents.md).

A curated agent has two halves, and each one needs its own text:

| half | file | says | seen |
|---|---|---|---|
| the subagent | `curated-agents/<name>/prompt.md` + `description` | **what** it does and **how it reports** | prompt: by the subagent; description: by the main agent, in every session, as one line in its list of subagents |
| the delegation rules | `curated-agents/<name>/delegation.md`, pasted into a repository's `AGENTS.md` | **when** the main agent hands work over, what to send, what to do with the report | by the main agent, in that repository |

The description alone does not get the agent used. With the same task
("add `div(a, b)`, `ValueError` on zero, with tests") and the agent installed,
neither harness delegated when `AGENTS.md` had no delegation rules, and both
did once it had them (2026-10-11). The two texts are not duplicates: the
description advertises, the rules decide. Keep the description to one line of
scope; put the policy in the rules.

## 1. Learn what the upstream covers

1. Open <https://gitingest.com>, ingest the upstream repository
   (`DietrichGebert/ponytail`), and **Copy all**.
2. Paste it into a chat with this request:

   > Let's list what the XXX repository handles well and what it covers.
   > I am designing a subagent that carries these skills by default, and I
   > want to write the instructions that tell the main agent which work to
   > delegate to it.

3. The answer gives two things: the coverage (which becomes the description
   and the skill routing in `prompt.md`) and a first draft of the delegation
   rules: delegate / do it yourself / what to send / what to do on return.

## 2. Ship the subagent

`curated-agents/<name>/`: `source.nix` pins the upstream, `default.nix` holds
the description, `prompt.md` routes to the skills. Register it in
`curated-agents/default.nix`, run `nix flake check`, switch.

## 3. Put the rules in a repository and watch a real run

Paste `delegation.md` into the test repository's `AGENTS.md`, give a plain task
that does **not** mention the agent, and run both harnesses headless:

```sh
t='<a task that fits the "Delegate" list>'
codex exec -C repo -s workspace-write --json "$t" < /dev/null > codex.jsonl
(cd repo && claude -p "$t" --output-format stream-json --verbose \
  --permission-mode acceptEdits < /dev/null > claude.jsonl)
```

To test a changed `prompt.md` before switching, put it at project scope in the
test repository (`.claude/agents/<name>.md`, with `@SKILLS@` replaced by the
store path): project agents take precedence over `~/.claude/agents`. In `-p`
runs, allow the test command on the command line
(`--allowedTools 'Bash(<test cmd>:*)'`), or Verified comes back "not run"; an
allow rule in the test repository's `.claude/settings.json` was not applied
(2026-10-11).

Check, for each harness:

| question | codex | claude |
|---|---|---|
| delegated? | a new rollout in `~/.codex/sessions/<date>/` with `"agent_role":"<name>"` | an `Agent` tool call with `"subagent_type":"<name>"` |
| did the subagent read its skills? | `"cmd":"cat /nix/store/…/SKILL.md"` in that rollout | a `Read` of the store path that was not refused |
| did it follow the repository's `AGENTS.md`? | the diff | the diff |
| did the main agent review the result? | its own `git diff` / test run after the subagent returned | the same |

Run the same task once **without** the rules too. That baseline is what shows
whether the rules, not the description, made the difference.

## 4. Reconcile the two halves

Read the delegation rules against `prompt.md` and the run logs. Everything the
rules expect from the subagent must be something the subagent is told to do.
For ponytail this pass found:

- The rules handled "Skipped", "Risks / needs checking" and "Info needed", but
  `prompt.md` only asked for "what you changed and what you did not check".
  The main agent papered over it, and "Info needed" could never happen.
  `prompt.md` now defines the sections and when to stop with "Info needed".
- Claude Code refused the subagent's read of its skills in a headless run, so
  it worked without them and said so in its report. The module now allows reads of
  `/nix/store` in `~/.claude/settings.json`.
- An installed copy of the upstream as a skill (`~/.codex/skills/ponytail`)
  made the main agent load the skill itself before delegating. It had to go:
  the skills belong to the subagent alone (ADR 0003).
- The rules named Claude-only subagents (Explore, Plan), and the rules apply
  only where the agent exists. `delegation.md` now opens with "if a subagent
  named `<name>` is available".

- A proposed rewrite of `prompt.md` restated the upstream `SKILL.md` in
  summary form and dropped the instruction to read it. Only its
  subagent-specific parts were kept (checking the handoff, staying in scope,
  no irreversible commands, the Verified and Shortcuts sections); what the
  skill already says stays in the skill. Also add what a skill written for a
  person gets wrong for a subagent: its closing lines and level switches.

Rerun step 3 after each fix, and once with a task that should end in
Info needed: tell the main agent to delegate it verbatim, so the subagent's
stop, not the main agent's own question, is what gets tested. After the
answer, check that the main agent continued the same subagent (Claude Code: a
`SendMessage` to it, not a second `Agent` call) and took its work over.
Answer with `claude -p --resume <session-id> "<answers>"` and look for
`"resumedAgentId"` in the SendMessage result. The continued subagent runs in
the background, so the stream has two `result` events; the takeover (the main
agent's own `git diff` / test run) comes after the first one.
