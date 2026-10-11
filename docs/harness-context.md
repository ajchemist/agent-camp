# What a harness loads into its context, and how to keep it out

Each harness starts a session with three layers on top of its own system
prompt. This page records which file feeds each layer, and the flag or setup
that leaves each layer out. Every row was checked on this host (Claude Code
2.1.296, codex-cli 0.162.1, 2026-10-11) by asking a fresh headless session
whether a marker phrase from each file was in its context.

| layer | what it is |
|---|---|
| **settings** | permissions, hooks, MCP servers, user-level subagents |
| **user instructions** | read in every session, whatever the workspace |
| **repo instructions** | read only inside that repository |

On this host the user instructions are one file for both harnesses:
`~/.agents/AGENTS.md`. `~/.claude/CLAUDE.md` imports it (`@~/.agents/AGENTS.md`),
and `~/.codex/AGENTS.md` is a symlink to it.

## Claude Code

What loads by default:

| layer | files |
|---|---|
| settings | `~/.claude/settings.json` (user), `.claude/settings.json` (project), `.claude/settings.local.json` (local); subagents from `~/.claude/agents/` |
| user instructions | `~/.claude/CLAUDE.md` and what it imports |
| repo instructions | `CLAUDE.md`, and `AGENTS.md` even when there is no `CLAUDE.md` |

How to leave a layer out. `--setting-sources` picks the levels to load, and a
level brings its instructions with it:

| run | user instructions | repo instructions | also gone |
|---|---|---|---|
| `claude` | loaded | loaded | |
| `claude --setting-sources project,local` | **left out** | loaded | all of `~/.claude/settings.json` and `~/.claude/agents/`: curated agents, the user's allow/deny rules |
| `claude --setting-sources user,local` | loaded | **left out** | the project's `.claude/settings.json` |
| `claude --setting-sources ''` | left out | left out | every settings file |
| `claude --bare` | left out | left out | hooks, plugins, LSP, auto-memory; auth only via `ANTHROPIC_API_KEY` |

So Claude Code cannot leave out the user instructions alone: the curated
agents go with them. To silence one subagent instead, hide it:
`claude --disallowedTools "Agent(ponytail)"`.

## Codex

What loads by default:

| layer | files |
|---|---|
| settings | `$CODEX_HOME/config.toml` (default `~/.codex`), subagents from `$CODEX_HOME/agents/` |
| user instructions | `$CODEX_HOME/AGENTS.md` |
| repo instructions | `AGENTS.md` from the repository root down to the working directory (a run from a subdirectory still reads the root one) |

How to leave a layer out:

| run | user instructions | repo instructions | also gone |
|---|---|---|---|
| `codex` | loaded | loaded | |
| `codex -c project_doc_max_bytes=0` | loaded | **left out** | |
| `codex --ignore-user-config` | loaded | loaded | `config.toml` only (model, MCP, hooks); not an instruction switch |
| `CODEX_HOME=<copy without AGENTS.md> codex` | **left out** | loaded | nothing else |

Codex has no flag for the user instructions. A second `CODEX_HOME` does it
cleanly: a directory that links everything in `~/.codex` except `AGENTS.md`,
so auth, config, sessions and agents stay the same:

```sh
alt=~/.local/state/codex-home-bare; mkdir -p "$alt"
for f in ~/.codex/* ~/.codex/.[!.]*; do
  [ "$(basename "$f")" = AGENTS.md ] || ln -sfn "$f" "$alt/"
done
CODEX_HOME="$alt" codex
```

## Not checked yet

pi, omp, kimi and goose are installed by agent-camp but have not been probed
this way. Add a section once they are.

## Checking a harness yourself

Run a fresh headless session in the repository and ask, with no tools, whether
a phrase that occurs only in one file is in its context:

```sh
q='Without using any tools: does any instruction text in your context mention "<phrase from the user file>"? And "<phrase from the repo file>"? Answer exactly: user=YES|NO repo=YES|NO'
claude -p "$q" --model haiku < /dev/null
codex exec "$q" < /dev/null
```
