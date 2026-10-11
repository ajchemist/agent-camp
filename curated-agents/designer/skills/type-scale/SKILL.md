---
name: type-scale
description: Build or rebuild a typography scale as DESIGN.md tokens - survey the sizes in use, pick a ratio, map semantic roles, make the large steps fluid with clamp(), and check the extremes. Use when DESIGN.md's typography is missing, inconsistent, or being replaced.
---

# Type scale

The output is DESIGN.md's `typography` frontmatter tokens and its
`## Typography` section, not CSS. `build` turns the tokens into code.

## 1. Survey (skip for a greenfield surface)

List every font size, line height, weight and letter spacing in use, with how
often each appears (grep the styles, or computed styles from a render).
Cluster near-duplicates (15px / 15.2px / 0.95rem are one step). The clusters
are the incumbent scale; the outliers are drift to remove. Keep the survey in
the return as evidence.

## 2. Ratio and base

- **Base:** body size. 16px unless the design read says otherwise; 17-18px
  for reading-heavy surfaces, 14-15px for dense operational UI.
- **Ratio** from the dials and the surface: dense UI 1.125-1.2; product and
  editorial 1.2-1.25; marketing and expressive 1.25-1.333; display-led
  landing 1.333-1.5 (only for the display steps, see 4).
- Snap the computed steps to whole pixels (or quarter rems). An incumbent
  step within 1px of a computed one wins over the math.

## 3. Roles, not sizes

Name tokens by role, never by size: `display`, `headline`, `title`,
`body`, `body-sm`, `label`, `caption`, `code`. Five to eight roles; a role
nobody uses is deleted. Each role carries `fontFamily`, `fontSize`,
`fontWeight`, `lineHeight`, `letterSpacing` (the DESIGN.md token schema).

- Line height falls as size grows: body 1.45-1.6, titles 1.2-1.3, display
  1.0-1.1.
- Tracking tightens as size grows (display around -0.02em) and opens for
  small caps and labels (+0.02 to +0.06em). Follow the typeface's optical
  sizing where it has one.
- Weight contrast carries hierarchy as much as size; at most three weights.

## 4. Fluid steps

Only the steps above `title` scale with the viewport:
`clamp(<min>, <preferred>, <max>)` with the preferred value in `vw + rem`
(never bare `vw`, which ignores user zoom).

Check each clamp at 320px and 1440px viewports:
- min ≥ the next smaller role's size + one step (hierarchy holds on phones)
- max keeps a display line within the measure the layout gives it
- the rem part keeps 200% browser zoom growing the text

Body and smaller stay fixed.

## 5. Check

- Measure: body lines 45-75 characters in the main column.
- Contrast between adjacent roles is visible at a glance; two roles that look
  the same merge into one.
- Every token in DESIGN.md is used by at least one component, and every size
  in the survey maps to a token or is listed as drift to remove.

Write the ratio, base and the clamp checks into `## Typography` so a later
change can follow the same reasoning.
