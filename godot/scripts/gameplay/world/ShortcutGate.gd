class_name ShortcutGate
extends Area2D
## rpg.md backlog ("Kryjówki/skróty odblokowywane po pokonaniu wroga lub
## zapłacie") — a one-time, permanently-unlockable physical blocker.
## `interact(player)` is the same duck-typed method InteractionDetector.gd
## already calls on VendingMachine/NpcActor/TransitStation, nothing new
## needed there.
##
## Two independent unlock paths (OR, not AND), matching the backlog wording
## exactly: paying `unlock_cost`, or `required_enemy_id` having already
## died (EventBus.enemy_died) somewhere in this scene. `required_enemy_id`
## empty means "pay only" — no enemy condition exists to satisfy.
##
## Physical blocking is a separate `StaticBody2D` child (`Blocker`, World
## layer, see COLLISION_MATRIX.md) rather than this Area2D itself — this
## node only ever does interact()-overlap detection (NPCs layer, like
## VendingMachine), it was never meant to physically stop `move_and_slide()`.
## Unlocking disables the Blocker's CollisionShape2D so the player can
## simply walk through afterwards; the gate itself stays in the tree
## (identity/obj_id preserved, no queue_free()) as a fixture in the level.

@export var gate_id: String = ""
@export var unlock_cost: int = 20
@export var required_enemy_id: String = ""

@onready var _icon_label: Label = $IconLabel
@onready var _debug_visual: Polygon2D = $DebugVisual
@onready var _blocker_shape: CollisionShape2D = $Blocker/CollisionShape2D

var _enemy_defeated: bool = false


func _ready() -> void:
	if gate_id.is_empty():
		push_warning(
			"ShortcutGate at %s has no gate_id set — unlock state would collide with any other empty-id gate."
			% get_path()
		)
	if ProgressStore.is_shortcut_unlocked(gate_id):
		_apply_unlocked_visual()
		_blocker_shape.set_deferred("disabled", true)
		monitoring = false
		monitorable = false
		return
	_icon_label.text = "🔒"
	if not required_enemy_id.is_empty():
		EventBus.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(obj_id: String) -> void:
	if obj_id == required_enemy_id:
		_enemy_defeated = true


func interact(_player: Node) -> void:
	if ProgressStore.is_shortcut_unlocked(gate_id):
		return
	if _enemy_defeated:
		_unlock()
		EventBus.toast_requested.emit("Skrót odblokowany — wróg pokonany")
		return
	if ProgressStore.spend_money(unlock_cost):
		_unlock()
		EventBus.toast_requested.emit("Skrót odblokowany (-%d zł)" % unlock_cost)
	else:
		EventBus.toast_requested.emit("Za mało pieniędzy — potrzebujesz %d zł" % unlock_cost)


func _unlock() -> void:
	ProgressStore.unlock_shortcut(gate_id)
	_blocker_shape.set_deferred("disabled", true)
	monitoring = false
	monitorable = false
	_apply_unlocked_visual()


func _apply_unlocked_visual() -> void:
	_icon_label.text = "🔓"
	_debug_visual.color = Color(0.3, 0.55, 0.3, 0.4)
