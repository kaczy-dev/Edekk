# COC2.md — MASTER DEVELOPMENT PLAN
# Phaser + TypeScript Top-Down Game

## 0. Mission

This document is the master execution plan for an AI coding agent working on this game.

Treat `COC.md` as the architectural constitution and this file as the implementation roadmap.

The objective is to transform the existing Phaser game into a polished, scalable, production-quality 2D top-down game.

Core stack:

- Phaser
- TypeScript
- Vite
- Tiled
- Vitest
- Playwright
- ESLint
- Prettier
- pnpm

Phaser is the game runtime, renderer, input integration, scene system, animation system and game-facing API. Phaser supports TypeScript and WebGL/Canvas rendering for browser games. Use the official Phaser API documentation as the source of truth for engine APIs.

Tiled is the source of authored map/world data. Prefer Tiled JSON for browser workflows where appropriate.

---

# 1. How the AI Agent Must Work

Before changing code:

1. Inspect the repository.
2. Identify the current architecture.
3. Identify existing systems that already solve part of the problem.
4. Do not duplicate existing functionality.
5. Read `COC.md`.
6. Determine which phase of this plan the task belongs to.
7. Make the smallest coherent change.
8. Run type checking.
9. Run relevant tests.
10. Run the game/build when appropriate.
11. Review performance and regressions.
12. Report what changed and what remains.

Never rewrite the entire project merely because the current implementation is imperfect.

Prefer incremental refactoring.

---

# 2. First Task: Repository Audit

Before implementing features, create an internal architecture map.

Inspect:

```text
package.json
tsconfig.json
vite.config.*
src/
public/
assets/
maps/
tests/
```

Determine:

- Phaser version
- TypeScript version
- build system
- current scenes
- current player implementation
- current enemy implementation
- current physics
- current map loading
- current asset loading
- current UI
- current save system
- current audio system
- current game loop
- current dependencies
- current performance bottlenecks
- current technical debt

Do not assume the project matches the target architecture.

Adapt the plan to the actual repository.

---

# 3. Target Architecture

The target architecture is:

```text
                    Phaser Runtime
                          |
                     Scene Layer
                          |
              +-----------+-----------+
              |                       |
         Game Systems             Rendering
              |                       |
      +-------+-------+          +----+----+
      |       |       |          |         |
      AI    Combat   World      FX      Camera
      |       |       |          |
      +-------+-------+----------+
                      |
                 Domain State
                      |
            +---------+---------+
            |         |         |
           Data      Save      Events
```

Main principle:

> Gameplay state and rules must not become dependent on Phaser rendering objects.

---

# 4. Phase 0 — Stabilize the Project

## Goal

Make the current project safe to evolve.

Tasks:

- enable strict TypeScript
- remove obvious `any`
- remove dead code
- remove duplicate utilities
- establish ESLint
- establish Prettier
- establish Vitest
- establish a reliable build
- establish a reliable development command
- establish basic Playwright smoke test
- establish error logging
- establish a baseline FPS/performance check

Required scripts should eventually resemble:

```text
dev
build
preview
typecheck
lint
test
test:watch
test:e2e
format
```

Definition of done:

```text
[ ] npm/pnpm install works
[ ] dev server works
[ ] production build works
[ ] TypeScript passes
[ ] ESLint passes
[ ] basic test passes
[ ] game boots without console errors
```

---

# 5. Phase 1 — Core Runtime

Create:

```text
src/core/
src/config/
src/scenes/
```

Implement:

```text
Game
GameContext
EventBus
Logger
Time
Random
```

Scenes:

```text
BootScene
PreloadScene
MainMenuScene
WorldScene
UIScene
GameOverScene
```

Rules:

- Scenes coordinate.
- Systems implement behavior.
- Renderers render.
- Domain objects contain state.
- Services handle infrastructure.

Do not allow `WorldScene` to become a god object.

---

# 6. Phase 2 — Asset Pipeline

Establish a deterministic asset pipeline.

Organize:

```text
public/assets/
├── images/
├── atlases/
├── maps/
├── audio/
├── fonts/
└── shaders/
```

Implement:

```text
AssetService
AssetRegistry
```

Use texture atlases for sprite-heavy content.

Avoid loading the same asset repeatedly.

Preload only assets required for the current game state where practical.

For large worlds, introduce lazy/zone-based loading later.

---

# 7. Phase 3 — Player Architecture

Refactor player into separate responsibilities.

