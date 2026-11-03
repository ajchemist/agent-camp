---
name: critique
description: How critique judges a rendered build, digested from Impeccable's critique.md and audit.md (4.5.2) for a single context with no user to ask. Use in critique mode instead of those two playbooks.
---

# Critique

Three passes in this order, so the detector does not anchor the design
judgment. Every pass judges the whole build, from the render first and the
source second.

## 1. Design review (write it down before step 2)

- **Specificity verdict**: is the composition, interaction and visual
  language grounded in this product, or could an unrelated product use it
  unchanged? Name the interchangeable choices.
- **Against DESIGN.md**: each section (tokens, type, layout, motion, Do's and
  Don'ts) honoured or breached, with the element and the value.
- **Nielsen's ten heuristics**, 0–4 each (4 is rare; most real pages total
  20–32 of 40): visibility of status, match to the real world, user control,
  consistency, error prevention, recognition over recall, flexibility,
  aesthetic and minimalist design, error recovery, help. On landing pages and
  portfolios, flexibility and help may be `n/a` with a one-line reason; total
  over the applicable maximum (24/32), band by percentage: 90% excellent,
  70% good, 50% acceptable, 30% poor, below critical.
- **Cognitive load**: any decision point with more than four visible options;
  what the reader must remember across views.
- **Emotional journey**: the peak and the end, valleys, reassurance at
  high-stakes moments.
- **Personas**: two or three that fit the surface (power user, first-timer,
  accessibility-dependent, stress tester, distracted mobile user); for each,
  the exact elements that fail them on the primary action.

## 2. Detector

`impeccable detect --json <markup files or dir>` (not CSS-only files; exit 0
clean, 2 findings). Verify each finding in context; mark false positives.

## 3. Technical checks

- **Accessibility**: contrast below 4.5:1 (3:1 large text), missing names,
  roles or states, focus indicators and tab order, heading order and
  landmarks, alt text, form labels; reduced motion keeps state and hierarchy
  instead of a global kill, and nothing flashes or blocks reading.
- **Performance**: animated layout properties, unbounded blur or shadow,
  `will-change` left on at rest, layout reads in loops, heavy unused imports.
- **Theming**: hard-coded values beside tokens, a broken dark theme.
- **Responsive**: fixed widths, horizontal scroll at narrow width, touch
  targets under 44×44px, drag surfaces that fight page scroll, text that
  breaks the layout when enlarged.

## Report

Synthesize, do not concatenate: say where review and detector agree, what
the detector caught that the review missed, and what it got wrong.

- Specificity verdict, the heuristics table with total and band, two or three
  strengths.
- Three to five priority issues, each: P0 blocking · P1 major or a WCAG AA
  breach · P2 minor, workaround exists · P3 polish; what, why it matters to
  the user, the concrete fix, and floor or taste.
- Minor observations, one line each.

No questions to the user, no recommended commands, no snapshot or trend.
