class_name CombatPickup
extends Area2D
## One-time combat find — rpg.md backlog "jednorazowe znajdźki combat"
## ("Bronie/przedmioty jednorazowe ze świata — tymczasowy bonus do ataku,
## lekki system bez pełnego ekwipunku"). Deliberately NOT wired into
## ItemData/Inventory/ProgressStore — it grants a transient combat buff via
## StatusEffectComponent, not a persisted collectible, so none of the
## save/load or inventory-chip machinery applies. Same overlap-triggered,
## one-shot shape as ItemPickup.gd.

@export var boost_duration_seconds: float = 20.0
@export var toast_text: String = "Znaleziono naostrzoną broń! Atak wzmocniony."


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var status := body.get_node_or_null("StatusEffects") as StatusEffectComponent
	if status == null:
		return
	status.apply_effect(StatusEffectComponent.EffectType.ATTACK_BOOST, boost_duration_seconds)
	AudioService.play_pickup()
	EventBus.toast_requested.emit(toast_text)
	queue_free()
