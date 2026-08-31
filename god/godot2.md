# GODOT 4 — SENIOR GAME DEVELOPMENT & PHASER → GODOT MIGRATION MASTER PLAN

> Cel: profesjonalna, skalowalna migracja istniejącej gry 2D top-down z Phaser/JavaScript/TypeScript do Godot 4, z wykorzystaniem VS Code + Claude Code.
>
> Ten dokument jest jednocześnie:
> - planem migracji,
> - standardem architektonicznym,
> - zasadami pracy dla AI coding agenta,
> - checklistą jakości,
> - Definition of Done dla kolejnych etapów.

---

# 0. ROLA CLAUDE CODE

Podczas tego projektu działasz jako:

**Senior/Lead Game Developer specjalizujący się w Godot 4, architekturze gier 2D, gameplay engineering, performance, tooling, automated testing oraz migracjach z innych silników.**

Masz podejmować decyzje jak lead developer odpowiedzialny za długoterminową jakość kodu.

Nie jesteś generatorem kodu.

Jesteś inżynierem odpowiedzialnym za:
- architekturę,
- spójność systemów,
- maintainability,
- wydajność,
- testowalność,
- bezpieczeństwo danych,
- możliwość dalszego rozwoju gry przez człowieka i AI.

---

# 1. NAJWAŻNIEJSZA ZASADA

## NIE PRZEPISUJ PHASERA 1:1

Phaser i Godot mają różne modele programistyczne.

Nie wykonuj:

```text
Phaser class
↓
GDScript class

Phaser Scene
↓
Godot Scene

Phaser EventEmitter
↓
global EventBus

Phaser Manager
↓
Godot Manager
```

automatycznie.

Najpierw zrozum odpowiedzialność systemu.

Następnie zaprojektuj jego odpowiednik zgodnie z idiomami Godot.

---

# 2. ZASADY NIENARUSZALNE

Claude Code MUST:

1. Nie niszczyć działającej wersji Phaser.
2. Nie usuwać kodu bez potwierdzenia.
3. Nie przepisywać całego projektu jedną operacją.
4. Nie tworzyć ogromnych klas typu `GameManager`.
5. Nie używać globalnego stanu bez uzasadnienia.
6. Nie używać `get_node()` w przypadkowych miejscach jako substytutu architektury.
7. Nie nadużywać Autoloadów.
8. Nie nadużywać sygnałów.
9. Nie używać `find_*` jako podstawowego mechanizmu komunikacji systemów.
10. Nie mieszać logiki gameplay z prezentacją.
11. Nie wkładać danych gry na sztywno do skryptów.
12. Nie optymalizować bez pomiaru.
13. Nie zmieniać zachowania gameplayu bez udokumentowania.
14. Nie zakładać, że kod wygenerowany przez AI jest poprawny.
15. Po każdej większej zmianie wykonywać walidację.
16. Przy wykryciu istniejącego rozwiązania najpierw je zrozumieć, a dopiero potem tworzyć nowe.
17. Nie tworzyć duplikatów systemów.
18. Każdy większy system musi mieć jasno określoną odpowiedzialność.

---

# 3. TARGET TECHNOLOGY STACK

## Engine

Godot 4.x.

Przed rozpoczęciem implementacji sprawdź dokładną wersję Godot używaną w projekcie.

Nie zakładaj API z innej wersji.

## Language

Preferowany:

```text
GDScript
```

Jeżeli istnieje konkretny powód użycia C#, najpierw udokumentuj decyzję.

## Editor

VS Code.

## Version control

Git.

## AI

Claude Code.

## Rendering

Dla projektu 2D użyj renderera odpowiedniego do target platform.

Nie zmieniaj renderera bez uzasadnienia i testów na docelowych urządzeniach.

## Input

Godot InputMap / Input actions.

## Data

Godot Resources (`.tres` / `.res`) dla danych konfiguracyjnych i statycznych.

## Testing

Godot Test Framework / istniejący uzgodniony framework testowy projektu.

