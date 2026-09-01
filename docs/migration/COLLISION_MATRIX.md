# COLLISION_MATRIX.md

Referenced as "not designed yet" in `MIGRATION_MATRIX.md` (Kolizje / przeszkody row)
until this pass. Defines the 5 physics layers used by `godot/project.godot`
(`[layer_names]`) and which `collision_layer`/`collision_mask` each node type gets.
Before this, every body/area defaulted to layer 1 / mask 1 — no real filtering,
just accidental non-collision because `Area2D` overlap logic guarded on
`is_in_group("player")` in script rather than physics layers doing the job.

## Layers

| # | Name   | Used by                                              |
|---|--------|-------------------------------------------------------|
| 1 | World  | `StaticBody2D` obstacles (`LevelBuilder._build_obstacle`) |
| 2 | Player | `Player.tscn` (`CharacterBody2D`)                     |
| 3 | Items  | `ItemPickup.tscn`, `GoalArea.tscn` (both `Area2D`)    |
| 4 | NPCs   | `NpcActor.tscn` (`Area2D`)                            |
| 5 | Danger | Reserved for future `trigger`-kind hazard objects (not built yet — no ported level uses `trigger`, see `MIGRATION_MATRIX.md`) |
| 6 | Enemies | `EnemyActor.tscn` (`CharacterBody2D`, `feature/rpg-enemy`) |
| 7 | PlayerHitbox | `Hitbox` (`Area2D`) child of `Player.tscn` — `monitoring` stays on permanently; `PlayerHitbox.apply_hits()` is called explicitly at the attack's hit-window instead of toggling it (`feature/rpg-combat`, see `PlayerHitbox.gd`'s header for why) |
| 8 | EnemyHitbox | `Hitbox` (`Area2D`) child of `EnemyActor.tscn` — same "always monitoring, called explicitly" design as PlayerHitbox (`feature/rpg-combat`) |

Layers 6-8 reserved by `rpg.md`'s combat plan on `feature/rpg-stats`, consumed by
`feature/rpg-enemy` (layer 6) and `feature/rpg-combat` (layers 7-8, with real nodes now
in `Player.tscn`/`EnemyActor.tscn` — not reserved-only anymore, unlike Danger above).

Goal areas share the Items layer rather than getting their own — mechanically
identical to a pickup (an `Area2D` the player overlaps once), not a distinct
physics concern.

## collision_layer / collision_mask per node

| Node                        | layer | mask      | Why                                                                 |
|------------------------------|-------|-----------|----------------------------------------------------------------------|
| Obstacle (`StaticBody2D`)    | 1     | 0         | Static — never needs to detect anything itself, only be detected.  |
| `Player` (`CharacterBody2D`) | 2     | 1         | Physically collides with World only — Items/NPCs are `Area2D` overlap, not `move_and_slide()` collision. |
| `ItemPickup`, `GoalArea`     | 3     | 2         | Detects Player only — prevents an obstacle or another item ever firing `body_entered`. |
| `NpcActor`                   | 4     | 2         | Same reasoning as pickups — Player-only overlap.                    |
| `InteractionArea` (Player child, `InteractionDetector.gd`) | 0 (none) | 3\|4 (12) | Detects both Items and NPCs (`GoalArea` shares the Items layer but deliberately doesn't implement `interact()` — see InteractionDetector.gd header). `collision_layer = 0` because nothing needs to detect the detector itself, only the reverse. |
| `EnemyActor` (`CharacterBody2D`)     | 6 (32) | 1         | Physically collides with World only, same reasoning as Player — its own attack/hurt detection goes through its `Hitbox`/`HealthComponent`, not `move_and_slide()`. |
| `Player`'s `Hitbox` (`Area2D`, `PlayerHitbox.gd`) | 7 (64) | 6 (32)    | Detects Enemies only. |
| `EnemyActor`'s `Hitbox` (`Area2D`, `EnemyHitbox.gd`) | 8 (128) | 2 (2)   | Detects Player only. |

Implemented in `plan31-08.md`, "Część 4": `InteractionDetector.gd` on
`Player.tscn`'s `InteractionArea` (100px `CircleShape2D`, present since the
first player-movement slice but inert until this pass) tracks every `Area2D`
in range implementing `interact(player)` via `area_entered`/`area_exited`,
picks the nearest each frame, and emits `nearest_changed` for
`LevelRuntime._on_nearest_interactable_changed()` to relay to the HUD prompt.
`ItemPickup`/`NpcActor` both grew an `interact()` alongside their existing,
untouched overlap-triggered collection/talk — additive alternative, not a
replacement.

## Why this matters (the bug it prevents)

Before this pass, an `Area2D` pickup/goal/NPC with default layer/mask 1 would
receive `body_entered` for *any* physics body sharing layer 1 — including
`StaticBody2D` obstacles and, if two interactables ever occupied overlapping
`Rect2`s in `LevelData`, each other. The only thing preventing a false
"collected"/"talked" fire was each script's own `is_in_group("player")` guard
in `body_entered` — correct today, but relying on script discipline instead
of physics filtering is exactly the kind of thing that breaks silently when
a new object kind (e.g. `trigger`/Danger) gets added later without someone
remembering to keep guarding by hand. The layer matrix now makes the
filtering structural.
