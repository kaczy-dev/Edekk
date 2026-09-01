class_name NpcActor
extends Area2D
## Ported from LevelScene.ts NPC handling (see
## docs/migration/GAMEPLAY_BEHAVIOR.md, sections "Interakcje" -> "NPC" and
## "Patrol NPC"). Overlap-triggered talk is still the primary, tested path.
## `interact()` (see InteractionDetector.gd, "Część 4") adds the "press E"
## alternative the old comment here used to flag as missing — this is the
## interactable where it actually matters, since overlap alone means talking
## again requires walking away and back. Not one-shot like ItemPickup: the
## NPC stays in the scene and can be talked to again (talked state /
## gift-once guard live in LevelRuntime, matching the TS source keeping
## talkedNpcs/inventory in gameStore rather than on the NPC itself).
##
## Emits via the EventBus autoload instead of a local `talked` signal — see
## EventBus.gd, "Część 9".

@export var obj_id: String
@export var npc_id: String

## 0 means static (no patrol) — matches LevelObject.patrol being optional.
@export var patrol_range: float = 0.0
@export var patrol_speed: float = 0.0

var _base_x: float
var _dir: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_x = position.x


func _physics_process(delta: float) -> void:
	if patrol_range <= 0.0:
		return
	var half := patrol_range / 2.0
	var next_x := position.x + _dir * patrol_speed * delta
	if next_x >= _base_x + half:
		next_x = _base_x + half
		_dir = -1
	elif next_x <= _base_x - half:
		next_x = _base_x - half
		_dir = 1
	position.x = next_x
	scale.x = absf(scale.x) * _dir


## Safe to call right after instantiate(), before this node enters the tree —
## same @onready-timing reasoning as ItemPickup.set_shape_size().
func set_shape_size(size: Vector2) -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape: CollisionShape2D = $CollisionShape2D
	shape.shape = rect

	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var visual: Polygon2D = $DebugVisual
	visual.polygon = PackedVector2Array(
		[Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
	)

	var label: Label = $IconLabel
	label.size = size
	label.position = -size / 2.0
	label.add_theme_font_size_override("font_size", roundi(size.y * 0.9))


## `icon` — see ItemPickup.set_icon() comment. Flips with the node's own
## `scale.x` during patrol (_physics_process() above), matching Phaser's
## `text.setScale(dir, 1)` mirroring the glyph at each turn.
func set_icon(icon: String) -> void:
	var label: Label = $IconLabel
	label.text = icon


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	EventBus.npc_talked.emit(obj_id, npc_id)


## Called by InteractionDetector.gd when this is the nearest interactable and
## the player presses "interact".
func interact(_player: Node) -> void:
	EventBus.npc_talked.emit(obj_id, npc_id)


## rpg.md backlog ("Ulubione miejsca") — duck-typed by InteractionDetector.gd
## the same way `interact()` is: presence of this method (not a shared base
## class) marks a node as favoritable. `npc_id` is the only human-readable
## name NpcActor carries — no separate display-name export exists to prefer.
func get_favorite_label() -> String:
	return npc_id
