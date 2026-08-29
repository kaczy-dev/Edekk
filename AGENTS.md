# AGENTS.md

Canonical instructions for AI coding agents working in this repository.
Tool-specific entry points (`CLAUDE.md`, `SKILLS.md`) point here — keep the substance in this file.

---

## What this project is

**Przygody Edka** ("Edek's Adventures") — a 2D top-down exploration game about Edek, a smoke-grey Maine Coon cat, played across four hand-painted worlds: Salon, Ogród (garden), Strych (attic) and Dach nocą (roof at night).

The game renders to a single `<canvas>` driven by a hand-written engine; everything around it (HUD, menus, dialogs) is React.

> **All player-facing copy is Polish.** Level titles, quest labels, dialog, buttons and error screens are written in Polish. Match that when adding UI text. Code, comments and identifiers stay English.

---

## Commands

| Command | Purpose |
|---|---|
| `npm run dev` | Vite dev server (tries port 8080, falls back if taken) |
| `npm run build` | Production build — Vite → Nitro, targeting Cloudflare |
| `npm run typecheck` | `tsc --noEmit` |
| `npm run lint` | ESLint (flat config, Prettier runs as a lint rule) |
| `npm run format` | `prettier --write .` |

**Before declaring work done, run `npm run typecheck` and `npm run build`.** Both currently pass.

### Two caveats

- **`npm run preview` does not work.** The build emits a Nitro/Cloudflare bundle that `vite preview` cannot serve — it returns HTTP 500. Verify against `npm run dev` instead.
- **There is no test runner.** No Vitest/Jest/Playwright is configured and there is no `test` script. Do not write test files expecting them to run. `gameStore`, `questUtils` and `inventory.ts` are pure and would be the natural first targets if tests are added.

### Formatting

ESLint reports roughly **166 pre-existing Prettier errors** spread across the repo. They predate current work and are deliberately left alone so diffs stay reviewable. Do not run `npm run format` across the whole repo as a drive-by — it would bury real changes in whitespace noise. Match the surrounding style in files you touch.

---

## Architecture

### The two halves, and the seam between them

```
React (declarative)                    Engine (imperative, 60 fps)
──────────────────────                 ────────────────────────────
routes/poziom.$id.tsx
  └─ GameCanvas.tsx  ──── engineRef ──▶ GameEngine (game/engine.ts)
       │  events {onPickUp, onTalk,        │  update(dt) → physics, collision,
       │          onGoal, onDanger,        │              interaction, particles
       │          onEnergyDelta, …}        │  render(ctx) → camera, sprites,
       │         ▲                         │              particles, lighting
       ▼         └─────────────────────────┘
  useGameStore (Zustand + persist)
       │
       ├─▶ HUD.tsx, GoalArrows.tsx  ──▶ useGoalTracks() shared RAF hook
       └─▶ menu / settings / title routes
```

`GameCanvas` owns the engine instance in a ref and mutates it imperatively (`engine.paused`, `engine.difficulty`, `engine.input.touch`, …). The engine calls back into React through the `EngineEvents` object, which forwards to Zustand actions. **The engine never imports React and never touches the store directly** — keep it that way.

### `src/game/` — engine and domain logic

| File | Responsibility |
|---|---|
| `engine.ts` | `GameEngine`: RAF loop, movement, sliding collision, camera (dead-zone follow + look-ahead + zoom), gait/animation state, sprite and lighting caches |
| `input.ts` | `InputState`: keyboard + touch aggregation, sprint hold/toggle, edge-triggered interact |
| `types.ts` | Domain model — `LevelDef`, `LevelObject`, `QuestStep` (discriminated union), `ItemId` |
| `levels.ts` | The four levels as static data, plus `getLevel(id)` |
| `items.ts` | `ITEMS` registry — `Record<ItemId, ItemDef>`, so a missing item is a compile error |
| `questUtils.ts` | `computeQuests()` / `questCompletion()` — pure derivation of quest state plus actionable hints |
| `inventory.ts` | `NPC_GIFTS`, `giftObjId()`, `inventoryFromCollected()` — the single source of truth for NPC gift items |
| `proximity.ts` | Per-archetype "how close counts as arrived" radii (gate / chest / food / spot) |
| `tierStyle.ts` | Visual language for distance tiers, including a colour-blind-safe set with redundant shape + glyph |
| `goalTracking.ts` | `useGoalTracks()` — the one hook that smooths distance/direction to reach-quest goals |
| `particles.ts` | Pooled particle system: ambient drift, pickup sparkle, sting burst, paw dust |

### `src/store/gameStore.ts`

Zustand store persisted to `localStorage` under `edek-game-v1`. Holds settings (`controls`, `difficulty`, audio), progress (`levelProgress`, `unlockedLevels`, `talkedNpcs`), session state (`inventory`, `energy`) and the autosave `save` slot. `DIFFICULTIES` and `DEFAULT_CONTROLS` are exported and are the **only** place those numbers should live.

