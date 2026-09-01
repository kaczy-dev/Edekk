class_name StatsData
extends Resource
## Combat stats block per rpg.md section 3.2 — same Resource-as-data pattern
## as ItemData/LevelObjectData. One .tres per enemy archetype lives in
## godot/data/enemies/, referenced from EnemyData.gd (feature/rpg-enemy).
## Also usable directly on the player for a future player-stats .tres —
## kept generic (no enemy-only or player-only fields) rather than forked
## into two near-identical Resources.

@export var max_hp: int = 10
@export var attack: int = 1
@export var defense: int = 0
@export var move_speed: float = 60.0
@export var attack_cooldown: float = 1.0