Target:

```text
entities/player/
├── Player.ts
├── PlayerController.ts
├── PlayerAnimator.ts
└── PlayerStats.ts
```

Also create:

```text
PlayerState
PlayerRenderer
```

Flow:

```text
Input
 ↓
PlayerController
 ↓
PlayerState
 ↓
MovementSystem
 ↓
PlayerRenderer
```

Requirements:

- movement must be deterministic
- diagonal movement must be normalized
- speed must be data/config driven
- animation must follow state
- rendering must not own gameplay rules

Support:

- keyboard
- mouse where useful
- touch
- gamepad later

---

# 8. Phase 4 — Input Abstraction

Create:

```text
InputManager
KeyboardInput
MouseInput
GamepadInput
TouchInput
```

Expose a normalized input model:

```ts
interface InputState {
    moveX: number;
    moveY: number;
    attack: boolean;
    interact: boolean;
    dodge: boolean;
}
```

Gameplay should not care whether the source is keyboard, gamepad, touch or AI.

This is critical for future mobile support.

---

# 9. Phase 5 — World / Tiled

Use Tiled as the world-authoring tool.

Recommended layers:

```text
Ground
GroundDetails
Collision
Objects
Decorations
AbovePlayer
Triggers
SpawnPoints
```

Implement:

```text
World
MapLoader
TilemapManager
ZoneManager
SpawnManager
```

Map flow:

```text
Tiled map
 ↓
MapLoader
 ↓
validated map data
 ↓
TilemapManager
 ↓
World
```

Use Tiled custom properties/classes for authored metadata.

Do not bury gameplay logic in map-specific code.

Tiled supports JSON export and command-line map export, making it suitable for a browser-oriented asset pipeline.

---

# 10. Phase 6 — Entity Architecture

Introduce stable entity IDs.

```ts
type EntityId = string;
```

Use composition.

Example:

```text
Goblin
 + Transform
 + Health
 + Movement
 + AI
 + Combat
 + Renderer
```

Chest:

```text
Chest
 + Transform
 + Inventory
 + Interaction
 + Renderer
```

Avoid deep inheritance.

If the project grows into thousands of active entities, evaluate `bitecs`. Do not introduce ECS prematurely.

---

# 11. Phase 7 — Movement and Collision

Create:

```text
MovementSystem
CollisionSystem
```

Decide based on the actual game:

- Phaser Arcade Physics for simple movement/collision
- Matter only if the game needs advanced physics

Do not introduce Matter merely because it is more powerful.

Requirements:

- collision must be authoritative
- movement must not be duplicated in multiple systems
- rendering follows the simulation
- collision geometry should be separate from visual decoration

---

# 12. Phase 8 — Combat System

Create:

```text
src/combat/
├── Damage.ts
├── Hitbox.ts
├── Hurtbox.ts
├── Weapon.ts
├── DamageSystem.ts
└── StatusEffects.ts
```

Combat flow:

```text
Input / AI
 ↓
Attack
 ↓
Hitbox
 ↓
Target detection
 ↓
Damage calculation
 ↓
Resistance
 ↓
Status effects
 ↓
Health update
 ↓
Combat event
 ↓
FX / audio / UI
```

Combat logic must be independent from particles and sounds.

Implement data-driven:

- base damage
- damage types
- armor
- resistances
- critical hits
- cooldowns
- attack ranges
- hitboxes
- hurtboxes
- knockback
- invulnerability windows
- status effects

Add tests for damage calculations.

---

# 13. Phase 9 — Enemy System

Create:

```text
entities/enemies/
ai/
```

Enemy runtime:

```text
EnemyState
EnemyController
EnemyRenderer
EnemyFactory
```

AI architecture:

```text
Perception
 ↓
Threat Evaluation
 ↓
State Machine
 ↓
Action
```

States:

```text
Idle
Patrol
Investigate
Chase
Attack
Flee
Dead
```

Never create a huge `Enemy.update()` with dozens of unrelated conditions.

---

# 14. Phase 10 — AI Performance

AI does not need to run everything every frame.

Target strategy:

```text
movement:      60 FPS
combat:        60 FPS
perception:    10–20 FPS
pathfinding:   throttled
background AI: 2–10 FPS
```

Use:

- distance checks
- visibility checks
- activation zones
- throttled perception
- cached paths
- path invalidation
- object pooling where relevant

Only optimize after profiling.

---

