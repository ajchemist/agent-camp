# Curated agents: one source, one adapter per harness

Status: accepted (2026-10-09).

agent-camp ships **curated agents**: subagent profiles a harness can delegate to. The first is `ponytail`, a senior engineer that follows the skills of [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail).

- **One source, adapters per harness.** `curated-agents/<name>/` holds the description and the prompt; `curated-agents/default.nix` renders them into each harness's user-level agent dir: Claude Code `~/.claude/agents/<name>.md`, Codex `~/.codex/agents/<name>.toml` (`developer_instructions`), Kimi Code `~/.agents/agents/<name>.md` (with `${base_prompt}`, since Kimi replaces its default prompt). pi has no built-in subagents, so it has no adapter yet.
- **Skills are read, not installed.** The prompt names the upstream `SKILL.md` files by their Nix store path, and the agent reads them as files. Installed skills would also reach the main agent, and a skill that hides itself from the model (`disable-model-invocation`) cannot be preloaded into a Claude Code subagent either. Claude Code gates reads outside the workspace (a headless `claude -p` refuses them), so while any curated agent goes to Claude Code the module adds `Read(//nix/store/**)` to `~/.claude/settings.json` (the whole store: read-only, and skill paths move with every bump), touching only the rules it added (tracked in `~/.local/state/agent-camp/claude-allow`).
- **Pinned upstream.** `curated-agents/<name>/source.nix` pins the release's commit and hash (`fetchFromGitHub`). It is a pinned tool under ADR 0001: the briefing tracks it, an approved update ticket gets a bump PR from `ci/bump.py`.
- **Work is taken over, not shuttled.** The subagent edits the main agent's working tree and returns a fixed report (Changed / Verified / Skipped / Shortcuts / Risks / Info needed). The main agent takes the edits over: it checks Changed against the diff, reruns Verified, and carries on. A question goes back as Info needed, and the main agent answers by continuing the same subagent (Claude Code `SendMessage`, Codex `followup_task`, also in a resumed session), so its work and context survive. Revised 2026-10-11, from headless runs in both harnesses (docs/curated-agent-workflow.md); before, a stop meant re-delegating from scratch.
- **Opt-out, per harness.** `agent-camp.curated-agents.<name>.enable` defaults to true. `.harnesses.<harness>` picks where it lands: claude and codex default to true, the rest to false.
- **Replacing built-ins, opt-in.** `.replaceBuiltins` also writes the agent under the name of each built-in coding subagent an adapter lists in `replaces` (kimi: `coder`, with `override: true`), keeping the built-in's description so delegation does not change. Read-only built-ins (explore, plan) are left alone.

## Considered options

- Installing the upstream as skills/plugins per harness: rejected, the skills would load into every session, not only the subagent.
- A local clone at a fixed path: rejected for the store path, which is pinned, absolute and needs no clone step.
- Per-harness copies of each agent (one repo or dir per harness, as in VoltAgent's collections): rejected, they drift. wshobson/agents and rulesync both converged on one source plus adapters.
