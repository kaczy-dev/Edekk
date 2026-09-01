class_name LevelObjectData
extends Resource
## Ported from src/game/types.ts (LevelObject).
##
## `kind` is one of "obstacle" | "item" | "npc" | "goal" | "trigger" |
## "enemy" — kept as a plain String (not an enum) to match the TS source and
## stay easy to diff against it; LevelBuilder.gd switches on it. "enemy" has
## no TS equivalent (combat didn't exist in the Phaser source) — added by
## rpg.md's combat plan, same shape as the others.

@export var id: String
@export var kind: String
@export var rect: Rect2
@export var item_id: StringName = &""
@export var npc_id: String = ""
@export var message: String = ""
## Glyph drawn in-world. Items fall back to their ItemData emoji when empty.
@export var icon: String = ""
## How many of which items must be collected to complete this goal.
## Keys are item ids (StringName), values are counts (int).
@export var requires: Dictionary = {}
@export var danger: bool = false
## Optional horizontal patrol for "npc" objects. 0 means "static, no patrol".
@export var patrol_range: float = 0.0
@export var patrol_speed: float = 0.0
## Which data/enemies/*.tres to spawn for "enemy"-kind objects — resolved
## through EnemyRegistry the same way item_id is resolved through
## ItemRegistry.
@export var enemy_id: StringName = &""
