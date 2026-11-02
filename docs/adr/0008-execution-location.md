# Subscription tokens run only in the private lab, in a fresh container per job

Status: accepted (2026-11-02). Revises #22's "fresh Proxmox VM per job".

The benchmark (ADR 0007) and the self-improvement loop (ADR 0006) run harnesses on the maintainer's subscriptions: a Claude Code OAuth token (`claude setup-token`, one year) and a Codex `auth.json`. Where they run decides who can see those tokens.

- **Private lab only.** Anything that uses a subscription token runs only in the private repository `ajchemist/agent-camp-lab`, on the maintainer's two existing self-hosted runner VMs (Proxmox, `github-runner-a520elite` and `github-runner-z170e6`). The lab is registered on them at repository scope, and public repositories are not enabled there, so no public or fork job reaches them. The VMs run one job at a time and reach only the internet, not the LAN or tailnet. agent-camp's public workflows (briefing, bump hashes, gate, CI) stay as they are and do only deterministic work.
- **A fresh container per job.** Each job runs the harness in a new Docker container, removed with its volumes at job end. Nothing from the maintainer's Mac home is mounted.
- **Credentials as lab secrets.** The Claude token and the Codex `auth.json` are encrypted Actions secrets of the lab repository, injected only into that container. They never appear in agent-camp's workflows or logs.
- **Codex auth survives rotation.** Codex refreshes `auth.json` about every 8 days. The job writes the refreshed file back to the lab's secret, and a concurrency group keeps Codex jobs from running at the same time.
- **The lab polls.** The lab reads agent-camp's issues and labels on a schedule. agent-camp uses no `repository_dispatch` and holds no token for the lab.
- **Narrow writes.** The lab writes through a GitHub App limited to issues, pull requests and contents on agent-camp, plus secrets on the lab repository only (for the `auth.json` write-back).
- **Accepted risk.** The runner VMs and their runner user are shared with jobs from the maintainer's six private organizations. One job at a time is scheduling, not isolation, so a token is only as safe as every job those scopes run. The maintainer accepts this because all of them are the maintainer's own private repositories.

## Considered options

- A fresh Proxmox VM per job (the #22 plan): the strongest isolation, but it needs Proxmox API automation and VM templates that do not exist yet. It may replace the shared runners later.
- The shared runners with a fresh container per job: chosen.
- GitHub-hosted runners on the public repository: rejected. A refreshed token is a new value that secret masking does not know, so it can appear unmasked in a public log; and OpenAI advises against ChatGPT login on public repositories.
- A self-hosted runner on the public repository: rejected, a fork PR could run code on it.
- The maintainer's Mac: rejected, a job would run next to the maintainer's own keys and sessions, and only while the Mac is up.
