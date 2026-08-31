class_name ItemPickup
extends Area2D
## Ported from LevelScene.ts item overlap handling (see
## docs/migration/GAMEPLAY_BEHAVIOR.md, section "Interakcje" -> "Item").
## Collection is overlap-triggered, one-shot — that's the tested, working
## primary path, unchanged. `interact()` (see InteractionDetector.gd, "Część
## 4") is an additive alternative for the same outcome, not a replacement:
## in practice a player is already standing on the item (and it's already
## collected via overlap) by the time "press E" would matter, but it exists
## for consistency with NPCs, whose interact() is the more useful case.
##
## Emits via the EventBus autoload instead of a local `collected` signal
## LevelBuilder/LevelRuntime used to connect directly — see EventBus.gd,
## "Część 9".
##
## NOT yet ported: camera punch (zoom 1.03x, 160ms) on pickup — needs the
## Camera system (MIGRATION_MATRIX.md), and the pickup sound.

@export var obj_id: String
@export var item_id: StringName

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

## `icon` is a glyph (emoji or LevelObjectData.icon override) — ported from
## LevelScene.ts's `add.text(...)` item rendering, which uses the same
## emoji-as-sprite approach rather than custom art (see items.ts: every
## ItemDef carries an `emoji`, no image asset).
func set_icon(icon: String) -> void:
	var label: Label = $IconLabel
	label.text = icon

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_collect()

## Called by InteractionDetector.gd when this is the nearest interactable and
## the player presses "interact". `_player` unused (ItemPickup doesn't care
## who collected it, matching _on_body_entered's own group-check-only logic)
## but kept in the signature so every interactable's interact() has the same
## shape InteractionDetector calls generically.
func interact(_player: Node) -> void:
	_collect()

func _collect() -> void:
	EventBus.item_collected.emit(obj_id, item_id)
	queue_free()