# 15. Phase 11 — Inventory and Items

Create:

```text
inventory/
├── Inventory.ts
├── Item.ts
├── ItemDatabase.ts
└── Equipment.ts
```

Data:

```text
data/items/
data/weapons/
```

Item definition should be externalized.

Support:

- stackable items
- unique items
- equipment
- durability if needed
- item categories
- item rarity
- weight if needed
- tooltips
- use actions

Inventory operations must be testable without Phaser.

---

# 16. Phase 12 — Quest System

Create:

```text
quests/
├── Quest.ts
├── QuestManager.ts
└── objectives/
```

Quest flow:

```text
Quest Definition
 ↓
Quest State
 ↓
Objective Tracking
 ↓
Completion
 ↓
Rewards
 ↓
UI Event
```

Objective types can include:

```text
kill
collect
talk
reach
interact
escort
survive
```

Quest UI must not own progression logic.

---

# 17. Phase 13 — Loot

Create:

```text
LootSystem
LootTable
LootGenerator
```

Data-driven loot tables.

Support:

- guaranteed drops
- weighted drops
- rarity
- quantity ranges
- unique drops
- conditional drops

Use a seeded RNG where deterministic reproduction is useful.

---

# 18. Phase 14 — Rendering Upgrade

This phase is responsible for the major visual quality improvement.

Create:

```text
rendering/
├── CameraController.ts
├── Lighting.ts
├── Shadows.ts
├── Particles.ts
├── Effects.ts
├── FloatingText.ts
├── Decals.ts
└── shaders/
```

Target visual pipeline:

```text
Ground
 ↓
Ground Details
 ↓
Shadows
 ↓
Entities
 ↓
Projectiles
 ↓
Particles
 ↓
Lighting
 ↓
Fog / Atmosphere
 ↓
Post Effects
 ↓
Camera Effects
 ↓
UI
```

---

# 19. Phase 15 — Lighting

Implement a lightweight 2D lighting strategy.

Features:

- ambient light
- local lights
- player light
- torches
- environmental lights
- day/night lighting

Do not create one expensive shader calculation per object if a simpler batched approach works.

Lighting must remain readable.

Do not let effects obscure gameplay.

---

# 20. Phase 16 — Shadows

Prioritize:

- player shadow
- enemy shadow
- large object shadow
- directional consistency

Use soft stylized shadows rather than physically accurate shadows unless the art direction requires otherwise.

For many objects, use reusable shadow textures/pools instead of expensive per-frame generation.

---

# 21. Phase 17 — WebGL Effects

Implement only effects that improve the visual hierarchy.

Potential effects:

```text
outline
hit flash
glow
fog
water distortion
light falloff
color grading
weather
screen-space vignette
```

Every shader must have:

- clear purpose
- mobile fallback
- reasonable default parameters
- profiling notes if expensive

Never make WebGL effects mandatory for core gameplay readability.

---

# 22. Phase 18 — Particles and Combat Feedback

Create reusable effect pools.

Effects:

```text
hit
critical hit
death
blood / impact
dust
footsteps
weapon trail
pickup
level up
environmental particles
```

Use object pooling.

Do not allocate hundreds of temporary objects every frame.

---

# 23. Phase 19 — Camera

Implement:

```text
CameraController
```

Features:

- smooth follow
- bounds
- zoom
- dead zone
- shake
- impact feedback
- transitions

Use camera shake sparingly.

Add an option to reduce or disable screen shake.

---

# 24. Phase 20 — UI

Keep UI separate from game simulation.

HUD:

```text
Health
Stamina
Mana if applicable
XP
Quest tracker
Interaction prompt
Damage numbers
```

Complex UI may use React.

Phaser should continue to own the actual game world.

Do not synchronize every entity position through Zustand.

---

# 25. Phase 21 — Audio

Create:

```text
AudioManager
MusicManager
SoundManager
```

Gameplay emits semantic events.

Example:

```text
combat:hit
combat:critical
enemy:death
item:pickup
quest:complete
player:damage
```

Audio layer maps events to sound assets.

Centralize volume categories:

```text
master
music
effects
ambient
ui
```

---

# 26. Phase 22 — Day / Night and Environment

Create:

```text
DayNightSystem
WorldLighting
WeatherSystem
AmbientSystem
```

Potential states:

```text
dawn
day
dusk
night
```

Environment should feel alive through:

- animated foliage
- particles
- ambient creatures
- lighting changes
- weather
- water
- environmental audio

