---
name: design-md
description: The file formats of DESIGN.md and PRODUCT.md, digested from Impeccable's document.md and init.md (4.5.2) so Impeccable can read what direction writes. Use when writing either file.
---

# DESIGN.md and PRODUCT.md formats

## DESIGN.md

At the project root. YAML frontmatter (normative tokens), then up to eight
markdown sections. Tokens are normative; prose says where and why to use them.

Frontmatter: only `name`, `description`, `colors`, `typography`, `rounded`,
`spacing`, `components`. No other top-level group (no `motion:`, `shadows:`,
`breakpoints:`).

```yaml
---
name: <project title>
description: <one-line tagline>
colors:
  primary: "#b8422e"        # key = descriptive slug; any CSS color, keep the incumbent notation
typography:
  display: { fontFamily: "...", fontSize: "clamp(2.5rem, 7vw, 4.5rem)", fontWeight: 300, lineHeight: 1, letterSpacing: "normal" }
rounded: { sm: "4px", md: "8px" }
spacing: { sm: "8px", md: "16px" }
components:
  button-primary: { backgroundColor: "{colors.primary}", textColor: "{colors.neutral-bg}", rounded: "{rounded.sm}", padding: "16px 48px" }
  button-primary-hover: { backgroundColor: "{colors.primary-deep}" }
---
```

- Token refs are `{group.key}`. Components may reference primitives;
  primitives never reference each other.
- Component props are only `backgroundColor`, `textColor`, `typography`,
  `rounded`, `padding`, `size`, `height`, `width`. Shadows, motion and focus
  rings go in prose.
- Keys keep the project's own names. Variants are sibling keys
  (`-hover`, `-active`). Only tokens actually reused.

Body sections, these exact headings in this order, irrelevant ones omitted:
`## Overview`, `## Colors`, `## Typography`, `## Layout`,
`## Elevation & Depth`, `## Shapes`, `## Components`, `## Do's and Don'ts`.

- Overview opens with `**Creative North Star: "..."**` and a
  `**Key Characteristics:**` bullet list.
- Colors grouped by role: Primary, Secondary, Tertiary, Neutral.
- Description first, exact value in parens ("gently curved edges (8px)"); no
  class names; never restate a token value differently from the frontmatter.
- One to three Named Rules per section: `**The [Name] Rule.** [doctrine]`.
- Strictly visual: nothing from PRODUCT.md repeated.

## PRODUCT.md

At the project root, facts only (inferred ones marked as assumptions);
irrelevant sections omitted; no visual direction.

```markdown
# Product

<!-- impeccable:product-schema 1 -->

## Platform
web | ios | android | adaptive

## Stack                       (greenfield only)
## Users
## Product Purpose
## Positioning
## Operating Context
## Capabilities and Constraints
## Brand Commitments
## Evidence on Hand            (state absences future work must not fabricate)
## Product Principles          (three to five, no visual recipes)
## Accessibility & Inclusion
```

Copy the schema comment verbatim.
