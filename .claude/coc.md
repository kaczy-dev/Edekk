# COC.md — Phaser + TypeScript Game Engineering Constitution

## 0. Purpose

This document is the authoritative engineering specification for an AI coding agent working on this game.

The agent MUST treat this file as a project constitution, not as optional advice.

Primary goal:

> Build a maintainable, performant, production-quality 2D top-down game using Phaser + TypeScript, with clean separation between gameplay/domain logic, rendering, data, UI, persistence, and tooling.

The project targets modern browsers and mobile/desktop web environments.

Phaser is the game runtime and renderer. TypeScript is mandatory. Vite is the build/development tool.

---

# 1. Technology Stack

## Core

- TypeScript — strict mode
- Phaser — game engine
- Vite — development server and production bundler
- Node.js — development/runtime tooling
- pnpm — preferred package manager

## Maps and Content

- Tiled — map and level authoring
- JSON — external game data where practical
- Texture atlases — preferred for sprite-heavy content

## Testing and Quality

- Vitest — unit/integration tests
- Playwright — browser/E2E smoke tests
- ESLint — static analysis
- Prettier — formatting

## Optional Dependencies

Only add a dependency when there is a concrete requirement.

Possible additions:

- React — complex non-game UI only
- Zustand — UI/meta-game state only
- Matter.js — advanced physics only
- bitecs — only if entity count/architecture justifies ECS
- idb — IndexedDB convenience layer
- Howler.js — only if Phaser Audio is insufficient

Do NOT install libraries merely because they are popular.

---

# 2. Non-Negotiable Architecture Rules

## Rule 1 — Phaser is not the entire architecture

Do not put all gameplay logic inside Phaser Scene classes.

Scenes coordinate systems and lifecycle. They must not become god objects.

BAD:

```ts
class WorldScene extends Phaser.Scene {
    // 3000 lines of movement, AI, combat, inventory, quests...
}
```

GOOD:

```text
WorldScene
  -> World
  -> Systems
  -> Entity Managers
  -> Rendering
  -> Input
```

---

## Rule 2 — Separate state from presentation

Gameplay state should not depend unnecessarily on Phaser display objects.

Prefer:

```ts
interface PlayerState {
    id: string;
    x: number;
    y: number;
    hp: number;
    maxHp: number;
    speed: number;
}
```

Then render it:

```ts
class PlayerRenderer extends Phaser.GameObjects.Sprite {
    updateFromState(state: PlayerState): void {
        this.setPosition(state.x, state.y);
    }
}
```

The game must be designed so that core gameplay logic can be tested without creating a Phaser renderer whenever practical.

---

## Rule 3 — Prefer composition over deep inheritance

Avoid large inheritance trees.

BAD:

```text
Entity
 -> Character
   -> Enemy
     -> Goblin
       -> EliteGoblin
```

Prefer:

```text
Entity
 + Transform
 + Health
 + Movement
 + Combat
 + AI
 + Renderer
```

Use classes where they improve encapsulation, but do not create inheritance solely for code reuse.

---

## Rule 4 — Systems own behavior

Examples:

```text
MovementSystem
CombatSystem
AISystem
CollisionSystem
InventorySystem
QuestSystem
LootSystem
DayNightSystem
SaveSystem
```

Entities contain state/components. Systems perform domain behavior.

---

## Rule 5 — Do not create circular dependencies

Dependency direction should generally be:

```text
Scenes
  ↓
Systems
  ↓
Domain / State
  ↓
Utilities
```

Rendering may consume domain state, but domain code should not depend on rendering.

Avoid:

```text
Player -> WorldScene -> Player
```

---

# 3. Recommended Project Structure