Do not update every environmental object every frame if it is off-screen.

---

# 27. Phase 23 — Save System

Create:

```text
save/
├── SaveManager.ts
├── SaveData.ts
└── IndexedDBStorage.ts
```

Architecture:

```text
Game
 ↓
SaveManager
 ↓
StorageAdapter
 ↓
IndexedDB
```

Version saves.

Example:

```ts
interface SaveData {
    version: number;
    timestamp: number;
    player: PlayerSaveData;
    world: WorldSaveData;
    quests: QuestSaveData;
}
```

Implement migrations:

```text
v1 -> v2
v2 -> v3
```

Never silently corrupt old saves.

---

# 28. Phase 24 — Data Validation

All important external data should be validated.

Validate:

- item data
- enemy data
- weapon data
- quest data
- save data
- map metadata

Use Zod only if the project actually needs runtime schema validation at scale.

Do not duplicate schemas unnecessarily.

---

# 29. Phase 25 — Mobile

Support:

- responsive viewport
- touch controls
- virtual joystick if needed
- attack buttons
- safe UI areas
- device pixel ratio
- browser visibility changes
- pause/resume
- reduced effects

Performance target should be realistic for mid-range mobile hardware.

Do not design only for desktop.

---

# 30. Phase 26 — Performance Pass

Create a profiling checklist.

Measure:

```text
FPS
frame time
draw calls
texture memory
active entities
particles
AI time
pathfinding
GC/allocation spikes
load time
bundle size
```

Optimization order:

```text
1. Measure
2. Identify bottleneck
3. Change one thing
4. Measure again
5. Keep only proven improvements
```

Potential optimizations:

- pooling
- atlas batching
- lazy loading
- entity activation zones
- AI throttling
- path caching
- reducing overdraw
- culling
- lower particle density
- shader simplification

---

# 31. Phase 27 — Testing

Unit tests:

```text
combat
damage
inventory
items
quests
AI state transitions
loot
save migrations
math
geometry
```

Integration tests:

```text
player movement
combat flow
quest progression
save/load
```

E2E:

```text
boot
menu
start game
move
interact
save
reload
```

Do not use E2E tests for every internal calculation.

---

# 32. Phase 28 — Debug Tools

Create a developer debug mode.

Useful overlays:

```text
FPS
frame time
entity count
player coordinates
current zone
AI state
collision shapes
hitboxes
hurtboxes
camera bounds
draw/debug information
```

Allow toggling with a debug key in development builds.

Never ship destructive debug functionality accidentally in production.

---

# 33. Phase 29 — Content Pipeline

Create repeatable workflows for:

```text
sprites
atlases
maps
audio
JSON data
shaders
```

Tiled exports should be reproducible.

Asset naming must be consistent.

Example:

```text
player_idle_down
player_walk_down
enemy_goblin_idle
weapon_sword_01
```

Avoid random filenames.

---

# 34. Phase 30 — World Scaling

If the world becomes large:

```text
World
 ├── Zone A
 ├── Zone B
 ├── Zone C
 └── Zone D
```

Only activate expensive simulation near the player.

Use:

```text
active zone
nearby zone
background zone
unloaded zone
```

Rendering and simulation activation should be separate concepts.

---

# 35. Phase 31 — Final Polish

Polish order:

```text
1. Movement feel
2. Combat responsiveness
3. Animation
4. Hit feedback
5. Camera
6. Audio
7. Lighting
8. Particles
9. Environment
10. UI
11. Loading transitions
12. Accessibility
```

The game should feel good before it becomes visually overloaded.

---

# 36. Development Milestones

## Milestone A — Foundation

```text
[ ] Repository audited
[ ] TypeScript strict
[ ] Vite stable
[ ] Phaser stable
[ ] lint
[ ] formatting
[ ] tests
[ ] boot scene
[ ] preload scene
```

## Milestone B — Playable Core

```text
[ ] player movement
[ ] camera
[ ] map
[ ] collision
[ ] basic enemy
[ ] basic combat
```

## Milestone C — Game Systems

```text
[ ] AI
[ ] inventory
[ ] items
[ ] loot
[ ] quests
[ ] save/load
```

## Milestone D — Visual Upgrade

```text
[ ] lighting
[ ] shadows
[ ] particles
[ ] shaders
[ ] camera effects
[ ] environmental animation
```

## Milestone E — Production

