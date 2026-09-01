class_name DeliveryPickup
extends Area2D
## rpg.md backlog ("Tryb 'dostawa' — proste zadania kurierskie między
## punktami miasta. Pasuje pod istniejący system questów (QuestStepData) +
## ekonomię (ProgressStore.money)") — deliberately NOT built on
## QuestStepData/LevelObjectData/LevelBuilder's "goal" kind: those are
## per-level authored content (a .tres a level's designer writes), while a
## courier job's whole point is two points that don't have to be on the
## same level. Standalone placeable Area2D instead, duck-typed
## `interact(player)` like VendingMachine/ShortcutGate — paired with a
## DeliveryDropoff.gd sharing the same `job_id` (author-assigned, same
## convention as ShortcutGate.gate_id), wherever in the game the level
## designer places it.

@export var job_id: String = ""
@export var item_label: String = "📦 Przesyłka"


func _ready() -> void:
	var label: Label = $IconLabel
	label.text = "📦"


func interact(_player: Node) -> void:
	if ProgressStore.is_carrying_parcel(job_id):
		EventBus.toast_requested.emit("Już niesiesz tę przesyłkę.")
		return
	ProgressStore.pickup_parcel(job_id)
	EventBus.toast_requested.emit("Odebrano: %s" % item_label)


## rpg.md backlog ("Ulubione miejsca") — same duck-type as VendingMachine.
func get_favorite_label() -> String:
	return item_label