Nie dodawaj frameworka tylko dlatego, że jest popularny. Najpierw oceń potrzeby projektu.

---

# 4. FAZA 0 — DISCOVERY / FREEZE

Przed migracją:

1. Utwórz branch migracyjny.
2. Zabezpiecz aktualny stan Phaser.
3. Uruchom istniejącą grę.
4. Potwierdź, że wersja bazowa działa.
5. Zapisz aktualny commit/tag.
6. Nie zmieniaj gameplayu w wersji bazowej.

Przykładowy punkt bazowy:

```text
migration-baseline
```

---

# 5. FAZA 1 — PEŁNY AUDYT PHASER

Claude Code musi przeanalizować cały projekt.

Nie tylko:

```text
src/
```

ale również:

```text
package.json
tsconfig.json
vite.config.*
webpack.*
assets/
public/
config/
tests/
scripts/
README*
```

oraz wszystkie inne istotne pliki.

## Zidentyfikuj

### Entry points

- bootstrap
- game initialization
- preload
- main scene
- routing
- startup services

### Scenes

- Boot
- Loading
- Main Menu
- Gameplay
- Pause
- Game Over
- inne

### Gameplay systems

- player
- movement
- combat
- enemies
- AI
- inventory
- items
- quests
- NPC
- interactions
- world
- spawning
- progression
- economy

### Presentation

- camera
- animation
- VFX
- shaders
- UI
- particles
- screen effects

### Infrastructure

- save/load
- settings
- audio
- input
- localization
- analytics, jeśli występują
- networking, jeśli występuje

---

# 6. AUDYT MUSI POWSTAĆ W PLIKACH

Claude Code tworzy:

```text
docs/migration/
├── PHASER_AUDIT.md
├── ARCHITECTURE_MAP.md
├── DEPENDENCY_GRAPH.md
├── ASSET_INVENTORY.md
├── GAMEPLAY_BEHAVIOR.md
├── DATA_MODEL.md
├── MIGRATION_RISKS.md
└── MIGRATION_MATRIX.md
```

---

# 7. ARCHITECTURE MAP

Dla każdego systemu zapisz:

```text
System:
Responsibility:
Entry points:
Dependencies:
Consumers:
State:
Events:
Data:
Rendering:
Persistence:
Performance sensitivity:
Migration strategy:
```

Przykład:

```text
Player Combat

Responsibility:
Perform attacks and apply damage.

Dependencies:
Input
WeaponData
HitDetection
Animation

Consumers:
HUD
Audio
VFX
QuestSystem

State:
Idle / Attacking / Cooldown / Hurt / Dead

Migration strategy:
Rebuild using composition and Resources.
```

---

# 8. MIGRATION MATRIX

Utwórz:

```text
docs/migration/MIGRATION_MATRIX.md
```

Tabela:

| System | Phaser files | Godot target | Complexity | Risk | Dependencies | Status |
|---|---|---|---|---|---|---|

Status:

```text
NOT_ANALYZED
ANALYZED
PLANNED
IN_PROGRESS
IMPLEMENTED
TESTED
PLAYTESTED
VERIFIED
COMPLETE
BLOCKED
```

Nie oznaczaj systemu jako `COMPLETE`, jeśli nie przeszedł testów i playtestu.

---

# 9. TARGET ARCHITECTURE

Docelowo:

```text
Godot Project
│
├── assets/
│
├── scenes/
│   ├── bootstrap/
│   ├── player/
│   ├── enemies/
│   ├── world/
│   ├── interactables/
│   ├── levels/
│   └── ui/
│
├── scripts/
│   ├── core/
│   ├── gameplay/
│   │   ├── player/
│   │   ├── combat/
│   │   ├── enemies/
│   │   ├── inventory/
│   │   ├── items/
│   │   ├── quests/
│   │   └── world/
│   │
│   ├── presentation/
│   │   ├── animation/
│   │   ├── vfx/
│   │   ├── camera/
│   │   └── ui/
│   │
│   └── infrastructure/
│       ├── save/
│       ├── audio/
│       ├── input/
│       └── settings/
│
├── data/
│   ├── items/
│   ├── weapons/
│   ├── enemies/
│   ├── characters/
│   └── levels/
│
├── shaders/
├── audio/
├── tests/
└── docs/
```

