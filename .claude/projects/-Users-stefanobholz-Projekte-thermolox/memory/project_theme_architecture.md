---
name: EVERLOXX 2.0 Theme CSS Architecture
description: How the three CSS files work together — base.css for Dawn/typography, everloxx-header.css for layout/components, everloxx-animations.css for scroll effects
type: project
---

EVERLOXX 2.0 live theme (#195686924629) uses three CSS layers:

1. **base.css** — Dawn theme base + typography (Playfair Display headings, Montserrat body, opacity/font-size improvements). DO NOT add !important overrides here.

2. **everloxx-header.css** — Header layout (grid, search bar, nav), cx-* components (marquee, cards, CTA, stats, tags, steps, USP), section spacing, card hovers, footer, dark section colors. Has ~53 !important rules for header layout (necessary to override Dawn). The "Global Typography System" block (body/h1-h6/p overrides) was REMOVED to avoid conflicts with base.css.

3. **everloxx-animations.css** — Scroll reveal system (cx-reveal/cx-visible), staggered children, counter animation, parallax, 3D lift hover. Triggered by IntersectionObserver script in theme.liquid.

**Why:** The typography block in everloxx-header.css (body 18px !important, h1-h6 !important) conflicted with base.css font settings. Removing it keeps readability intact while preserving all layout/component styles.

**How to apply:** When modifying typography, edit base.css. When modifying layout/components, edit everloxx-header.css. Never add global element overrides (body, h1-h6, p) to everloxx-header.css.
