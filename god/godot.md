# Phaser → Godot 4 Migration Plan

## 1. Cel projektu

Migrujemy istniejącą grę 2D top-down stworzoną w Phaser + JavaScript/TypeScript do Godot 4.

### Source
- Phaser
- JavaScript/TypeScript
- istniejące assety
- istniejące mapy
- istniejąca logika gameplay
- istniejący UI
- istniejący system audio
- istniejące dane gry

### Target
- Godot 4.x
- GDScript
- VS Code
- Git
- Claude Code jako AI coding agent

### Główna zasada
Nie wykonuj mechanicznego tłumaczenia kodu Phaser → GDScript.
Migruj funkcjonalność i zachowanie gry, dostosowując architekturę do Godot.

---

# 2. Zasady migracji

## Zasada 1 — Source pozostaje nietknięty

Oryginalny projekt Phaser musi pozostać działający.

Nigdy nie usuwaj ani nie nadpisuj źródłowych plików podczas migracji.

Preferowana struktura:

```text
project/
├── phaser/
└── godot/
```

lub dwa osobne repozytoria.

## Zasada 2 — najpierw analiza, potem kod

Claude Code NIE może rozpocząć przepisywania kodu przed wykonaniem pełnego audytu projektu.

Najpierw należy zidentyfikować:
- sceny
- systemy
- klasy
- moduły
- encje
- assety
- mapy
- animacje
- audio
- UI
- input
- fizykę
- kolizje
- AI
- combat
- inventory
- save/load
- eventy
- konfigurację
- zależności
- biblioteki zewnętrzne

---

# 3. Faza 0 — audyt Phaser

Claude Code ma przygotować:

```text
PHASER_AUDIT.md
```

Dokument powinien zawierać:

## Scenes
Lista wszystkich scen:
- Boot
- Preloader
- MainMenu
- Game
- GameOver
- itd.

## Systems
Lista systemów:
- Player
- Enemies
- Combat
- Inventory
- Items
- Quest
- UI
- Audio
- Camera
- World
- Save
- Settings
- itd.

## Dependencies
Lista:
- npm packages
- Phaser plugins
- własne biblioteki
- helpery
- utility modules

## Assets
Lista:
- sprites
- sprite sheets
- tilesets
- tilemaps
- audio
- fonts
- shaders
- particles
- JSON
- konfiguracje

## Runtime dependencies
Określ, które systemy zależą od których.

Przykład:

```text
Player
 ├── Input
 ├── Movement
 ├── Animation
 ├── Combat
 ├── Health
 └── Inventory
```

---

# 4. Faza 1 — mapa architektury

Claude Code powinien utworzyć:

```text
MIGRATION_ARCHITECTURE.md
```

Zawierający mapowanie:

| Phaser | Godot |
|---|---|
| Scene | Scene (.tscn) |
| GameObject | Node |
| Sprite | Sprite2D |
| Container | Node2D |
| Text | Label |
| Image | Sprite2D |
| Group | Groups |
| EventEmitter | Signals |
| Arcade Physics | Godot Physics |
| Collider | CollisionShape2D |
| Tilemap | TileMapLayer |
| Animation | AnimationPlayer / AnimatedSprite2D |
| Data object | Resource |
| Config | Resource |
| Global manager | Autoload |
| Timer | Timer |
| Camera | Camera2D |
| Particle system | GPUParticles2D |
| Shader | Godot Shader |
| Input | InputMap / Input actions |

---

# 5. Faza 2 — przygotowanie projektu Godot

Utwórz:

```text
godot/
├── project.godot
├── scenes/
├── scripts/
├── assets/
├── data/
├── shaders/
├── audio/
├── ui/
├── resources/
└── tests/
```

Docelowo:

```text
godot/
├── project.godot
│
├── assets/
│   ├── sprites/
│   ├── textures/
│   ├── tilesets/
│   ├── fonts/
│   └── vfx/
│
├── audio/
│   ├── music/
│   ├── sfx/
│   └── ambience/
│
├── scenes/
│   ├── bootstrap/
│   ├── player/
│   ├── enemies/
│   ├── world/
│   ├── ui/
│   └── levels/
│
├── scripts/
│   ├── core/
│   ├── player/
│   ├── enemies/
│   ├── combat/
│   ├── inventory/
│   ├── world/
│   ├── ui/
│   ├── audio/
│   └── services/
│
├── data/
│   ├── items/
│   ├── enemies/
│   ├── weapons/
│   └── levels/
│
├── resources/
├── shaders/
└── tests/
```

---

# 6. Faza 3 — migracja assetów

Przenieś assety bez zmiany ich zawartości.

Najpierw:
- sprites
- textures
- tilesets
- fonts
- audio

Następnie:
- animations
- particles
- shaders

Nie optymalizuj assetów podczas pierwszej migracji.
Najpierw zachowaj funkcjonalność.

---

# 7. Faza 4 — Input

Przenieś wszystkie akcje użytkownika.

Przykład:

```text
move_up
move_down
move_left
move_right
attack
interact
inventory
pause
```

W Godot skonfiguruj:

```text
Project Settings
→ Input Map
```

Kod nie powinien bezpośrednio zależeć od konkretnych klawiszy.

Preferuj:

```gdscript
Input.get_vector(
    "move_left",
    "move_right",
    "move_up",
    "move_down"
)
```

---

# 8. Faza 5 — Player

Player jest pierwszym pełnym systemem gameplay.

Kolejność:

```text
Player Scene
↓
Movement
↓
Collision
↓
Animation
↓
Health
↓
Combat
↓
Interaction
↓
Inventory
```

Preferowana struktura:

```text
Player
├── CharacterBody2D
├── CollisionShape2D
├── Sprite2D / AnimatedSprite2D
├── Camera2D
├── InteractionArea
├── Hurtbox
└── AnimationPlayer
```

Nie twórz jednego ogromnego `player.gd`.
Logikę dziel na komponenty/systemy.

---

# 9. Faza 6 — World

Migruj:
- Tilemaps
- Collision
- Objects
- Triggers
- Doors
- Interactables
- Spawn points
- World boundaries
- Camera boundaries

Każdy element powinien być osobną sceną, jeśli jest wielokrotnie używany.

Przykład:

```text
Door.tscn
Chest.tscn
NPC.tscn
EnemySpawner.tscn
Pickup.tscn
```

---

# 10. Faza 7 — Enemies

Dla każdego przeciwnika zachowaj:
- movement
- detection
- targeting
- attack
- damage
- health
- death
- animation
- drops

Jeśli Phaser posiada state machine, przenieś koncepcję state machine, ale zaprojektuj ją idiomatycznie dla Godot.

Przykład:

```text
Enemy
├── Idle
├── Patrol
├── Chase
├── Attack
├── Hurt
└── Dead
```

---

# 11. Faza 8 — Combat

Combat powinien zostać wydzielony jako niezależny system.

Docelowo:

```text
Combat
├── Damage
├── Health
├── Hitbox
├── Hurtbox
├── Attack
├── Weapon
├── StatusEffect
└── Death
```

Dane obrażeń nie powinny być rozsiane po kodzie.

Preferuj Resources:

```gdscript
class_name DamageData
extends Resource

@export var amount: float
@export var knockback: float
@export var critical: bool
```

---

# 12. Faza 9 — Items / Inventory

Najpierw przenieś dane:
- Item
- Weapon
- Armor
- Consumable
- QuestItem
- Currency

Następnie inventory.

Statyczne dane powinny znajdować się w:

```text
Resource
```

np.:

```text
data/items/
├── sword.tres
├── potion.tres
└── armor.tres
```

Logika inventory powinna być oddzielona od UI.

---

# 13. Faza 10 — UI

Migruj:
- HUD
- Health bar
- Mana/stamina
- Inventory
- Tooltip
- Menus
- Pause
- Dialogs
- Notifications
- Damage numbers

