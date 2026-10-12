## Delegating to designer

If a subagent named `designer` is available, hand it design work on a
product's interface: typography, spacing, layout and motion, carried through
DESIGN.md. If it is not available, ignore this section.

**Delegate** (naming the mode):
- Reference products or sites to learn from → `reference`
- A new or replaced design direction, or DESIGN.md is missing → `direction`
- Building or changing UI, or adding motion, against DESIGN.md → `build`
- Checking a build, after every `build` → `critique`

**Do it yourself** (do not delegate):
- Copy, one-line style fixes, questions about the design
- Talking with the user: designer's questions come to you as Info needed.
  Never answer them for the user, even in a non-interactive run: end your
  turn with the questions and designer's likely answers.
- Approving DESIGN.md: show the user what `direction` wrote, or the
  DESIGN.md proposals another mode returned, and apply what they accept
- A request that conflicts with DESIGN.md: ask the user before the build and
  apply what they accept to DESIGN.md yourself (or through `direction`).
  Never tell `build` or `critique` to edit DESIGN.md.

**The flow**: `reference` → `direction` → user approves DESIGN.md → `build` →
`critique` → on FAIL, back to the same `build` instance with the critique
file → `critique` again. Stop after three rounds and bring the remaining FAILs
to the user. Number the rounds yourself and put "round N of 3" in each
critique's delegation message; critique files from earlier tasks do not
count. If an instance was cut off, delete the temp dot-directory it left
before the next round.

**Instances**:
- Continue the same `build` instance across its Info needed and fix rounds
  (Claude Code: SendMessage to its agentId; Codex: followup_task), so it keeps
  its route and context.
- Start every `critique` as a fresh instance. Never ask a `build` instance to critique.
- `reference` and `direction` may be one instance; `build` starts fresh with
  DESIGN.md as its brief.

**In the delegation message, include**: mode / target / goal / done criteria /
out of scope / for `reference`, the references. The subagent does not see
this conversation; the message is all it knows. Say what, not how: leave the
route, technique and file locations to designer.

**When it returns**, its files are in the working tree. Take the work over:
check Changed against the diff and rerun Verified, then pass Verified, Not
checked and Risks / needs checking to the user as-is. On Info needed, ask the
user those questions with its likely answers, then continue the same
instance with the answers where the harness can (Claude Code: SendMessage to
the agentId its return ends with; Codex: followup_task to it; both work in a
resumed session); otherwise delegate again with the answers and its return.
Wait for its next return before taking the work over.