```text
project/
│
├── public/
│   └── assets/
│       ├── images/
│       ├── atlases/
│       ├── maps/
│       ├── audio/
│       ├── fonts/
│       └── shaders/
│
├── src/
│   ├── main.ts
│   ├── game.ts
│   │
│   ├── config/
│   │   ├── gameConfig.ts
│   │   ├── graphicsConfig.ts
│   │   ├── audioConfig.ts
│   │   └── constants.ts
│   │
│   ├── core/
│   │   ├── Game.ts
│   │   ├── GameContext.ts
│   │   ├── EventBus.ts
│   │   ├── Logger.ts
│   │   ├── Time.ts
│   │   └── Random.ts
│   │
│   ├── scenes/
│   │   ├── BootScene.ts
│   │   ├── PreloadScene.ts
│   │   ├── MainMenuScene.ts
│   │   ├── WorldScene.ts
│   │   ├── UIScene.ts
│   │   └── GameOverScene.ts
│   │
│   ├── entities/
│   │   ├── player/
│   │   ├── enemies/
│   │   ├── npc/
│   │   ├── items/
│   │   ├── projectiles/
│   │   └── environment/
│   │
│   ├── systems/
│   │   ├── MovementSystem.ts
│   │   ├── CombatSystem.ts
│   │   ├── CollisionSystem.ts
│   │   ├── AISystem.ts
│   │   ├── InteractionSystem.ts
│   │   ├── LootSystem.ts
│   │   ├── QuestSystem.ts
│   │   ├── InventorySystem.ts
│   │   ├── SaveSystem.ts
│   │   └── DayNightSystem.ts
│   │
│   ├── world/
│   │   ├── World.ts
│   │   ├── MapLoader.ts
│   │   ├── TilemapManager.ts
│   │   ├── ZoneManager.ts
│   │   └── SpawnManager.ts
│   │
│   ├── ai/
│   │   ├── AIController.ts
│   │   ├── StateMachine.ts
│   │   ├── Pathfinding.ts
│   │   └── states/
│   │
│   ├── combat/
│   │   ├── Damage.ts
│   │   ├── Hitbox.ts
│   │   ├── Hurtbox.ts
│   │   ├── Weapon.ts
│   │   ├── DamageSystem.ts
│   │   └── StatusEffects.ts
│   │
│   ├── inventory/
│   │   ├── Inventory.ts
│   │   ├── Item.ts
│   │   ├── ItemDatabase.ts
│   │   └── Equipment.ts
│   │
│   ├── quests/
│   │   ├── Quest.ts
│   │   ├── QuestManager.ts
│   │   └── objectives/
│   │
│   ├── data/
│   │   ├── items/
│   │   ├── enemies/
│   │   ├── weapons/
│   │   ├── quests/
│   │   └── characters/
│   │
│   ├── rendering/
│   │   ├── CameraController.ts
│   │   ├── Lighting.ts
│   │   ├── Shadows.ts
│   │   ├── Particles.ts
│   │   ├── Effects.ts
│   │   ├── FloatingText.ts
│   │   └── shaders/
│   │
│   ├── ui/
│   │   ├── HUD.ts
│   │   ├── HealthBar.ts
│   │   ├── DamageNumbers.ts
│   │   └── DialogManager.ts
│   │
│   ├── audio/
│   │   ├── AudioManager.ts
│   │   ├── MusicManager.ts
│   │   └── SoundManager.ts
│   │
│   ├── input/
│   │   ├── InputManager.ts
│   │   ├── KeyboardInput.ts
│   │   ├── MouseInput.ts
│   │   └── GamepadInput.ts
│   │
│   ├── save/
│   │   ├── SaveManager.ts
│   │   ├── SaveData.ts
│   │   └── IndexedDBStorage.ts
│   │
│   ├── services/
│   │   ├── AssetService.ts
│   │   ├── AudioService.ts
│   │   └── AnalyticsService.ts
│   │
│   ├── types/
│   │   ├── entities.ts
│   │   ├── combat.ts
│   │   ├── items.ts
│   │   ├── quests.ts
│   │   └── world.ts
│   │
│   └── utils/
│       ├── math.ts
│       ├── geometry.ts
│       └── arrays.ts
│
├── tests/
│   ├── combat/
│   ├── inventory/
│   ├── ai/
│   └── save/
│
├── tools/
├── package.json
├── tsconfig.json
├── vite.config.ts
├── eslint.config.js
├── prettier.config.js
└── README.md
```

---

# 4. Scene Architecture

Scenes should be small.

Recommended lifecycle:

```text
BootScene
   ↓
PreloadScene
   ↓
MainMenuScene
   ↓
WorldScene
   ├── gameplay
   └── UIScene
```

