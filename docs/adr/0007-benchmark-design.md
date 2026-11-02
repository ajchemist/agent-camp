# Benchmark: baseline arm against curated arm, verdicts per tier

Status: accepted (2026-11-02). Decided in #22.

Nobody can say whether a curated agent beats a harness as it ships. Simple work may be done as well and more cheaply without it. The lab (ADR 0008) answers this with a benchmark whose verdicts decide which tiers the curated agent takes, and each harness's default model and effort for it.

- **Two arms per harness.** Every bench task runs under the baseline arm (the harness as shipped, empty home, no curated agent, no user-scope skills) and the curated arm (same harness, model, effort and brief, plus the curated agent). The only difference is our curation. Each arm runs three times per task, so run-to-run variance shows.
- **Verdicts per tier.** Bench tasks are tagged by tier (simple, standard, complex) and domain, and versioned; results are compared only within one version. A tier where the curated arm does not win, or wins too little for its cost, goes into the agent's "Do it yourself" rules through a human-judged PR. Promotion changes only a harness's own defaults, never routes work to another harness.
- **Gates before judging.** Deterministic gates (Impeccable detector, Lighthouse and accessibility, reduced motion) run first, so a broken build never reaches a vote. A run that does not finish or hits its cap counts as a loss.
- **Blind human pairwise judging.** The maintainer judges pairs with left and right randomized and recorded, ties allowed, arm names revealed only after a verdict, about 30 pairs per tier with about 15% hidden repeats to measure consistency.
- **LLM judge, earned.** A judge from the other model family than the arms' model judges each pair in both orders and keeps only consistent verdicts. Its verdicts count only once its agreement with the human verdicts clears a bar, and every promotion includes a share of human-judged pairs.
- **Holdout tasks.** Two bench tasks (one simple, one complex) are used only by promotion verdicts and stay private until judged. The improvement run sees the dev set only, so it cannot tune to the promotion test.
- **Decoy run first.** Before the first real benchmark, the baseline arm is compared with itself; the method must find no difference.
- **Spend decided before it happens.** Every paid benchmark is preregistered (hypothesis, metrics, stop rules, budget), dry-run, and piloted on three tasks with a cost table before approval. Caps per run, per bench and per month stop the work when reached, within an agreed share of the subscriptions; the numbers are set after the pilot.
- **Journal.** Every run is recorded with harness, model, effort, token use, wall time, each gate's result and the bench task version, so later questions are answered from the journal.
- **Matched budget.** When the curated arm first wins, one matched-token-budget comparison checks that the win is not just more compute. Quality against tokens is plotted per tier.
- **Public gallery.** Results by tier and domain, viewable by anyone; heavy originals stay in the lab.

## Considered options

- Comparing curated agent versions with each other only: rejected, it cannot show that curation beats the harness alone, the question that matters (a no-skill baseline has matched one of our upstreams in an outside report).
- One overall verdict: rejected, a win on complex work would hide a loss on simple work.
- LLM judge only: rejected, self-preference and position bias are real and its agreement with a human is unknown until measured.
- Human judging only: workable, but slow; the judge adds volume once it has earned trust.
- Public or crowd voting, a second human rater, more arms or leave-one-out ablation of upstreams: out of scope for now.
