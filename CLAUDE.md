# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Start here

**[AGENTS.md](./AGENTS.md) is the canonical guide** — commands, architecture, conventions, and a "gotchas learned the hard way" section covering the bugs that have actually bitten in this codebase. Read it before making changes. This file only adds what is specific to Claude Code.

## Quick reference

```bash
npm run dev        # Vite dev server (port 8080, falls back if taken)
npm run typecheck  # tsc --noEmit
npm run build      # Vite → Nitro (Cloudflare target)
npm run lint       # ESLint; Prettier runs as a lint rule
```

`npm run preview` is broken (the Nitro bundle returns 500 under `vite preview`). `npm run test` runs Vitest — see the Testing section below..

Examples to look for and remove:

- Debug text overlays left in scene render
- Disabled geometry or materials (commented-out sprites)
- Hard-coded camera positions that break gameplay
- Test event listeners that were meant to be temporary

### Skills

A third-party design skill, **`ui-ux-pro-max`**, is installed under `.agents/skills/` and pinned in `skills-lock.json`. It is worth invoking for UI/visual work. See [SKILLS.md](./SKILLS.md).

### Language

All player-facing copy is Polish; code and comments are English. The user communicates in Polish — reply in Polish unless asked otherwise.

### Phaser version

This project runs **Phaser 4.2.1**, not Phaser 3. Its WebGL renderer was rewritten (RenderNodes); pipeline keys, the Lights2D API, and `postFX`/`FX.Bloom` from Phaser 3 do not carry over as-is — some were removed outright (confirmed by grepping `node_modules/phaser/src`, not by assumption). A Phaser-3-shaped API call that compiles under the type defs can still throw at runtime and abort `create()` mid-way. Verify Phaser 4.2.1 APIs against the installed source or browser before relying on rendering internals.

### Testing

`npm run test` runs Vitest (jsdom environment, config at `vitest.config.ts`). Tests live co-located as `src/**/*.test.ts` — see `src/game/questUtils.test.ts`, `inventory.test.ts`, `daily.test.ts`, `levels.test.ts`, and `src/store/gameStore.test.ts` for the established pattern: pure game logic and data-integrity checks, deliberately kept independent of a running `Phaser.Game`/`Phaser.Scene` instance rather than mocking Phaser internals. There is no `test:unit`/`test:e2e` split and no Playwright setup — browser-level verification goes through the `claude-in-chrome` skill instead (see above).

### Godot 4 migration (in progress)

The project is migrating from Phaser to Godot 4. This is a staged migration, not a rewrite-in-place — read `god/godot.md` and `god/godot2.md` before touching anything migration-related; they are the canonical rules (`god/godotassets.md` and `god/vscode_godot_setup.md` cover assets and tooling).

The Three.js/R3F 3D prototype (`src/game/three/`, `/poziom3d`) was an unlinked, immature spike — never in production — and was removed from the repo (2026-08-31) as confirmed out of scope for the Godot migration. `LevelScene.ts` (Phaser 4.2.1) is the live production engine for all 6 levels; the Canvas2D `src/game/engine.ts` is dead fallback code. Phaser is the sole behavioral source of truth for Godot parity.

**Non-negotiable rules from the plan:**

- The existing Phaser source (`src/game/phaser/`) stays untouched and working until a system is fully migrated, tested, and playtested in Godot. Never delete or overwrite it as a side effect of migration work.
- Audit and plan before implementing. `docs/migration/` holds `PHASER_AUDIT.md`, `ARCHITECTURE_MAP.md`, `DEPENDENCY_GRAPH.md`, `ASSET_INVENTORY.md`, `GAMEPLAY_BEHAVIOR.md`, `DATA_MODEL.md`, `MIGRATION_RISKS.md`, `MIGRATION_MATRIX.md` — check `MIGRATION_MATRIX.md` for what's analyzed/in-progress/complete before starting work on a system.
- Do not translate Phaser/TS code 1:1 into GDScript. Understand the responsibility of a system first, then design its Godot-idiomatic equivalent (Nodes, Signals, Resources, CharacterBody2D, InputMap, Autoloads used sparingly).
- Work one subsystem at a time on its own branch (`migration/player`, `migration/combat`, etc.), validate (compiles, runs, tests, behavior parity), then update `MIGRATION_MATRIX.md` before moving to the next system.
- The Godot project lives in `godot/` at the repo root (see `godot/README.md` for current status — currently a directory skeleton + `project.godot`, no gameplay yet).