Responsibilities:

### BootScene

- initialize minimal engine configuration
- initialize global services
- determine runtime capabilities

### PreloadScene

- load assets
- create texture atlases
- initialize asset registries
- show loading progress

### WorldScene

- create world
- create gameplay systems
- create entities
- connect input
- update simulation

### UIScene

- HUD
- inventory
- dialogs
- notifications
- menus

Do not put combat/AI/inventory implementation inside Scenes.

---

# 5. Game Loop

Use Phaser's update lifecycle as the outer loop.

Conceptually:

```text
Input
  ↓
Simulation
  ↓
AI
  ↓
Movement
  ↓
Collision
  ↓
Combat
  ↓
World state
  ↓
Rendering
  ↓
UI
```

Keep update order deterministic.

Do not randomly mutate gameplay state from rendering code.

---

# 6. Entity Design

An entity should have a stable ID.

```ts
type EntityId = string;
```

Example:

```ts
interface EntityState {
    id: EntityId;
    x: number;
    y: number;
}
```

Components should contain focused state.

Example:

```ts
interface HealthComponent {
    hp: number;
    maxHp: number;
}
```

Avoid giant interfaces containing every possible property.

---

# 7. Player Architecture

Recommended:

```text
PlayerState
PlayerController
PlayerAnimator
PlayerRenderer
PlayerStats
```

Responsibilities:

### PlayerState

Pure gameplay state.

### PlayerController

Interprets input into gameplay intentions.

### PlayerAnimator

Maps movement/state to animation.

### PlayerRenderer

Owns Phaser display objects.

### PlayerStats

Stats and derived values.

Do not allow keyboard handling to directly modify sprite coordinates in multiple places.

---

# 8. Input

Use an abstraction:

```ts
interface InputState {
    moveX: number;
    moveY: number;
    attack: boolean;
    interact: boolean;
    dodge: boolean;
}
```

Gameplay consumes `InputState`.

This allows:

- keyboard
- mouse
- touch
- gamepad
- AI-controlled characters

to use the same gameplay API.

---

# 9. Combat Architecture

Combat must be data-driven.

Core concepts:

```text
Weapon
Damage
Hitbox
Hurtbox
Resistance
StatusEffect
```

Example:

```ts
interface Damage {
    amount: number;
    type: DamageType;
    sourceId: EntityId;
    targetId: EntityId;
}
```

Damage processing:

```text
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
Combat events
  ↓
Visual/audio feedback
```

Never couple damage calculation directly to particles, sounds, or UI.

---

# 10. AI Architecture

Use state machines for normal NPC/enemy behavior.

Example:

```text
Idle
Patrol
Investigate
Chase
Attack
Flee
Dead
```

Architecture:

```text
AIController
  ↓
Perception
  ↓
Threat evaluation
  ↓
StateMachine
  ↓
Current State
  ↓
Action
```

Avoid giant `updateEnemy()` functions.

AI decisions should be testable independently of rendering.

---

# 11. World and Maps

Use Tiled for authored maps.

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

Map data should not contain hard-coded game logic where avoidable.

Use object properties/classes for authored metadata.

The `MapLoader` converts Tiled data into game-world structures.

For large worlds, support multiple maps/zones and avoid loading the entire world unnecessarily.

---

# 12. Data-Driven Content

Do not hard-code balance values inside gameplay classes.

BAD:

```ts
class Goblin {
    hp = 100;
    damage = 15;
    speed = 80;
}
```

Prefer:

```json
{
    "id": "goblin",
    "hp": 100,
    "damage": 15,
    "speed": 80
}
```

Then:

```text
JSON/data
   ↓
Data Registry
   ↓
Factory
   ↓
Runtime Entity
```

Validate external data at load time.

Use schemas when the amount of content justifies it.

---

# 13. Rendering Architecture

Rendering is a separate concern.

Recommended pipeline:

```text
Tilemap
 ↓
Ground effects
 ↓
Entities
 ↓
Shadows
 ↓
Particles
 ↓
Lighting
 ↓
Fog / atmosphere
 ↓
Post-processing
 ↓
Camera effects
 ↓
Display
```