Struktura może zostać zmieniona, jeśli rzeczywista gra wymaga lepszego podziału. Nie traktuj jej jako dogmatu.

---

# 10. GODOT SCENE DESIGN

Preferuj małe, wielokrotnego użycia sceny.

Przykłady:

```text
Player.tscn
Enemy.tscn
Chest.tscn
Door.tscn
Pickup.tscn
NPC.tscn
Projectile.tscn
DamageNumber.tscn
```

Przykładowy Player:

```text
Player (CharacterBody2D)
├── Visuals
│   └── AnimatedSprite2D
├── CollisionShape2D
├── Hurtbox
│   └── CollisionShape2D
├── Hitbox
│   └── CollisionShape2D
├── InteractionArea
│   └── CollisionShape2D
├── Camera2D
└── AnimationPlayer
```

Nie oznacza to, że każdy Player musi mieć dokładnie taką strukturę.

Projektuj pod rzeczywiste wymagania.

---

# 11. COMPOSITION OVER INHERITANCE

Preferuj:

```text
Character
├── Health
├── Movement
├── Combat
├── Targeting
├── Inventory
└── Interaction
```

zamiast:

```text
BaseCharacter
    ↓
BaseCombatCharacter
    ↓
BaseEnemy
    ↓
BaseMeleeEnemy
    ↓
EliteMeleeEnemy
    ↓
BossMeleeEnemy
```

Dziedziczenie stosuj tylko wtedy, gdy relacja jest rzeczywiście stabilna i upraszcza projekt.

---

# 12. MONOBEHAVIOUR-LIKE ANTI-PATTERNS

W Godot unikaj ogromnych skryptów attached do jednego Node.

Zły przykład:

```text
Player.gd
- movement
- combat
- inventory
- quests
- audio
- UI
- save
- achievements
```

Lepszy:

```text
Player
├── PlayerMovement
├── PlayerCombat
├── PlayerHealth
├── PlayerInteractor
└── PlayerInventory
```

lub logiczne klasy usługowe, jeśli system nie wymaga Node.

---

# 13. DATA-DRIVEN DESIGN

Statyczne dane nie powinny być zakodowane:

```gdscript
if weapon_id == "sword":
    damage = 25
```

Preferuj:

```text
WeaponData
ItemData
EnemyData
CharacterData
LevelData
```

jako Resources.

Przykład:

```gdscript
class_name WeaponData
extends Resource

@export var id: StringName
@export var damage: float
@export var attack_speed: float
@export var range: float
@export var knockback: float
```

Dane gameplay muszą być możliwe do zmiany bez przepisywania logiki.

---

# 14. IDENTIFIERS

Dla danych gry preferuj stabilne identyfikatory.

Przykład:

```text
weapon.iron_sword
item.health_potion
enemy.goblin
quest.intro_001
```

Nie polegaj na nazwach wyświetlanych graczowi.

---

# 15. INPUT ARCHITECTURE

Wszystkie akcje przechodzą przez InputMap.

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

Gameplay nie powinien wiedzieć, czy akcję wywołała:

- klawiatura,
- gamepad,
- touch,
- inny input device.

---

# 16. MOVEMENT

Dla top-down 2D wybierz odpowiedni Godot body type.

Najczęściej:

```text
CharacterBody2D
```

Ruch powinien być oddzielony od:

- animacji,
- combat,
- UI,
- audio.

Nie wykonuj przypadkowych transformacji pozycji, jeśli fizyka i kolizje wymagają `move_and_slide()` lub odpowiedniego mechanizmu.

---

# 17. COLLISION ARCHITECTURE

Zdefiniuj warstwy i maski przed masową migracją.

Przygotuj dokument:

```text
docs/architecture/COLLISION_MATRIX.md
```

Przykład:

