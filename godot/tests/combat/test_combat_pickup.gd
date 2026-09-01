extends GutTest
## rpg.md backlog "jednorazowe znajdźki combat" (CombatPickup.gd) — mirrors
## the overlap-triggered, one-shot shape already tested informally via
## ItemPickup's usage in LevelBuilder; here exercised directly since
## CombatPickup is a standalone scene, not routed through LevelData/LevelBuilder.

const CombatPickupScene := preload("res://scenes/interactables/CombatPickup.tscn")
const PlayerScene := preload("res://scenes/player/Player.tscn")

var _pickup: CombatPickup
var _player: CharacterBody2D


func before_each() -> void:
	_pickup = CombatPickupScene.instantiate()
	add_child_autofree(_pickup)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.add_to_group("player")


func test_player_overlap_applies_attack_boost_and_frees_the_pickup() -> void:
	var status: StatusEffectComponent = _player.get_node("StatusEffects")
	_pickup._on_body_entered(_player)
	assert_eq(status.attack_damage_multiplier, StatusEffectComponent.ATTACK_BOOST_MULTIPLIER)
	assert_true(
		_pickup.is_queued_for_deletion(),
		"one-shot pickup frees itself after granting the boost",
	)


func test_non_player_overlap_does_nothing() -> void:
	var other := Node2D.new()
	add_child_autofree(other)
	_pickup._on_body_entered(other)
	assert_false(_pickup.is_queued_for_deletion(), "a non-player body must not consume the pickup")


func test_toast_requested_announces_the_find() -> void:
	watch_signals(EventBus)
	_pickup._on_body_entered(_player)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", [_pickup.toast_text])