Use WebGL effects selectively.

Possible effects:

- dynamic lighting
- soft shadows
- glow
- outline
- fog
- water distortion
- weather
- screen-space effects
- hit flash
- damage effects

Do not add a shader simply because it looks impressive. Measure its cost.

---

# 14. Performance Rules

Performance is a design requirement.

## Avoid

- creating/destroying objects every frame
- unnecessary allocations in `update()`
- repeated texture loading
- excessive particle counts
- thousands of independent timers
- expensive pathfinding every frame
- unnecessary Phaser display objects
- huge uncompressed textures
- giant monolithic scenes

## Prefer

- object pooling
- texture atlases
- cached calculations
- spatial partitioning when needed
- throttled AI
- throttled pathfinding
- batched rendering
- lazy loading
- zone-based entity activation

Do not optimize blindly. Profile first.

---

# 15. Object Pooling

Use pools for frequently spawned objects:

- projectiles
- particles
- floating damage numbers
- temporary effects
- enemies in high-density situations

Concept:

```text
Pool
 ├── acquire()
 └── release()
```

Avoid creating hundreds of objects per second.

---

# 16. AI Update Frequency

Not every AI system must update every frame.

Example:

```text
Rendering: 60 FPS
Movement: 60 FPS
Combat: 60 FPS
Perception: 10–20 FPS
Pathfinding: throttled
Background NPC logic: 2–10 FPS
```

Use distance-to-player and visibility to reduce work.

---

# 17. Camera

Camera logic belongs in:

```text
rendering/CameraController.ts
```

Features may include:

- smooth follow
- dead zone
- zoom
- bounds
- shake
- impact effects
- room transitions

Gameplay code should not directly manipulate the camera everywhere.

---

# 18. Audio

Use a centralized manager.

```text
AudioManager
 ├── MusicManager
 └── SoundManager
```

Gameplay emits semantic events:

```text
player.attack
enemy.hit
enemy.death
item.pickup
quest.complete
```

Audio decides what sound corresponds to the event.

Do not scatter audio file paths throughout gameplay code.

---

# 19. Event Bus

Use events for loosely coupled reactions.

Example:

```ts
eventBus.emit("combat:damage", {
    sourceId,
    targetId,
    amount
});
```

Consumers can include:

- floating damage numbers
- sound
- particles
- camera shake
- analytics
- UI

Do not turn EventBus into a hidden global dependency for everything.

Prefer direct dependencies when a relationship is simple and explicit.

---

# 20. Save System

Use an adapter:

```ts
interface StorageAdapter {
    save<T>(key: string, value: T): Promise<void>;
    load<T>(key: string): Promise<T | null>;
    delete(key: string): Promise<void>;
}
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

Save data must be versioned.

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

Always support migrations when the save format changes.

---

# 21. Error Handling

Never silently swallow errors.

BAD:

```ts
try {
   ...
} catch {
}
```

GOOD:

```ts
try {
   ...
} catch (error) {
   logger.error("Failed to load save", error);
   ...
}
```

User-facing errors should be graceful.

Developer errors should contain useful context.

---

# 22. TypeScript Rules

Use strict TypeScript.

Recommended:

```json
{
    "compilerOptions": {
        "strict": true,
        "noUncheckedIndexedAccess": true,
        "noImplicitOverride": true,
        "noFallthroughCasesInSwitch": true
    }
}
```

Rules:

- avoid `any`
- prefer `unknown` when type is genuinely unknown
- use discriminated unions
- use readonly data where appropriate
- avoid unsafe casts
- type public APIs explicitly
- keep types close to their domain

Never use `as any` to silence a compiler problem.

---

# 23. Naming

Use:

```text
PascalCase   classes
camelCase    variables/functions
UPPER_CASE   true constants when appropriate
```

Examples:

```ts
class CombatSystem {}

const playerState = {};

