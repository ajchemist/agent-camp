# Curated agents: one source, one adapter per harness

Status: accepted (2026-10-09).

agent-camp ships **curated agents**: subagent profiles a harness can delegate to. The first is `ponytail`, a senior engineer that follows the skills of [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail).

- **One source, adapters per harness.** `curated-agents/<name>/` holds the description and the prompt; `curated-agents/default.nix` renders them into each harness's user-level agent dir: Claude Code `~/.claude/agents/<name>.md`, Codex `~/.codex/agents/<name>.toml` (`developer_instructions`), Kimi Code `~/.agents/agents/<name>.md` (with `${base_prompt}`, since Kimi replaces its default prompt). pi has no built-in subagents, so it has no adapter yet.
- **Skills are read, not installed.** The prompt names the upstream `SKILL.md` files by their Nix store path, and the agent reads them as files. Installed skills would also reach the main agent, and a skill that hides itself from the model (`disable-model-invocation`) cannot be preloaded into a Claude Code subagent either.
- **Pinned upstream.** `curated-agents/<name>/source.nix` pins the release's commit and hash (`fetchFromGitHub`). It is a pinned tool under ADR 0001: the briefing tracks it, an approved update ticket gets a bump PR from `ci/bump.py`.
- **Opt-out, per harness.** `agent-camp.curated-agents.<name>.enable` defaults to true. `.harnesses.<harness>` picks where it lands: claude and codex default to true, the rest to false.

## Considered options

- Installing the upstream as skills/plugins per harness: rejected, the skills would load into every session, not only the subagent.
- A local clone at a fixed path: rejected for the store path, which is pinned, absolute and needs no clone step.
- Per-harness copies of each agent (one repo or dir per harness, as in VoltAgent's collections): rejected, they drift. wshobson/agents and rulesync both converged on one source plus adapters.
