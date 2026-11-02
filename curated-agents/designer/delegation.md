## Delegating to designer

**On or off**: the line `curated-agents: designer off` in the repository's
AGENTS.md switches this section off, and `curated-agents: designer on`
switches it on. Without either line, it is on where this section is in the
repository's AGENTS.md or agent-camp installed designer `global`, and off
elsewhere. A session-start notice that says not to delegate to designer wins
over both.

If a subagent named `designer` is available, hand it design work on a
product's interface: typography, spacing, layout and motion, carried through
DESIGN.md. If it is not available, ignore this section.

**Delegate** (naming the mode), scaled to the work:
- Simple work (a component, a fix, a change that fits the existing styles) →
  one `build`, which ends with its own check pass. No `direction`, DESIGN.md,
  PRODUCT.md or `critique`.
- Reference products or sites to learn from → `reference`
- No design to follow (no DESIGN.md, and the brief and existing page do not
  settle it), or a replaced design direction → `direction`
- Building or changing UI, or adding motion → `build`
- Checking complex or motion work, after its `build` → `critique`

**Do it yourself** (do not delegate):
- Copy, one-line style fixes, questions about the design
- Talking with the user: designer's questions come to you as Info needed.
  Pass them to the user only when they are a real gap: the goal is missing or
  contradicts the done criteria. Those you never answer for the user, even
  in a non-interactive run: end your turn with the questions and designer's
  likely answers. A question the brief or repository already answers is no
  gap: continue the same instance with that answer, and list it as an
  assumption in your final answer.
- Never stop to ask after any mode on a complete brief or in a
  non-interactive run: not to approve what `direction` wrote, not to choose
  among options. Its likely answers go under Risks, listed as assumptions in
  your final answer, and the work goes on to a `build`. Only in an
  interactive run whose brief left the design open, show the user what
  `direction` wrote, or the DESIGN.md proposals another mode returned, and
  apply what they accept.
- A request that conflicts with DESIGN.md: ask the user before the build and
  apply what they accept to DESIGN.md yourself (or through `direction`).
  Never tell `build` or `critique` to edit DESIGN.md.

**The flow**: simple work is one `build`. Complex work: `reference` (when
there are references) → `direction` (when there is no design to follow) →
`build` → `critique` (complex or motion work). One critique round, unless it
finds a floor defect: then back to the same `build` instance with the
critique file → `critique` again, and stop there; bring remaining FAILs to
the user. Taste FAILs are advisory: pass them on, do not loop on them. Put
"round N of 2" in each critique's delegation message; critique files from
earlier tasks do not count. If an instance was cut off, delete the temp
dot-directory it left before the next round.

**Instances**:
- Continue the same `build` instance across its Info needed and fix rounds
  (Claude Code: SendMessage to its agentId; Codex: followup_task), so it keeps
  its route and context.
- Start every `critique` as a fresh instance. Never ask a `build` instance to critique.
- `reference` and `direction` may be one instance; `build` starts fresh with
  DESIGN.md (or, where the brief allowed no DESIGN.md, `direction`'s Design
  decisions) as its brief.

**In the delegation message, include**: mode / target / goal / done criteria /
out of scope / for `reference`, the references / what the brief permits, in
its words (a library it allows is approved; the files it allows bound where
DESIGN.md and PRODUCT.md may go). The subagent does not see
this conversation; the message is all it knows. Say what, not how: leave the
route, technique and file locations to designer.

**When it returns**, its files are in the working tree. Take the work over:
check Changed against the diff and rerun Verified, except renders: designer's
one browser check is the render, and what it could not render stays Not
checked. Pass Verified, Not checked and Risks / needs checking to the user
as-is. On Info needed, ask the
user those questions with its likely answers, then continue the same
instance with the answers where the harness can (Claude Code: SendMessage to
the agentId its return ends with; Codex: followup_task to it; both work in a
resumed session); otherwise delegate again with the answers and its return.
Wait for its next return before taking the work over.