function calculateDamage() {}
```

Names should describe intent.

Avoid:

```text
ManagerManager
Utils2
Thing
Data
Stuff
Helper
```

unless the name genuinely communicates responsibility.

---

# 24. File Size

Prefer small modules.

Warning threshold:

- ~300 lines: review responsibility
- ~500 lines: strongly consider splitting
- ~800+ lines: almost always split

These are guidelines, not hard compiler rules.

A file should have one clear reason to change.

---

# 25. Dependency Rules

Before adding a package, ask:

1. Is the problem real?
2. Can Phaser/TypeScript solve it?
3. Can a small local module solve it?
4. Is the dependency maintained?
5. Does it increase bundle size significantly?
6. Does it create architectural coupling?

Do not add dependencies automatically.

---

# 26. React Rule

If React is used:

React owns:

- menus
- inventory UI
- settings
- meta-game UI
- complex dialogs

Phaser owns:

- world
- sprites
- enemies
- particles
- gameplay animations
- game camera
- gameplay interaction

Never render the entire game world with React DOM.

---

# 27. Zustand Rule

If Zustand is used, reserve it primarily for UI/meta state.

Good:

```text
menu open
selected inventory item
settings
volume
language
```

Avoid putting every entity's position into Zustand.

Gameplay simulation should remain inside the game architecture.

---

# 28. Testing Strategy

Unit test pure logic first.

High-value tests:

```text
combat damage calculation
armor/resistance
inventory operations
item stacking
quest progression
AI state transitions
save migrations
random utilities
geometry/math
```

Example:

```ts
describe("damage calculation", () => {
    it("applies armor correctly", () => {
        ...
    });
});
```

Use Playwright for:

- game boot
- loading
- main menu
- starting a game
- basic player interaction
- save/load smoke tests

Do not attempt to test every visual detail with E2E tests.

---

# 29. Git Rules

Commits should describe intent.

Good:

```text
feat: add enemy chase state
fix: prevent duplicate loot drops
perf: pool floating damage numbers
refactor: isolate combat calculations
```

Bad:

```text
changes
stuff
fix
update
```

Do not mix unrelated features and refactors in one commit.

---

# 30. AI Coding Agent Rules

The AI agent MUST:

1. Read this file before making architectural changes.
2. Inspect existing code before creating new abstractions.
3. Reuse existing systems where appropriate.
4. Avoid duplicate managers/services.
5. Avoid creating unnecessary dependencies.
6. Preserve existing behavior unless the task explicitly changes it.
7. Keep TypeScript strict.
8. Run type checking after meaningful changes.
9. Run relevant tests after meaningful changes.
10. Avoid unrelated refactors.
11. Explain architectural trade-offs when introducing a new system.
12. Prefer incremental changes.
13. Never rewrite large portions of the project without a clear reason.
14. Never use `any` as a shortcut.
15. Never hide errors.
16. Never put business/gameplay logic into rendering classes.
17. Never put rendering responsibilities into domain systems.
18. Never introduce a global singleton unless there is a strong architectural reason.
19. Never duplicate game state between multiple stores without synchronization rules.
20. Keep public APIs small and explicit.

---

# 31. Before Editing Code

The agent should first determine:

```text
What system owns this behavior?
What is the source of truth?
Does a similar implementation already exist?
Does this belong to domain, system, rendering, UI, or infrastructure?
Will this create a dependency cycle?
Can this be tested independently?
```

Only then modify the code.

---

# 32. New Feature Workflow

For a new feature:

```text
1. Understand existing architecture
2. Identify domain state
3. Define types
4. Define system behavior
5. Integrate with Scene
6. Add rendering/UI
7. Add audio/feedback
8. Add persistence if required
9. Add tests
10. Run typecheck/lint/tests
11. Review performance
```

Do not start by writing the visual effect.

Start with the gameplay contract.

---

# 33. Example Feature: New Enemy

Correct workflow:

```text
enemy data
   ↓
EnemyDefinition
   ↓
EnemyFactory
   ↓
EnemyState
   ↓
AIController
   ↓
AISystem
   ↓
CombatSystem
   ↓
EnemyRenderer
```

Do not put all of this into `Goblin.ts`.

---

# 34. Example Feature: New Weapon

```text
weapon JSON
   ↓
WeaponDefinition
   ↓
WeaponDatabase
   ↓
Weapon runtime object
   ↓
CombatSystem
   ↓
Damage
   ↓
