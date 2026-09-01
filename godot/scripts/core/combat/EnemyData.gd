class_name EnemyData
extends Resource
## Enemy archetype definition — rpg.md section 3.2, same Resource-as-data
## pattern as ItemData/LevelObjectData. One .tres per enemy type lives in
## godot/data/enemies/, @export'ed onto EnemyActor.tscn instances the same
## way ItemPickup reads ItemData.

@export var id: StringName
@export var display_name: String
@export var stats: StatsData
@export var sprite_frames: SpriteFrames
## Different source packs use different native frame sizes (Demon_A: 100px,
## Tiny Swords Warrior: 192px) — scaled per-archetype here instead of a
## single fixed scale in EnemyActor.tscn, which only one enemy could ever be
## correctly sized for.
@export var sprite_scale: Vector2 = Vector2(0.32, 0.32)

## Distance (px) at which an IDLE enemy notices the player and starts CHASE.
@export var detect_radius: float = 160.0
## Distance (px) at which a CHASE enemy is close enough to switch to ATTACK.
@export var attack_range: float = 28.0