Godot:

```text
Control
├── Panel
├── Label
├── TextureRect
├── ProgressBar
├── Button
└── Container
```

UI nie może zawierać głównej logiki gameplay.

Przykład:

```text
Inventory System
       ↓
Inventory UI
```

a nie:

```text
Inventory UI
       ↓
cała logika inventory
```

---

# 14. Faza 11 — Audio

Przenieś:
- Music
- SFX
- Ambience
- UI sounds
- Combat sounds
- Footsteps

Utwórz centralny:

```text
AudioManager
```

Audio powinno być wywoływane przez API systemu audio, a nie przez bezpośrednie manipulowanie odtwarzaczami w każdym skrypcie.

---

# 15. Faza 12 — Save / Load

Najpierw dokładnie zidentyfikuj dane zapisywane w Phaser.

Podziel je na:

```text
PlayerState
WorldState
InventoryState
QuestState
Settings
Progress
```

Nie zapisuj bezpośrednio całych Node'ów.
Zapisuj dane.

Przykład:

```text
SaveData
├── player
├── inventory
├── quests
├── world
└── settings
```

---

# 16. Faza 13 — Game State

Utwórz centralny system stanu gry:

```text
BOOT
MENU
PLAYING
PAUSED
GAME_OVER
LOADING
```

Nie używaj przypadkowych globalnych flag.

---

# 17. Faza 14 — Signals / Events

Phaser EventEmitter powinien zostać zastąpiony przez Godot Signals tam, gdzie jest to naturalne.

Przykład:

```text
Player
  ↓
health_changed
  ↓
HUD
```

oraz:

```text
Enemy
  ↓
died
  ↓
Quest System
```

Unikaj tworzenia jednego globalnego event busa dla wszystkiego.

---

# 18. Faza 15 — Vertical Slice

Przed migracją całej gry należy doprowadzić do działania pełny vertical slice:

```text
Start
 ↓
Load level
 ↓
Player movement
 ↓
Enemy
 ↓
Combat
 ↓
Damage
 ↓
Death
 ↓
Loot
 ↓
UI
 ↓
Save
 ↓
Load
```

Dopiero po jego poprawnym działaniu kontynuuj migrację reszty gry.

---

# 19. Faza 16 — porównanie Phaser vs Godot

Dla każdej ważnej mechaniki przygotuj:

```text
PHASER_BEHAVIOR.md
```

Określ:
- Input
- Expected behavior
- Physics
- Timing
- Animation
- Collision
- Damage
- State transitions
- Edge cases

Godot powinien zachowywać się funkcjonalnie tak samo, chyba że świadomie zmieniamy mechanikę.

---

# 20. Faza 17 — testy

Każdy ważny system powinien otrzymać testy.

Minimum:

```text
tests/
├── combat/
├── inventory/
├── save/
├── player/
└── enemies/
```

Testuj:
- damage
- health
- death
- inventory
- item stacking
- save/load
- enemy states
- movement
- game state

---

# 21. Faza 18 — optymalizacja

Nie optymalizuj przed uzyskaniem poprawnej wersji.

Po migracji:

```text
Profile
↓
Identify bottleneck
↓
Measure
↓
Optimize
↓
Measure again
```

Szczególnie sprawdź:
- `_process`
- `_physics_process`
- liczbę instancji Node
- particles
- draw calls
- texture sizes
- audio
- allocations
- pathfinding
- AI
- collision checks

---

# 22. Faza 19 — usuwanie kodu Phaser

Kod Phaser pozostaje nietknięty do momentu pełnej migracji.

Dopiero gdy:

```text
Godot Feature = Complete
Godot Feature = Tested
Godot Feature = Playtested
```

można oznaczyć odpowiednią część Phaser jako:

```text
MIGRATED
```

Po zakończeniu całego projektu:

```text
Phaser
→ archive
```

Nigdy nie usuwaj starego projektu przed końcową akceptacją.

