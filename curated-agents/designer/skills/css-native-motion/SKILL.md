---
name: css-native-motion
description: Build web motion with the platform alone (transitions, keyframes, @starting-style, view transitions, scroll-driven and scroll-triggered animation), each behind @supports with a static fallback. Use for landing and marketing surfaces, or any surface that should ship no motion runtime.
---

# CSS-native motion

The default route for landing and marketing pages: no runtime, and a browser
that lacks a feature shows the static page. Decide *whether* and *how* a thing
moves with Emil's `animate` first; this skill is only the *how in CSS*.

## Pick the mechanism

| the motion | mechanism |
|---|---|
| state change on one element (hover, open, toggle) | `transition` on transform / opacity |
| element appears (inserted, `display: none` → shown, popover, dialog) | `transition` + `@starting-style`, with `transition-behavior: allow-discrete` for `display` / `overlay` |
| one view replaced by another, same page (tabs, filters, list reorder) | same-document view transition: `document.startViewTransition()` + `view-transition-name` |
| page to page navigation (MPA) | cross-document view transition: `@view-transition { navigation: auto; }` in both pages |
| progress tied to scroll position (progress bar, parallax, scrub) | scroll-driven: `animation-timeline: scroll()` / `view()` + `animation-range` |
| plays once when scrolled into view, then runs on its own clock (reveal) | scroll-triggered: `timeline-trigger` + `animation-trigger` |
| pin, scrub sequences across sections, SplitText, physics | not CSS: route to GSAP |

Scroll-driven and scroll-triggered are different things. Scroll-driven has no
duration: scrolling back reverses it, stopping freezes it. Scroll-triggered
is time-based: once the threshold is crossed the animation plays out at its
own duration. A reveal is scroll-triggered; do not fake it with a short
`animation-range`, which stalls half-faded when the user stops scrolling.

## Rules

1. **Gate every non-baseline feature** with `@supports` and write the static
   state first. Outside the gate the element is fully visible and in place;
   a reveal never starts from `opacity: 0` outside `@supports`.
   ```css
   .reveal { /* final state: visible, in place */ }
   @supports (timeline-trigger: view()) {
     @media (prefers-reduced-motion: no-preference) {
       .reveal { /* trigger + initial state + animation */ }
     }
   }
   ```
2. **Reduced motion.** Movement lives inside
   `@media (prefers-reduced-motion: no-preference)`. Under `reduce`, keep
   opacity changes if they carry meaning, drop translation, scale and parallax.
   For view transitions, set `::view-transition-group(*) { animation: none; }`
   under `reduce`, or skip `startViewTransition`.
3. **Animate only `transform`, `opacity`, `filter`, `clip-path`.** Anything
   that triggers layout (width, height, top, margin) is out; use a view
   transition or FLIP instead.
4. **Curves and durations come from DESIGN.md's Motion section** as custom
   properties (`--ease-out`, `--dur-fast`), never literals scattered through
   rules. A spring that DESIGN.md calls for becomes a `linear()` easing
   generated once and stored as a token.
5. **View transitions:** name only what should morph (`view-transition-name`
   unique per page at the moment of capture); the rest cross-fades.
   Keep the default cross-fade short. Feature-detect the JS API:
   `if (!document.startViewTransition) { update(); return; }`.
6. **Scroll-driven:** set `animation-duration: auto` (or leave it unset with
   the shorthand) and `animation-fill-mode: both`; name ranges explicitly
   (`animation-range: entry 0% cover 40%`). A scroll timeline on the root
   scroller animates with the page; one on a nested scroller needs that
   scroller to be the nearest ancestor scroll container or a named
   `scroll-timeline`.
7. **No scroll hijacking.** Native CSS never needs to stop the user's scroll;
   if the design does, it is the GSAP route and the decision goes in the return.

## Browser support

Support moves faster than this file. Snapshot as of 2026-10 (secondary
sources, partly conflicting): same-document view transitions are Baseline
(Firefox 144); cross-document view transitions in Chromium and Safari,
Firefox in progress; scroll-driven animations in Chromium and Safari 26,
Firefox behind a flag; scroll-triggered animations in Chromium only
(Chrome 145/146). `@starting-style` and `transition-behavior` are Baseline.

When the delegation message or DESIGN.md names a browser range, check the
feature on MDN's compatibility table before relying on it, and say in the
return which features fall back in which browsers.

## Verify

- Render with the feature on, in a browser without it (or with the
  `@supports` block removed), and with `prefers-reduced-motion: reduce`.
  All three must look finished.
- Capture frames of each motion (start, middle, end) and compare against the
  DESIGN.md timings.