```text
[ ] mobile controls
[ ] performance pass
[ ] automated tests
[ ] save migrations
[ ] error handling
[ ] debug tools
[ ] release build
```

---

# 37. Agent Commands / Working Protocol

For every significant task, follow:

```text
PLAN
 ↓
INSPECT
 ↓
IMPLEMENT
 ↓
TYPECHECK
 ↓
TEST
 ↓
BUILD
 ↓
PROFILE IF RELEVANT
 ↓
REVIEW
```

Do not skip inspection.

Do not claim success without verification.

If a command cannot be run, state that clearly.

---

# 38. When Refactoring Existing Code

Use this order:

```text
1. Preserve behavior
2. Extract types
3. Extract pure logic
4. Extract system
5. Extract renderer
6. Update callers
7. Add tests
8. Remove old implementation
```

Avoid a giant rewrite.

---

# 39. Anti-Patterns

The agent MUST avoid:

```text
God Scene
God Player class
God Manager
global mutable state everywhere
deep inheritance
any everywhere
hard-coded balance
hard-coded asset paths everywhere
logic in rendering
UI controlling gameplay
duplicate state stores
per-frame object creation
unbounded particle spawning
AI every frame for every enemy
one shader per object without justification
```

---

# 40. Decision Rules

When two approaches are possible:

Prefer:

```text
simpler
typed
testable
data-driven
composable
measurable
```

over:

```text
clever
abstract
dependency-heavy
prematurely optimized
```

Do not introduce architecture for hypothetical future requirements.

Introduce abstractions when the current project has a real repeated responsibility.

---

# 41. Definition of Done

A feature is complete only when:

```text
[ ] Correct system owns it
[ ] Types are correct
[ ] No unnecessary dependency
[ ] No circular dependency
[ ] Rendering separated from gameplay
[ ] Errors handled
[ ] Tests added where valuable
[ ] Typecheck passes
[ ] Lint passes
[ ] Build passes
[ ] No obvious performance regression
[ ] Mobile impact considered
[ ] Save impact considered
[ ] Existing functionality preserved
```

---

# 42. Final Architecture Goal

The final project should conceptually look like:

```text
                        GAME
                         |
              +----------+----------+
              |                     |
          GAMEPLAY                PRESENTATION
              |                     |
       +------+------+        +-----+------+
       |      |      |        |     |      |
      AI   Combat  World    Render Camera  FX
       |      |      |        |
       +------+------+--------+
              |
          DOMAIN STATE
              |
       +------+------+------+
       |      |      |      |
      Data   Save  Events  Services
```

The project should remain understandable to a new developer.

The agent should optimize for long-term maintainability, not maximum code volume.

---

# 43. Master Execution Order

If asked to "build the game", execute approximately in this order:

```text
01. Audit repository
02. Stabilize tooling
03. Establish core runtime
04. Establish asset pipeline
05. Establish player architecture
06. Establish input abstraction
07. Establish Tiled world pipeline
08. Establish entity architecture
09. Establish movement/collision
10. Establish combat
11. Establish enemy AI
12. Establish inventory/items
13. Establish quests
14. Establish loot
15. Establish save system
16. Establish UI
17. Establish audio
18. Establish lighting
19. Establish shadows
20. Establish particles
21. Establish shaders
22. Establish environment systems
23. Establish mobile controls
24. Establish debug tools
25. Run performance pass
26. Run testing pass
27. Run polish pass
28. Run production/release audit
```

Do not jump directly to step 19 because visual effects are exciting.

A strong gameplay foundation produces a much better final game.

---

# 44. Final Instruction to Claude Code

You are not being asked to merely generate code.

You are acting as the senior engineer responsible for the long-term health of this game codebase.

Before every substantial change:

- inspect
- reason about ownership
- choose the smallest correct architecture
- implement
- verify
- test
- report

Never optimize for "more files", "more classes", or "more frameworks".

Optimize for:

> a polished top-down game that is visually impressive, responsive, performant, testable, maintainable and capable of growing substantially without architectural collapse.

When uncertain, inspect the existing repository rather than guessing.

When a requirement conflicts with `COC.md`, flag the conflict before making a major architectural deviation.

When a feature can be implemented cleanly without a new dependency, prefer that.

When performance is uncertain, measure it.

When visual quality is uncertain, prioritize readability and gameplay feedback.

When architecture is uncertain, keep responsibilities explicit and dependencies one-directional.