### Routes

File-based via `@tanstack/router-plugin`; `src/routeTree.gen.ts` is generated — never hand-edit it.

`/` title · `/menu` level select · `/poziom/$id` gameplay · `/ustawienia` settings · `/koniec` ending

### Build config

`vite.config.ts` delegates almost everything to `@lovable.dev/vite-tanstack-config` (a hosted preset bundling TanStack Start, React, Tailwind, Nitro, path aliases and error reporting). Build behaviour is therefore not fully auditable from this repo alone.

---

## Gotchas learned the hard way

These caused real bugs here. Read them before touching the engine/React seam.

### 1. Store selectors must return stable references

```ts
// ✗ Returns a NEW array whenever the key is missing. Any useMemo or useEffect
//   depending on it re-runs every render — this froze the game loop.
const talked = useGameStore((s) => s.talkedNpcs[level.id] ?? []);

// ✓ Share one frozen fallback.
const NO_IDS: string[] = [];
const talked = useGameStore((s) => s.talkedNpcs[level.id] ?? NO_IDS);
```

### 2. Keep the `level` object's identity stable

`getLevel()` returns the same object out of the `LEVELS` module every call. Do **not** return the level from a route loader — loader data is re-serialised, so the component would receive a fresh object each render and every downstream memo would invalidate. The loader validates and throws `notFound()`; the component calls `getLevel()` itself.

### 3. Clear image `onload` handlers on effect cleanup

A late-firing `img.onload` will happily start an engine for an already-unmounted effect, orphaning a RAF loop, an input listener set and an autosave interval that nothing can cancel. These stack up across HMR reloads and level changes. `GameCanvas` guards this with a `cancelled` flag **and** `img.onload = null`.

### 4. Never resample a large image per frame

The cat sprite is a 1024×1024 PNG drawn at ~67×118, and backgrounds are 1920×1080. Resampling those every frame at `imageSmoothingQuality: "high"` is enormously expensive. Bake oversized art into a correctly-sized offscreen canvas **once** (see `getCatCache`, `getLightSprite`) and blit with `"low"` smoothing in the loop.

**Measured budget** (dev, 1.64 MP canvas): `render()` ≈ 0.62 ms, `update()` ≈ 0.043 ms — about 4% of a 16 ms frame. If you add rendering work, re-measure against that.

### 5. Don't persist high-frequency state

`energy` changes several times a second, and every Zustand write serialises the whole store to `localStorage` synchronously. `persist` is configured with `partialize` to exclude `energy` and `inventory` — both are rebuilt by `startLevel()`. Keep new per-frame state out of the persisted slice.

### 6. Cross-file couplings that the compiler cannot check

Several features are linked by string, not by type. When renaming, grep for all of them:

- Quest `objId` values in `levels.ts` must match an object `id` in the same level.
- `proximity.ts` classifies goals by matching **whole words** in the object id (`gate`, `chest`, `bowl`, …) — the word-boundary split exists so a future id containing "box" is not read as a chest.
- NPC gifts are recorded as `"<npcObjectId>-gift"`; only `inventory.ts` knows that convention.

---

## Conventions

- **TypeScript is `strict`.** No `any`. Narrow discriminated unions with a type guard (`isReachQuest` in `goalTracking.ts`) rather than casting — note that `.filter()` does not narrow, and narrowing is lost inside callbacks.
- **Unused-code detection is currently off** (`noUnusedLocals`, `noUnusedParameters` and `@typescript-eslint/no-unused-vars` are all disabled). Nothing will warn you about dead code — three fully-unused modules accumulated this way. Clean up after yourself.
- **Path alias:** `@/` → `src/`.
- **Styling:** Tailwind v4, configured CSS-first in `src/styles.css` via `@theme inline`. Use the semantic tokens (`honey`, `amber`, `moss`, `night`, `card`, `border`) instead of raw hex.
- **Fonts** (Fraunces, Plus Jakarta Sans) load via `<link>` in `__root.tsx`, *not* `@import` in CSS — a CSS `@import` must precede every other rule and would otherwise land after Tailwind's expansion and fail to build.
- **Respect `controls.reducedMotion`.** It already gates screen shake, ambient particles, `Tilt3D` and `ParallaxHero`. Event feedback (pickup sparkle, sting burst) deliberately stays on so information is not lost.
- **Accessibility:** distance tiers encode meaning with colour *and* shape *and* glyph (`tierStyle.ts`). Preserve that redundancy.

---

## Working agreements

- Verify UI changes in a real browser on `npm run dev` — a passing build says nothing about whether the game is playable.
- When investigating performance, **measure before changing anything.** Two rounds of plausible-sounding optimisation here fixed nothing because the actual cost was elsewhere.
- Remove diagnostic instrumentation before finishing. Temporary flags left in `engine.ts`/`GameCanvas.tsx` can silently disable the game.
- `git status` in this repo often shows unrelated pre-existing modifications. Do not sweep them into a commit.
