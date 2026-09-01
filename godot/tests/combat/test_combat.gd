extends GutTest
## rpg.md, feature/rpg-combat — end-to-end hitbox/hurtbox wiring, using the
## real Player.tscn and EnemyActor.tscn (Demon_A) rather than isolated
## components, so this exercises the full chain: Input -> PlayerAttack ->
## PlayerHitbox -> HealthComponent.take_damage() -> EventBus, and the
## reverse for the enemy's attack.
##
## Drives real Input events via Input.parse_input_event() — same technique
## as tests/integration/test_gameplay.gd (Input.action_press() never reaches
## _unhandled_input()/is_action_just_pressed() checks the way a real event
## does).

const PlayerScene := preload("res://scenes/player/Player.tscn")
const EnemyActorScene := preload("res://scenes/enemies/EnemyActor.tscn")

var _player: CharacterBody2D
var _enemy: EnemyActor


func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2.ZERO

	_enemy = EnemyActorScene.instantiate()
	add_child_autofree(_enemy)


func _press_key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)


func _release_key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = false
	Input.parse_input_event(ev)


func test_player_attack_damages_enemy_in_hitbox_range() -> void:
	_enemy.global_position = Vector2(30, 0) # inside PlayerHitbox's 40px radius
	watch_signals(EventBus)

	_press_key(KEY_J)
	await wait_physics_frames(1)
	_release_key(KEY_J)
	await wait_seconds(0.2) # past PlayerAttack.HIT_WINDOW_AT (0.15s)

	var enemy_health: HealthComponent = _enemy.get_node("HealthComponent")
	assert_eq(enemy_health.current_hp, 9, "Demon_A (12 HP) takes 3 damage from the player's hitbox")
	assert_signal_emitted_with_parameters(EventBus, "enemy_damaged", [_enemy.name, 9, 12])


## rpg.md backlog "jednorazowe znajdźki combat" — CombatPickup applies
## ATTACK_BOOST via StatusEffectComponent, PlayerHitbox.apply_hits() reads it.
func test_player_attack_with_attack_boost_deals_doubled_damage() -> void:
	_enemy.global_position = Vector2(30, 0) # inside PlayerHitbox's 40px radius
	var status: StatusEffectComponent = _player.get_node("StatusEffects")
	status.apply_effect(StatusEffectComponent.EffectType.ATTACK_BOOST, 10.0)

	_press_key(KEY_J)
	await wait_physics_frames(1)
	_release_key(KEY_J)
	await wait_seconds(0.2)

	var enemy_health: HealthComponent = _enemy.get_node("HealthComponent")
	assert_eq(
		enemy_health.current_hp,
		6,
		"Demon_A (12 HP) takes 3*2=6 damage while ATTACK_BOOST is active",
	)


func test_player_attack_out_of_range_does_nothing() -> void:
	_enemy.global_position = Vector2(500, 0) # far outside the 40px hitbox
	_press_key(KEY_J)
	await wait_physics_frames(1)
	_release_key(KEY_J)
	await wait_seconds(0.2)

	var enemy_health: HealthComponent = _enemy.get_node("HealthComponent")
	assert_eq(
		enemy_health.current_hp,
		12,
		"an attack that never overlaps the enemy deals no damage",
	)


func test_enemy_attack_damages_player_in_range() -> void:
	_enemy.global_position = Vector2(20, 0) # inside Demon_A's attack_range (28)
	watch_signals(EventBus)

	# Windup is attack_cooldown (1.1) * 0.4 = 0.44s — wait past it.
	await wait_seconds(0.5)

	var player_health: HealthComponent = _player.get_node("HealthComponent")
	assert_eq(player_health.current_hp, 18, "player (20 HP) takes 2 damage from Demon_A's attack")
	assert_signal_emitted_with_parameters(EventBus, "player_damaged", [18, 20])


func test_enemy_enters_hurt_state_on_nonlethal_damage() -> void:
	var enemy_health: HealthComponent = _enemy.get_node("HealthComponent")
	var sm: EnemyStateMachine = _enemy.get_node("StateMachine")
	enemy_health.take_damage(1) # Demon_A has 12 HP — not lethal
	assert_eq(sm.current, EnemyStateMachine.StateName.HURT)


## rpg.md section 11b backlog ("Graffiti/ślady gracza") — EnemyActor emits
## combat_trace_requested at its own global_position on death.
func test_enemy_death_requests_a_combat_trace_at_its_position() -> void:
	_enemy.global_position = Vector2(40, 60)
	var enemy_health: HealthComponent = _enemy.get_node("HealthComponent")
	watch_signals(EventBus)
	enemy_health.take_damage(999)
	assert_signal_emitted_with_parameters(EventBus, "combat_trace_requested", [Vector2(40, 60)])


func test_enemy_dies_and_is_freed_after_death_animation() -> void:
	var enemy_health: HealthComponent = _enemy.get_node("HealthComponent")
	var sm: EnemyStateMachine = _enemy.get_node("StateMachine")
	enemy_health.take_damage(999)
	assert_eq(sm.current, EnemyStateMachine.StateName.DEAD, "lethal damage forces DEAD, not HURT")

	# Demon_A's death animation: 4 frames @ 8fps = 0.5s.
	await wait_seconds(0.6)
	await wait_physics_frames(2) # let queue_free() actually finalize
	assert_false(
		is_instance_valid(_enemy),
		"EnemyActor frees itself once the death animation finishes",
	)
