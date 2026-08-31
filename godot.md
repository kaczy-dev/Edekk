CLAUDE CODE — PHASER TO GODOT MIGRATION

You are a senior game-engine migration engineer.

We have an existing Phaser game that must be migrated to Godot 4.

Your job is NOT to blindly translate JavaScript/TypeScript into GDScript.

Your job is to preserve the game's gameplay, behavior, data and visual intent while rebuilding the architecture using idiomatic Godot 4 patterns.

CRITICAL RULE

DO NOT MODIFY THE EXISTING PHASER PROJECT DURING THE AUDIT.

DO NOT START IMPLEMENTING THE GODOT VERSION YET.

FIRST ANALYZE THE ENTIRE PHASER PROJECT.

---

PHASE 1 — COMPLETE AUDIT

Inspect:

- package.json
- source code
- scenes
- assets
- tilemaps
- JSON/data files
- configuration
- audio
- shaders
- animations
- UI
- input
- physics
- collisions
- enemy AI
- combat
- inventory
- items
- save/load
- events
- utilities
- external dependencies

Search the entire repository.

Do not rely only on obvious entry points.

Identify hidden dependencies and implicit runtime behavior.

---

PHASE 2 — BUILD A SYSTEM MAP

Create:

PHASER_AUDIT.md

Include:

1. Project overview
2. Entry points
3. Scene list
4. System list
5. Entity list
6. Asset inventory
7. External dependencies
8. Event system
9. Input system
10. Physics system
11. Combat system
12. AI system
13. Inventory system
14. UI system
15. Audio system
16. Save/load system
17. Data/configuration system
18. Rendering/VFX/shader system
19. Dependency graph
20. Known technical debt
21. Migration risks
22. Recommended migration order

---

PHASE 3 — GODOT ARCHITECTURE

Create:

MIGRATION_ARCHITECTURE.md

For every major Phaser subsystem specify:

- Phaser implementation
- current responsibility
- dependencies
- Godot equivalent
- proposed Godot scene
- proposed Godot script
- proposed Resource types
- signals
- autoloads, if required
- migration risks

Do not create unnecessary global singletons.

Prefer composition.

Prefer signals for decoupled communication.

Prefer Resources for static game data.

Keep gameplay logic separate from presentation.

Keep MonoBehaviour-style logic out of giant scripts.

---

PHASE 4 — MIGRATION MATRIX

Create:

MIGRATION_MATRIX.md

Use this format:

System| Phaser files| Godot target| Complexity| Dependencies| Status

Statuses:

NOT_STARTED
ANALYZED
IN_PROGRESS
IMPLEMENTED
TESTED
PLAYTESTED
COMPLETE

---

PHASE 5 — DO NOT IMPLEMENT YET

After completing the audit, STOP.

Report:

1. What you discovered
2. Project architecture
3. Main systems
4. Migration risks
5. Recommended Godot architecture
6. Recommended migration order
7. Files that must be migrated
8. Files that can be reused directly
9. Files that should be redesigned
10. Potential compatibility problems

Do not modify gameplay code.

Do not delete anything.

Do not rewrite anything.

Do not create the Godot implementation yet.

Wait for the next instruction.

---

IMPLEMENTATION RULES

When implementation begins later:

1. Work on ONE subsystem at a time.
2. Inspect existing code before changing anything.
3. Reuse existing abstractions where appropriate.
4. Do not create duplicate systems.
5. Do not create giant manager classes.
6. Do not introduce unnecessary global state.
7. Prefer composition over inheritance.
8. Use Godot signals for event-driven communication.
9. Use Resources for static game data.
10. Keep scenes modular.
11. Keep scripts small and focused.
12. Avoid premature optimization.
13. Do not change gameplay behavior without explicit reason.
14. Preserve edge cases from the Phaser implementation.
15. Add tests for important gameplay systems.

---

AFTER EACH MIGRATION

Run:

1. Static analysis
2. Project compilation
3. Tests
4. Runtime validation
5. Architecture review

Then report:

- files created
- files modified
- systems migrated
- tests added
- remaining issues
- known deviations from Phaser behavior

Do not proceed to another major subsystem until the current subsystem is stable.

---

FINAL GOAL

The final Godot project must:

- preserve the original game's gameplay
- preserve important visual behavior
- preserve game data
- preserve input behavior
- preserve combat behavior
- preserve AI behavior
- preserve save/load behavior
- be maintainable
- be modular
- be testable
- be performant
- use idiomatic Godot architecture

The final project must NOT be a JavaScript architecture translated line-by-line into GDScript.

It must be a properly engineered Godot game.