```text
Layer 1: World
Layer 2: Player
Layer 3: Enemy
Layer 4: PlayerHitbox
Layer 5: EnemyHitbox
Layer 6: Interactions
```

Nie kopiuj liczb z tego przykładu bez analizy istniejącej gry.

---

# 18. COMBAT ARCHITECTURE

Combat powinien mieć wyraźne granice:

```text
Attack
↓
Hit Detection
↓
Damage Request
↓
Damage Resolution
↓
Health
↓
Death
↓
Rewards / Drops
↓
VFX / Audio / UI
```

Nie pozwól, aby UI bezpośrednio modyfikowało health.

---

# 19. DAMAGE MODEL

Wprowadź jasno zdefiniowane dane:

```text
DamageContext
├── source
├── target
├── amount
├── type
├── critical
├── knockback
├── status effects
└── metadata
```

Jeżeli gra tego nie potrzebuje, nie komplikuj systemu.

Architektura ma wynikać z wymagań, nie z potrzeby pokazania „zaawansowanego kodu”.

---

# 20. STATE MACHINES

State machine stosuj tam, gdzie liczba stanów i przejść uzasadnia ich użycie.

Dla AI:

```text
Idle
Patrol
Investigate
Chase
Attack
Hurt
Flee
Dead
```

Każdy stan powinien mieć:

```text
enter
update
exit
```

Nie twórz state machine dla prostego obiektu, który ma dwa stany.

---

# 21. AI

AI powinno być niezależne od UI.

Oddziel:

```text
Perception
Decision
Navigation
Action
Animation
```

Przykład:

```text
Enemy
 ↓
Perception
 ↓
Decision
 ↓
Action
 ↓
Animation
```

Nie steruj AI przez przypadkowe flagi UI.

---

# 22. NAVIGATION

Jeśli gra korzysta z pathfindingu:

1. Zidentyfikuj obecne rozwiązanie Phaser.
2. Określ wymagania.
3. Dopiero wtedy wybierz odpowiednie Godot Navigation API.
4. Przetestuj zachowanie na rzeczywistych mapach.

Nie zamieniaj pathfindingu na prosty `move_toward()` tylko dlatego, że jest łatwiejszy.

---

# 23. WORLD / LEVELS

Level powinien być kompozycją scen i danych.

Unikaj jednej gigantycznej sceny zawierającej wszystko.

Preferuj:

```text
Level
├── Tilemap
├── StaticObjects
├── Interactables
├── Enemies
├── SpawnPoints
├── Triggers
└── WorldLogic
```

Jeżeli świat jest duży, zaplanuj streaming/chunking dopiero po zmierzeniu realnych potrzeb.

---

# 24. TILEMAP MIGRATION

Jeśli Phaser korzysta z Tiled:

1. Zidentyfikuj format map.
2. Zidentyfikuj tilesety.
3. Zidentyfikuj object layers.
4. Zidentyfikuj collision layers.
5. Zidentyfikuj custom properties.
6. Zidentyfikuj spawn points.
7. Zidentyfikuj trigger zones.

Nie zakładaj, że import mapy zachowa wszystkie zachowania.

Każda funkcja mapy musi zostać zweryfikowana.

---

# 25. ANIMATION

Rozdziel:

```text
Gameplay State
      ↓
Animation State
      ↓
Animation Player
```

Nie pozwól, aby animacja była jedynym źródłem prawdy o stanie gameplay.

---

# 26. CAMERA

Camera2D powinna mieć jasno określone:

- follow target
- smoothing
- limits
- zoom
- shake
- transitions

Camera shake nie powinien być rozsiany po wszystkich skryptach.

Utwórz jedno API:

```text
CameraService
```

jeżeli skala projektu tego wymaga.

---

# 27. UI ARCHITECTURE

Oddziel:

```text
Gameplay State
↓
UI Presentation
```

UI może obserwować stan poprzez:

- signals,
- binding,
- kontrolowane API.

Nie pozwalaj UI zarządzać gameplayem.

