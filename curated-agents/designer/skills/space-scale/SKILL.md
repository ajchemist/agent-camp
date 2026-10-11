---
name: space-scale
description: Build or rebuild a spacing scale as DESIGN.md tokens - survey the gaps in use, pick a base unit and progression, map semantic roles for component and layout spacing, make section spacing fluid, and check density against the dials. Use when DESIGN.md's spacing is missing, inconsistent, or being replaced.
---

# Space scale

The output is DESIGN.md's `spacing` frontmatter tokens and the spacing rules
in `## Layout`. `build` turns them into code.

## 1. Survey (skip for a greenfield surface)

List every padding, margin, gap and inset value in use, with counts. Cluster
near-duplicates. Note where the same relationship (card padding, label to
field, section to section) uses different values: that is the drift the scale
must remove.

## 2. Base and progression

- **Base unit:** 4px for dense UI, 8px otherwise. Every token is a multiple
  of the base.
- **Progression:** linear at the small end, geometric at the large end, e.g.
  4, 8, 12, 16, 24, 32, 48, 64, 96, 128. Steps closer than about 1.25x apart
  above 16px are indistinguishable; drop one.
- The type scale's line height should land on the base (a 24px body line on
  an 8px base) so text and boxes share a rhythm.

## 3. Two layers of tokens

- **Primitive:** `space-1` … `space-10` (the progression).
- **Semantic roles** referring to primitives: `inset-control` (inside buttons
  and inputs), `inset-card`, `gap-inline` (icon to label), `gap-stack`
  (elements in a group), `gap-group` (between groups), `gutter` (grid),
  `section` (between page sections). Components use roles, never primitives.

Proximity carries grouping: the space inside a group is clearly smaller than
the space between groups (at least one step, usually two).

## 4. Density and fluid spacing

- `VISUAL_DENSITY` from the dials shifts the roles, not the primitives: dense
  maps `inset-card` and `gap-group` one step down, airy one step up.
- Only `section` and `gutter` scale with the viewport, with `clamp()` in
  `vw + rem`; check them at 320px and 1440px. Component spacing stays fixed.

## 5. Check

- Every spacing value in the code after `build` is a token; the survey's
  drift is gone.
- Squint test on a render: groups read as groups, sections as sections.
- At 320px nothing touches the viewport edge (gutter ≥ 16px) and nothing
  scrolls horizontally.

Write the base, progression and role map into `## Layout`.