**Tooling:** VS Code integration is set up in `.vscode/settings.json`/`launch.json` via the `geequlim.godot-tools` extension (LSP port 6005, debug port 6006). Godot 4.x itself must be installed locally and its path set in `godotTools.editorPath.godot4` — this is a manual, one-time step for the user. GDScript formatting (tabs) is scoped to `[gdscript]` in VS Code settings so it doesn't affect the JS/TS Prettier setup.

**Do not** start implementing Godot gameplay systems without checking `docs/migration/MIGRATION_MATRIX.md` first — an approved audit should precede new subsystem work, per the plan's Phase 5 ("do not implement yet, wait for the next instruction").

### Session discipline (Godot work)

Learned from the 2026-09-01/02 tooling-vs-overengineering back-and-forth in `rpg.md` — keep
these in mind specifically for Godot sessions on this repo:

- **One round = one dated `rpg.md` entry.** This has been the single most reliable piece of
  documentation in the repo — no other `.md` file is trusted the same way (see `rpg.md`
  section 12's audit of the rest). Keep doing it for every implemented round, including
  small ones.
- **Don't trust a raw pass/fail count from a new `class_name` script without a cache
  refresh first.** GUT silently skips test files it can't parse yet — a suite that reports
  "165/165" can be lying by omission if a new class hasn't been scanned into the editor's
  class cache. Run a headless scan (or the `godot-cache-refresh` skill) after adding any
  new `class_name` script, before trusting its test results — and hold any agent doing
  Godot work to running the full suite via `scripts/run_godot_tests.sh` before reporting
  "done", not just the file(s) it touched.
- **Visual verification is the standing gap, not a one-off.** Nearly every section of
  `rpg.md` ends with "nie zweryfikowane wizualnie" — GUT catches logic, not "does the UI
  overlap" or "does a gossip bubble run off-screen". Periodically actually run the game by
  hand (not just through an agent) and click through recently-added features instead of
  trusting unit tests alone.
- **Scope-check before asking "what else?".** A string of "add one more thing" requests in
  one session tends to snowball into overengineering that then has to be walked back (see
  `rpg.md` section 14 for a concrete instance: CI + git hooks added and reverted same day).
  Before asking for another addition, check whether it answers a problem that has actually
  shown up, not one that's merely imaginable.
- **Review after, not instead of, a round.** A code review (e.g. the `godot-code-reviewer`
  agent) is more useful pointed at one finished, tested feature's diff than asked as a
  free-floating "what could be improved" — a concrete diff produces sharper, more relevant
  findings than a generic wishlist.
- **`rpg.md` is the trustworthy file — protect that property.** No other `.md` in the repo
  has it (`MIGRATION_MATRIX.md`, `godot/README.md`, `todo.md`, `planagent.md` are all
  already stale). It stays trustworthy only by keeping "one round = one dated entry"
  every time, without exception, including corrections when an earlier entry turns out
  wrong (see `rpg.md` section 15d's correction of its own prior claim).
- **Format → cache-refresh → test is a pipeline, not a fallback.** Run
  `gdscript-format` + `godot-cache-refresh` right after writing any round of new
  `class_name` scripts, before looking at test results — not as a fix applied after a
  suspiciously-clean pass count turns out to be GUT silently skipping unparseable files.
  Doing it after the fact means the "165/165 PASS" you already reported may have been
  wrong.
- **Batch visual verification instead of spreading it thin.** GUT catches logic, not
  layout — whether a gossip bubble overlaps the weather tint, whether a new menu panel
  clips at some resolution. Rather than trying to eyeball each new feature in isolation
  right after building it, periodically do one deliberate manual playthrough covering
  everything built since the last one, so overlapping/colliding UI actually gets a chance
  to show up together.
- **Watch the "what else could I add" pattern.** A run of open-ended addition requests in
  one session is what produced the CI/husky/worktree churn in `rpg.md` section 14 (added,
  then reverted same day). The better question isn't "what could be added" but "what
  actually limited the last round of work" — a real, encountered constraint, not a
  hypothetical one.
- **Prefer smaller, more frequent commits over one large uncommitted stack.** This repo
  has repeatedly carried dozens of uncommitted files across several finished `rpg.md`
  sections at once (worse after things like an editor crash mid-session). `rpg.md`
  already segments work into closed, dated sections — those are natural commit
  boundaries; use them instead of letting work pile up uncommitted.

### Memory lifecycle

Each level gets its own `Phaser.Game` instance, torn down with `game.destroy(true)` when `PhaserGameCanvas` unmounts or the level changes (see the cleanup in its main effect) — this already avoids cross-level texture/listener leaks. Keyboard bindings use `this.input.keyboard.addKey(...)`, which Phaser cleans up on scene shutdown automatically.
