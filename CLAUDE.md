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

`npm run preview` is broken (the Nitro bundle returns 500 under `vite preview`). There is **no test runner** configured.

## Claude-Code-specific notes

### Verify in the browser, not just the build

This is a canvas game. `npm run build` passing proves nothing about whether it is playable — a frozen main thread still builds and still screenshots a correct-looking frame. Use the `claude-in-chrome` skill, load `/poziom/1`, dismiss the dialog, and confirm the cat actually moves with WASD.

If the Chrome extension disconnects mid-session (it has), say so plainly and hand verification to the user rather than declaring the work verified.

### Measure before optimising

Performance intuitions have been wrong here twice. The browser `javascript_tool` can time the engine directly:

```js
// Frame cost, measured against a live page
const t0 = performance.now();
for (let i = 0; i < 30; i++) engine.render(ctx);
(performance.now() - t0) / 30;   // baseline: ~0.62 ms
```

When the page is too busy for `Runtime.evaluate`, `read_console_messages` still works — but arm it with one call *before* navigating, since capture starts on first use.

### Clean up diagnostics

Temporary switches (`TEMP_SKIP_ENGINE`, self-terminating render loops, `window.__engine` exposure) have been left behind mid-session and would ship a broken game. Before finishing, grep for them:

```bash
grep -rn "TEMP_\|__engine\|__stats" src/
```

### Skills

A third-party design skill, **`ui-ux-pro-max`**, is installed under `.agents/skills/` and pinned in `skills-lock.json`. It is worth invoking for UI/visual work. See [SKILLS.md](./SKILLS.md).

### Language

All player-facing copy is Polish; code and comments are English. The user communicates in Polish — reply in Polish unless asked otherwise.