Effects
```

Weapon balance should be data-driven.

---

# 35. Example Feature: New Quest

```text
quest data
   ↓
QuestDefinition
   ↓
QuestManager
   ↓
Objective tracking
   ↓
Quest state
   ↓
EventBus
   ↓
UI notification
   ↓
Reward system
```

Quest UI must not own quest progression logic.

---

# 36. Visual Quality Rules

For the top-down presentation, prioritize:

1. readable silhouettes
2. consistent pixel/world scale
3. clear depth ordering
4. lighting consistency
5. animation quality
6. hit feedback
7. particles
8. camera feedback
9. environmental motion
10. atmospheric effects

Do not compensate for poor art direction by adding excessive shaders.

The visual hierarchy must remain readable during combat.

---

# 37. Layering / Depth

Establish a consistent depth strategy.

Example:

```text
Ground
GroundDetails
Shadows
Entities
EffectsBelow
Player
EffectsAbove
Projectiles
Particles
UI
```

Do not manually assign arbitrary depths throughout the codebase.

Centralize depth constants where possible.

---

# 38. Mobile Support

Assume touch devices matter.

The game should account for:

- different resolutions
- aspect ratios
- device pixel ratio
- touch controls
- safe UI margins
- performance limitations
- browser lifecycle/backgrounding

Never assume a fixed 1920x1080 viewport.

Use responsive camera and UI logic.

---

# 39. Accessibility / UX

Where practical:

- configurable volume
- configurable controls
- readable text
- sufficient contrast
- reduced screen shake option
- reduced visual effects option
- pause behavior
- touch-friendly UI

Gameplay readability takes priority over visual effects.

---

# 40. Performance Budget

Treat performance as a feature.

Monitor:

```text
FPS
frame time
draw calls
texture memory
active entities
particle count
AI update cost
pathfinding cost
heap allocations
```

When performance drops:

1. profile
2. identify bottleneck
3. measure change
4. keep optimization only if it improves the real bottleneck

Do not perform speculative micro-optimizations everywhere.

---

# 41. Security / Robustness

Never trust external data blindly.

Validate:

- save files
- imported JSON
- user-generated content
- URL parameters
- network responses

Do not execute arbitrary strings as JavaScript.

Avoid dynamic code generation.

---

# 42. Definition of Done

A feature is not complete merely because it works visually.

Before considering a feature done:

```text
[ ] Architecture location is correct
[ ] Types are defined
[ ] No unnecessary dependency added
[ ] No obvious circular dependency
[ ] Gameplay and rendering are separated
[ ] Error handling exists
[ ] Relevant tests exist
[ ] TypeScript passes
[ ] ESLint passes
[ ] Performance is acceptable
[ ] Mobile behavior considered
[ ] Save compatibility considered if relevant
[ ] No unrelated code changed
```

---

# 43. Priority Order

When trade-offs are necessary, prioritize:

```text
1. Correctness
2. Player experience
3. Maintainability
4. Performance
5. Visual quality
6. Developer convenience
```

Do not sacrifice correctness for visual polish.

Do not sacrifice maintainability for a short-term implementation unless explicitly requested.

---

# 44. Architectural North Star

The project should evolve toward:

```text
                    ┌─────────────┐
                    │    Phaser   │
                    │   Runtime   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Scenes    │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         Input Layer   Game Systems   Rendering
              │            │            │
              │      ┌─────┼─────┐      │
              │      ▼     ▼     ▼      │
              │     AI   Combat World   │
              │            │            │
              └────────────┼────────────┘
                           ▼
                     Domain State
                           │
                  ┌────────┼────────┐
                  ▼        ▼        ▼
                Save      Data      Events
```

The exact implementation may evolve, but responsibilities must remain clearly separated.

---

# 45. Final Agent Instruction

When uncertain, do not immediately create more architecture.

First inspect the repository.

Prefer the smallest change that:

- satisfies the requirement,
- fits the existing architecture,
- preserves testability,
- preserves performance,
- does not introduce unnecessary coupling.

If a requested change conflicts with this constitution, explain the conflict before making a major architectural deviation.

The goal is not to produce the most code.

The goal is to produce a game codebase that can continue growing for years without collapsing under its own complexity.