---

# 23. Definition of Done

System uznajemy za zmigrowany dopiero, gdy:
- kod działa
- projekt się kompiluje
- nie ma błędów runtime
- mechanika działa jak w Phaser
- assety są poprawne
- animacje działają
- kolizje działają
- UI działa
- system ma testy, jeśli jest to uzasadnione
- nie powstały duplikaty istniejących systemów
- architektura pozostaje spójna
- Claude Code wykonał końcowy review

---

# 24. Kolejność migracji

Priorytet:

```text
1. Audit
2. Godot project
3. Assets
4. Input
5. Core
6. Player
7. World
8. Combat
9. Enemies
10. Items
11. Inventory
12. UI
13. Audio
14. Save/Load
15. Remaining gameplay
16. VFX
17. Optimization
18. Tests
19. Final QA
```

---

# 25. Zasada dla Claude Code

Claude Code ma pracować małymi, kontrolowanymi etapami.

Nigdy:

```text
"Rewrite entire project."
```

Preferuj:

```text
Analyze
→ Plan
→ Implement
→ Test
→ Review
→ Commit
→ Next system
```

Każdy etap powinien kończyć się działającym projektem.

---

# 26. Git strategy

Przed każdym większym systemem:

```text
git checkout -b migration/player
```

Po zakończeniu:

```text
commit
```

Przykładowe commity:

```text
migration: create Godot project
migration: import assets
migration: implement input system
migration: migrate player movement
migration: migrate player combat
migration: migrate enemy system
migration: migrate inventory
migration: migrate UI
migration: migrate save system
migration: complete migration
```

---

# 27. Final architecture

Docelowo projekt powinien wyglądać mniej więcej tak:

```text
Godot
│
├── Core
│   ├── GameState
│   ├── Events
│   └── Services
│
├── Gameplay
│   ├── Player
│   ├── Enemies
│   ├── Combat
│   ├── Items
│   └── World
│
├── Presentation
│   ├── UI
│   ├── Animation
│   ├── VFX
│   └── Audio
│
├── Data
│   ├── Items
│   ├── Enemies
│   ├── Weapons
│   └── Levels
│
└── Infrastructure
    ├── Save
    ├── Settings
    └── Persistence
```

Najważniejszym kryterium jest zachowanie gameplayu przy jednoczesnym uzyskaniu architektury natywnej dla Godot.

---

# CLAUDE CODE — PHASER TO GODOT MIGRATION

You are a senior game-engine migration engineer.

We have an existing Phaser game that must be migrated to Godot 4.

Your job is NOT to blindly translate JavaScript/TypeScript into GDScript.

Your job is to preserve the game's gameplay, behavior, data and visual intent while rebuilding the architecture using idiomatic Godot 4 patterns.

## CRITICAL RULE

DO NOT MODIFY THE EXISTING PHASER PROJECT DURING THE AUDIT.

DO NOT START IMPLEMENTING THE GODOT VERSION YET.

FIRST ANALYZE THE ENTIRE PHASER PROJECT.

---

# PHASE 1 — COMPLETE AUDIT

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

# PHASE 2 — BUILD A SYSTEM MAP

Create:

```text
PHASER_AUDIT.md
```

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

# PHASE 3 — GODOT ARCHITECTURE

Create:

```text
MIGRATION_ARCHITECTURE.md
```

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

Keep scene scripts small and focused.

---

# PHASE 4 — MIGRATION MATRIX

Create:

```text
MIGRATION_MATRIX.md
```

Use this format:

| System | Phaser files | Godot target | Complexity | Dependencies | Status |
|---|---|---|---|---|---|

Statuses:

NOT_STARTED
ANALYZED
IN_PROGRESS
IMPLEMENTED
TESTED
PLAYTESTED
COMPLETE

---

# PHASE 5 — DO NOT IMPLEMENT YET

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

# IMPLEMENTATION RULES

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

# AFTER EACH MIGRATION

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

# FINAL GOAL

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
