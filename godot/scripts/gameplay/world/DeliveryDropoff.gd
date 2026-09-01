class_name DeliveryDropoff
extends Area2D
## rpg.md backlog ("Tryb 'dostawa'") — pairs with DeliveryPickup.gd via the
## same `job_id`. See DeliveryPickup.gd's header for why this isn't built on
## the QuestStepData/GoalArea pipeline.

@export var job_id: String = ""
@export var reward_money: int = 30


func _ready() -> void:
	var label: Label = $IconLabel
	label.text = "🏠"


func interact(_player: Node) -> void:
	if not ProgressStore.deliver_parcel(job_id):
		EventBus.toast_requested.emit("Nie masz przy sobie tej przesyłki.")
		return
	ProgressStore.add_money(reward_money)
	EventBus.toast_requested.emit("Dostarczono! (+%d zł)" % reward_money)