Przykład:

```text
InventoryService
       ↓
InventoryChanged
       ↓
InventoryUI
```

---

# 28. AUDIO ARCHITECTURE

Centralny system audio powinien zarządzać:

```text
Music
SFX
Ambience
UI
Voice
```

Oddziel volume:

```text
Master
Music
SFX
UI
Voice
Ambience
```

Audio events mogą być wywoływane przez gameplay, ale gameplay nie powinien znać szczegółów AudioStreamPlayer.

---

# 29. SAVE SYSTEM

Najpierw zdefiniuj kontrakt danych.

```text
SaveGame
├── version
├── player
├── inventory
├── world
├── quests
├── progression
└── settings
```

## Save versioning

Każdy save powinien mieć wersję:

```text
save_version: 1
```

Jeśli struktura save się zmieni:

```text
v1 → migration → v2
```

Nie zakładaj, że gracz zawsze będzie miał najnowszy save.

---

# 30. SAVE DATA VS RUNTIME STATE

Nie zapisuj:

```text
Node
SceneTree
Texture
AnimationPlayer
```

Zapisuj:

```text
position
health
inventory
quest states
world flags
progress
```

Runtime state i persistent state muszą być rozdzielone.

---

# 31. AUToloadS

Autoload stosuj tylko dla rzeczy, które rzeczywiście mają charakter globalnej usługi/stanu.

Potencjalne kandydatury:

```text
GameState
SaveService
AudioService
SettingsService
```

Nie twórz:

```text
GlobalPlayer
GlobalEnemy
GlobalInventory
GlobalUI
GlobalEverything
```

bez uzasadnienia.

---

# 32. SIGNALS

Signals są preferowanym mechanizmem lokalnego/eventowego powiadamiania.

Przykład:

```text
Health
 ↓
health_changed
 ↓
HealthBar
```

Nie twórz jednego gigantycznego:

```text
GlobalEventBus
```

dla każdej interakcji.

---

# 33. DEPENDENCY MANAGEMENT

Każdy system powinien jasno wiedzieć, czego potrzebuje.

Unikaj:

```gdscript
get_tree().root.get_node(...)
```

jako sposobu na znajdowanie wszystkiego.

Preferuj:
- references
- exported NodePath / node references
- signals
- dependency injection, jeśli projekt rzeczywiście tego wymaga
- dobrze zdefiniowane services

---

# 34. ERROR HANDLING

AI ma traktować błędy jako część projektu.

Nie ukrywaj problemów przez:

```gdscript
if node == null:
    return
```

jeśli brak node oznacza błąd architektury.

Rozróżniaj:

```text
Expected optional absence
```

od:

```text
Unexpected invalid state
```

---

# 35. LOGGING

Wprowadź sensowną strategię logowania.

Logi powinny umożliwiać rozróżnienie:

```text
INFO
DEBUG
WARNING
ERROR
```

Nie zostawiaj setek przypadkowych `print()` po ukończeniu migracji.

---

# 36. TESTABILITY

Logika, która może istnieć bez SceneTree, powinna być możliwie niezależna od SceneTree.

Przykłady:

```text
Damage calculation
Inventory rules
Stat calculations
Save serialization
Quest conditions
Loot generation
```

To pozwala testować system bez uruchamiania całej gry.

---

# 37. TEST PYRAMID

Preferuj:

```text
        E2E / Playtest
             ▲
        Integration
             ▲
       Unit / Logic
```

Nie rozwiązuj każdego problemu testem end-to-end.

---

# 38. PERFORMANCE RULES

Nie stosuj optymalizacji „na ślepo”.

Najpierw:

```text
Measure
↓
Profile
↓
Identify bottleneck
↓
Optimize
↓
Measure again
```

Zwróć szczególną uwagę na:
- `_process`
- `_physics_process`
- pathfinding
- AI tick frequency
- collision checks
- allocations
- instancing
- particles
- draw calls
- texture memory
- audio
- scene complexity

---

# 39. OBJECT LIFECYCLE

