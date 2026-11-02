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
- Public or crowd voting, a second human rater or leave-one-out ablation of upstreams: out of scope for now.

## Amendment (2026-11-02): what makes an arm worth keeping, and candidates

The benchmark exists so that we never choose a path that spends more tokens for worse output. A path that costs more is worth keeping when its quality has a floor and keeps rising with improvement iterations.

- **Verdict rule.** An arm is promoted, or kept, only if three things hold:
  - it is not dominated (more tokens for equal or lower quality);
  - it clears the quality floor;
  - its learning curve rises.

  Higher token use is acceptable when all three hold.
- **Quality floor.** Two checks, both on every trial:
  - every deterministic gate passes on all three trials (pass^3);
  - the worst of the three trials does not lose a pairwise verdict to the baseline arm's median trial.

  An absolute rubric score may be added later.
- **Learning curve.** Each bench task version has an anchor: frozen baseline arm outputs from the first run. After every improvement iteration, the win rate against the anchor is measured per tier and plotted against the iteration count.
- **Stalled or failing paths.** An arm that is dominated, misses the floor, or whose curve has not risen after 3 improvement iterations gets a PR that routes the tier to the baseline arm. That PR waits for the maintainer's verdict. A candidate in that state is marked for retirement.
- **Candidates.** Besides the incumbent (the curated agent agent-camp ships), the lab runs up to 2 candidates, other ways of building the same agent, which live only in the lab. The baseline arm and the incumbent always run.
  - Candidates are compared with the incumbent at equal improvement-iteration counts, by overlaying learning curves. A new candidate first gets 3 improvement iterations.
  - Human judging goes to the incumbent against the best candidate. The other comparisons rely on the earned LLM judge.
  - A candidate that beats the incumbent, clears the floor and has a rising curve gets a replacement PR. Replacement follows ADR 0006's third row (research issue, `approved`).
- **Intake.** The maintainer feeds the lab methodology notes through an issue form labelled `intake` in the lab. The lab triages each note: it improves a candidate, proposes a new candidate (research issue, `approved`), or is declined with a reason.
