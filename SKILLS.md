# SKILLS.md

Agent skills available in this repository — what is installed, when it applies, and how to manage it.

A **skill** is a packaged set of instructions an agent loads on demand. Instead of carrying domain guidance in every prompt, the agent pulls in the relevant playbook when the task calls for it.

---

## Installed

### `ui-ux-pro-max`

Design intelligence for UI work — a searchable local dataset rather than a prose style guide.

| | |
|---|---|
| **Source** | [`nextlevelbuilder/ui-ux-pro-max-skill`](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) (GitHub) |
| **Location** | `.agents/skills/ui-ux-pro-max/` |
| **Entry point** | `SKILL.md` |
| **Pinned in** | `skills-lock.json` (SHA-256 integrity hash) |

**What it carries:** 79 searchable styles, 192 product palettes with reasoning profiles, 74 font pairings, 119 UX guidelines, 105 curated icons, 17 GSAP motion presets, 25 chart types and 22 technology stacks — held as CSV/JSON under `data/`, queried on demand instead of loaded wholesale.

**Its rules are ordered by priority**, so an agent knows what to fix first:

| Priority | Category | Why it comes first |
|---|---|---|
| 1 | Accessibility | 4.5:1 contrast, alt text, keyboard navigation, ARIA labels |
| 2 | Touch & interaction | 44×44px minimum targets, 8px spacing, loading feedback |
| 3 | Performance | Modern image formats, lazy loading, CLS < 0.1 |
| 4 | Style selection | Match the product type; stay internally consistent |
| 5 | Layout & responsive | Mobile-first, no horizontal scroll, never disable zoom |
| 6 | Typography & colour | 16px base, 1.5 line-height, semantic tokens over raw hex |
| 7 | Animation | Context-aware timing; always honour reduced-motion |
| 8 | Forms & feedback | Visible labels, errors beside the field |
| 9 | Navigation | Predictable back behaviour, deep linking |

#### When to use it here

Reach for it when the task changes how something **looks, feels, moves, or is interacted with** — designing or refactoring components, choosing colour/typography/spacing, reviewing for accessibility, or implementing animation and responsive behaviour.

Skip it for engine internals, store logic, build configuration, or anything non-visual.

#### How it lines up with this codebase

Several of its priorities are already load-bearing here, so follow the existing patterns rather than introducing parallel ones:

- **Reduced motion** — `controls.reducedMotion` already gates screen shake, ambient particles, `Tilt3D` and `ParallaxHero`. Any new animation must respect it.
- **Semantic colour tokens** — `src/styles.css` defines `honey`, `amber`, `moss`, `night` and the shadcn token set via Tailwind v4 `@theme inline`. Use those, not raw hex.
- **Redundant encoding** — `src/game/tierStyle.ts` encodes distance with colour *and* shape *and* glyph so it survives colour-blindness. Preserve that when touching indicators.
- **Touch targets** — the mobile sprint and interact buttons in `GameCanvas.tsx` are already sized past the 44px floor.

One deliberate deviation: the skill advises **SVG icons, never emoji**. This game uses emoji as item icons (`src/game/items.ts`) as a stylistic choice suited to a storybook cat game. Treat that as intentional.

---

## Managing skills

Skills live in `.agents/skills/<name>/` with a `SKILL.md` entry point whose YAML frontmatter carries `name` and `description`. The description is what an agent matches against when deciding whether a skill is relevant, so it should read as trigger conditions, not marketing.

`skills-lock.json` pins each skill to its source and a content hash:

```json
{
  "version": 1,
  "skills": {
    "ui-ux-pro-max": {
      "source": "nextlevelbuilder/ui-ux-pro-max-skill",
      "sourceType": "github",
      "skillPath": ".claude/skills/ui-ux-pro-max/SKILL.md",
      "computedHash": "d1de8ff8…"
    }
  }
}
```

Commit the lock file alongside the skill. The hash is what makes an update visible in review instead of silently changing agent behaviour.

### Adding a skill

1. Install it into `.agents/skills/<name>/`.
2. Confirm `SKILL.md` frontmatter describes **when** to use it, not just what it is.
3. Commit the skill and the updated `skills-lock.json` together.
4. Add a row to this file explaining how it interacts with this codebase's existing conventions.

### A note on trust

A skill is instructions an agent will follow. Third-party skills come from outside this repository, so review `SKILL.md` before installing, and treat the pinned hash as the thing that keeps a later upstream change from altering behaviour unnoticed.

---

## Related

- [AGENTS.md](./AGENTS.md) — architecture, commands, and the codebase-specific gotchas
- [CLAUDE.md](./CLAUDE.md) — Claude Code entry point