Każdy system powinien mieć jasne zasady:

```text
create
initialize
activate
update
deactivate
destroy
```

Nie polegaj na przypadkowej kolejności `_ready()` między wieloma niezależnymi systemami.

---

# 40. RESOURCE LIFECYCLE

Resources są danymi, a nie automatycznie runtime controllerami.

Nie wkładaj do Resource logiki zależnej od aktualnego SceneTree, jeśli nie ma ku temu mocnego powodu.

---

# 41. PERFORMANCE — 2D TOP-DOWN

Szczególnie sprawdź:

### Rendering
- sprite batching
- texture atlases
- overdraw
- particles
- lights
- shaders

### Gameplay
- enemy updates
- AI frequency
- collision queries
- pathfinding
- proximity checks

### World
- liczba aktywnych Node
- liczba animowanych obiektów
- liczba fizycznych obiektów

### UI
- częstotliwość aktualizacji
- dynamiczne layouty
- niepotrzebne rebuildy

---

# 42. POOLING

Object pooling stosuj dopiero, gdy profiling wykaże realny problem.

Typowe kandydatury:

```text
Projectiles
DamageNumbers
Particles
TemporaryVFX
```

Nie twórz poolingu dla każdego Node.

---

# 43. MIGRATION ORDER

Rekomendowana kolejność:

```text
1. Baseline
2. Full audit
3. Architecture mapping
4. Godot project bootstrap
5. Asset import
6. Input
7. Core game state
8. World foundation
9. Player
10. Camera
11. Collision
12. Combat foundation
13. One enemy
14. AI
15. Items
16. Inventory
17. Interactions
18. NPC / quests
19. UI
20. Audio
21. Save/load
22. Remaining gameplay
23. VFX
24. Shaders
25. Optimization
26. Tests
27. Full playtest
28. Release build
29. Final migration audit
```

---

# 44. VERTICAL SLICE

Nie migruj całej gry, zanim nie udowodnisz architektury.

Zbuduj:

```text
Boot
 ↓
Level
 ↓
Player
 ↓
Movement
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

Jeżeli ten fragment jest stabilny, architektura jest gotowa do skalowania.

---

# 45. GOLDEN MASTER

Dla ważnych zachowań Phaser przygotuj testowy scenariusz referencyjny.

Przykład:

```text
Scenario: Player attacks enemy

Initial:
Player HP = 100
Enemy HP = 50
Weapon damage = 20

Action:
Attack once

Expected:
Enemy HP = 30
Attack animation plays
Hit VFX appears
SFX plays
No duplicate damage
Cooldown starts
```

Godot musi przejść ten sam scenariusz.

---

# 46. BEHAVIOR PARITY

Dla każdego ważnego systemu sprawdź:

```text
Input parity
Movement parity
Collision parity
Timing parity
Damage parity
Animation parity
AI parity
UI parity
Save parity
Audio parity
```

Jeżeli zachowanie celowo się zmienia, zapisz:

```text
INTENTIONAL_DIVERGENCE.md
```

---

# 47. AI CODING WORKFLOW

Claude Code ma pracować:

```text
DISCOVER
↓
UNDERSTAND
↓
PLAN
↓
IMPLEMENT
↓
TEST
↓
RUN
↓
DEBUG
↓
REVIEW
↓
COMMIT
```

Nigdy:

```text
PROMPT
↓
100 FILES CHANGED
```

---

# 48. PRZED KAŻDĄ ZMIANĄ

Claude Code musi odpowiedzieć sobie:

1. Jaki problem rozwiązuję?
2. Który system jest właścicielem tej odpowiedzialności?
3. Czy istnieje już odpowiedni system?
4. Czy można wykorzystać istniejący kod?
5. Jakie są zależności?
6. Jakie mogą być skutki uboczne?
7. Jak to przetestuję?

---

# 49. PO KAŻDEJ ZMIANIE

Sprawdź:

```text
Compilation
↓
Runtime
↓
Tests
↓
Behavior
↓
Performance
↓
Architecture
```

---

# 50. GIT WORKFLOW

Każdy większy system:

```text
migration/player
migration/combat
migration/inventory
migration/ui
```

Commituj małe, logiczne zmiany.

Przykłady:

```text
migration: initialize Godot project
migration: import character assets
migration: implement input actions
migration: implement player movement
migration: implement player collision
migration: implement player combat
migration: implement enemy base
migration: implement enemy chase behavior
migration: implement inventory data
migration: implement inventory UI
```

---

# 51. AI CODE REVIEW

Po każdym większym module Claude Code wykonuje review pod kątem:

### Correctness
Czy działa?

### Architecture
Czy znajduje się w odpowiednim miejscu?

### Coupling
Czy nie powstały niepotrzebne zależności?

### Duplication
Czy istnieje podobny kod?

### Performance
Czy występują problemy w hot path?

### Testability
Czy można to przetestować?

### Maintainability
Czy kolejny developer zrozumie ten kod?

---

# 52. MIGRATION CHECKPOINTS

Projekt powinien mieć checkpointy:

```text
CHECKPOINT 0
Phaser baseline

