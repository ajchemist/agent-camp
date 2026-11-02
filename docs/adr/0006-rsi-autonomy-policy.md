# RSI autonomy policy: autonomy by kind of work

Status: accepted (2026-11-02). Decided in #22.

A private lab repository (`ajchemist/agent-camp-lab`, ADR 0008) watches agent-camp and does the repetitive work of keeping curated agents good: following upstream drift, improving prompts and skills, trying new methods. How far it may go without a human depends on the kind of work, not on the run that does it:

- **Upstream drift bump: merges itself.** An update ticket for a curated agent's upstream leads the lab to bump it and rerun the affected tiers (ADR 0007). If every gate passes and the curated arm is no worse than before, the lab merges the bump PR and closes the ticket. A failed gate or a regression falls back to waiting for a human.
- **Prompt, delegation rules or own skills: PR, human verdict.** A change to what agent-camp itself writes becomes a PR that carries its benchmark results and waits for a maintainer's verdict.
- **Adding or retiring an upstream, or a new method: research issue only.** The lab opens an issue and writes no code. Code follows once the issue is `approved` (ADR 0002). Retiring goes through the same path as adding.
- **Supersession, narrow.** The first row supersedes ADR 0001's "Nothing auto-merges" and ADR 0002's approval gate for lab-opened drift bumps of curated agents' upstreams only. Every other pinned tool, and every bump opened by anyone else, keeps both rules.
- **No back door.** The lab's PRs go through agent-camp's public CI and gate like anyone's.
- **Policy lives in the lab, enforced by the lab.** One table in the lab maps a kind of work to its autonomy, and the lab's code applies it before acting. Prompts do not carry the policy, so changing autonomy is one change in one place.

## Considered options

- Nothing auto-merges, as in ADR 0001: rejected for drift bumps, where the gates and the rerun benchmark check more than a human reading a version diff would. Kept for everything else.
- One autonomy level for all lab work: rejected. Full autonomy would let the lab tune the agent to the benchmark and adopt upstreams unreviewed; none would leave the toil where it is.
- The policy written into each run's prompt: rejected, a model may misread or ignore it, and a change would have to reach every prompt.
