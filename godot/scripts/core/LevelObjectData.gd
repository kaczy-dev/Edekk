class_name LevelObjectData
extends Resource
## Ported from src/game/types.ts (LevelObject).
##
## `kind` is one of "obstacle" | "item" | "npc" | "goal" | "trigger" — kept as
## a plain String (not an enum) to match the TS source and stay easy to
## diff against it; LevelBuilder.gd switches on it.

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