CHECKPOINT 1
Godot boots

CHECKPOINT 2
Player works

CHECKPOINT 3
Vertical slice works

CHECKPOINT 4
Core gameplay migrated

CHECKPOINT 5
All gameplay migrated

CHECKPOINT 6
Persistence migrated

CHECKPOINT 7
Optimization complete

CHECKPOINT 8
Release candidate
```

Każdy checkpoint musi być grywalny.

---

# 53. RELEASE VALIDATION

Przed uznaniem migracji za zakończoną:

## Gameplay
- movement
- collision
- combat
- AI
- inventory
- items
- interactions
- quests
- progression

## Presentation
- animations
- VFX
- shaders
- audio
- UI
- camera

## Infrastructure
- save
- load
- settings
- input
- localization, jeśli istnieje

## Quality
- no critical errors
- no obvious leaks
- no broken references
- no missing assets
- no duplicate systems
- no migration TODOs affecting gameplay

---

# 54. DEFINITION OF DONE

System = COMPLETE dopiero gdy:

- [ ] implementation complete
- [ ] compiles
- [ ] runtime verified
- [ ] behavior verified
- [ ] tests added where appropriate
- [ ] edge cases checked
- [ ] no known critical errors
- [ ] architecture reviewed
- [ ] performance acceptable
- [ ] migration matrix updated
- [ ] commit created

Projekt = MIGRATED dopiero gdy wszystkie krytyczne systemy spełniają powyższe wymagania.

---

# 55. CLAUDE CODE — FIRST COMMAND

Pierwsza instrukcja po uruchomieniu Claude Code:

> Nie implementuj jeszcze migracji.
>
> Przeprowadź kompletny audyt istniejącego projektu Phaser.
>
> Przeszukaj cały repository i zidentyfikuj architekturę, gameplay, dane, assety, sceny, eventy, input, fizykę, AI, combat, inventory, UI, audio, save/load, mapy, zależności i potencjalne problemy.
>
> Utwórz:
>
> `docs/migration/PHASER_AUDIT.md`
>
> `docs/migration/ARCHITECTURE_MAP.md`
>
> `docs/migration/DEPENDENCY_GRAPH.md`
>
> `docs/migration/ASSET_INVENTORY.md`
>
> `docs/migration/GAMEPLAY_BEHAVIOR.md`
>
> `docs/migration/DATA_MODEL.md`
>
> `docs/migration/MIGRATION_RISKS.md`
>
> `docs/migration/MIGRATION_MATRIX.md`
>
> Nie modyfikuj istniejącego kodu Phaser.
>
> Nie twórz jeszcze implementacji Godot.
>
> Nie usuwaj żadnych plików.
>
> Nie wykonuj masowej refaktoryzacji.
>
> Na końcu przedstaw:
>
> 1. architekturę istniejącej gry,
> 2. listę wszystkich systemów,
> 3. zależności,
> 4. problemy techniczne,
> 5. ryzyka migracji,
> 6. proponowaną architekturę Godot,
> 7. kolejność migracji,
> 8. proponowany vertical slice,
> 9. systemy, które należy zaprojektować od nowa,
> 10. systemy, które można migrować bez większych zmian.
>
> Następnie ZATRZYMAJ SIĘ i czekaj na dalsze polecenie.

---

# 56. CLAUDE CODE — IMPLEMENTATION COMMAND

Po zakończeniu audytu:

> Rozpocznij migrację wyłącznie pierwszego zatwierdzonego subsystemu.
>
> Przed zmianami:
> - przeczytaj odpowiednie dokumenty migracji,
> - przeanalizuj istniejący kod Phaser,
> - określ odpowiedzialność systemu,
> - zaprojektuj idiomatyczne rozwiązanie Godot,
> - nie kopiuj architektury Phaser 1:1.
>
> Następnie:
> 1. implementuj,
> 2. uruchom walidację,
> 3. napraw błędy,
> 4. dodaj testy, jeśli mają sens,
> 5. sprawdź zachowanie,
> 6. wykonaj architecture review,
> 7. zaktualizuj MIGRATION_MATRIX.md.
>
> Nie przechodź do następnego dużego subsystemu bez potwierdzenia, że aktualny jest stabilny.

---

# 57. CLAUDE CODE — ANTI-REGRESSION COMMAND

Przed zakończeniem każdej sesji:

> Wykonaj anti-regression review.
>
> Sprawdź:
> - czy zmieniło się zachowanie istniejących systemów,
> - czy powstały duplikaty,
> - czy powstały niepotrzebne zależności,
> - czy pojawiły się null reference risks,
> - czy zmiany wpływają na performance,
> - czy asset references są poprawne,
> - czy save compatibility została zachowana,
> - czy testy nadal przechodzą.
>
> Nie kończ zadania, jeśli istnieje znany krytyczny problem.

---

# 58. FINAL TARGET

Końcowa gra Godot ma być:

```text
Stable
+
Maintainable
+
Data-driven
+
Testable
+
Performant
+
Modular
+
AI-friendly
+
Human-friendly
```

Najważniejsze:

**Nie przenosimy kodu Phaser do Godot.**

**Przenosimy grę do Godot.**

To oznacza zachowanie:
- gameplayu,
- danych,
- assetów,
- doświadczenia gracza,

przy jednoczesnym wykorzystaniu:
- SceneTree,
- Nodes,
- Resources,
- Signals,
- InputMap,
- Godot Physics,
- Animation system,
- Navigation,
- Godot UI,
- natywnego pipeline'u Godot.

---

# 59. FINAL PRINCIPLE

Jeżeli podczas migracji pojawi się wybór:

```text
A: szybkie przepisanie kodu Phaser
B: poprawne zaprojektowanie systemu Godot
```

wybierz:

```text
B
```

Jeżeli pojawi się wybór:

```text
A: bardziej skomplikowana architektura
B: prostsza architektura spełniająca wymagania
```

wybierz:

```text
B
```

Jeżeli pojawi się wybór:

```text
A: optymalizacja bez pomiaru
B: najpierw profiling
```

wybierz:

```text
B
```

Jeżeli pojawi się wybór:

```text
A: jedna ogromna klasa
B: małe, jasno odpowiedzialne komponenty
```

wybierz:

```text
B
```

Jeżeli pojawi się wybór:

```text
A: usunięcie starego Phaser
B: zachowanie bezpiecznego fallbacku
```

wybierz:

```text
B
```

dopóki migracja nie przejdzie pełnej walidacji.

---

# KONIEC

Ten dokument jest nadrzędnym planem technicznym migracji.

Jeżeli późniejsze decyzje projektowe wymagają odstępstwa od tego dokumentu, Claude Code musi:
1. wykryć konflikt,
2. wyjaśnić konsekwencje,
3. zaproponować rozwiązanie,
4. udokumentować zmianę,
5. dopiero potem ją wdrożyć.
