class_name GoalArea
extends Area2D
## Ported from LevelScene.ts goal overlap handling (see
## docs/migration/GAMEPLAY_BEHAVIOR.md, section "Interakcje" -> "Goal").
## Triggers on overlap only in this slice — the "or press E" alternative
## needs the general nearest-interactable system (NPC + goal, 100px radius),
## not built yet since no ported level has NPCs (see MIGRATION_MATRIX.md).
##
## `requires` is a Dictionary[StringName, int] (item id -> count), same
## shape as LevelObjectData.requires. Checking it against the player's
## inventory is the caller's job (LevelRuntime.gd) — this node only reports
## "something entered", it doesn't know about inventory.
##
## Emits via the EventBus autoload instead of a local `reached` signal — see
## EventBus.gd, "Część 9".

@export var obj_id: String
@export var requires: Dictionary = {}
@export var message: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## Safe to call right after instantiate(), before this node enters the
## tree — LevelBuilder does exactly that, so this looks up the child node
## directly instead of via @onready (which only resolves at _ready()).
func set_shape_size(size: Vector2) -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape: CollisionShape2D = $CollisionShape2D
	shape.shape = rect

	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var visual: Polygon2D = $DebugVisual
	visual.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])

	var label: Label = $IconLabel
	label.size = size
	label.position = -size / 2.0
	label.add_theme_font_size_override("font_size", roundi(size.y * 0.9))

## `icon` — see ItemPickup.set_icon() comment; goal objects carry their own
## `LevelObjectData.icon` (🏰/🚪/🍂/🐈), not derived from an item.
func set_icon(icon: String) -> void:
	var label: Label = $IconLabel
	label.text = icon

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	EventBus.goal_reached.emit(obj_id)
