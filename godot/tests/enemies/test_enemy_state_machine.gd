extends GutTest
## rpg.md, feature/rpg-enemy — Idle/Chase/Attack classification by distance
## to the player, using the real EnemyActor.tscn (Demon_A data: detect_radius
## 160, attack_range 28) rather than a hand-rolled EnemyData, so this also
## exercises _ready()'s wiring (sprite_frames/max_hp/state_machine.setup()).

const EnemyActorScene := preload("res://scenes/enemies/EnemyActor.tscn")

var _enemy: EnemyActor
var _player: Node2D

func before_each() -> void:
	_enemy = EnemyActorScene.instantiate()
	add_child_autofree(_enemy)
	_enemy.global_position = Vector2.ZERO

	_player = Node2D.new()
	_player.add_to_group("player")
	add_child_autofree(_player)

func _place_player_at(distance: float) -> void:
	_player.global_position = Vector2(distance, 0)

func test_ready_wires_sprite_frames_and_max_hp_from_enemy_data() -> void:
	var sprite: AnimatedSprite2D = _enemy.get_node("Sprite2D")
	assert_not_null(sprite.sprite_frames, "EnemyActor._ready() assigns sprite_frames from enemy_data")
	assert_true(sprite.sprite_frames.has_animation(&"idle"))
	var health: HealthComponent = _enemy.get_node("HealthComponent")
	assert_eq(health.max_hp, 12, "HealthComponent.max_hp set from Demon_A's StatsData (12)")

func test_no_player_in_scene_stays_idle() -> void:
	_player.remove_from_group("player")
	await wait_physics_frames(2)
	var sm: EnemyStateMachine = _enemy.get_node("StateMachine")
	assert_eq(sm.current, EnemyStateMachine.StateName.IDLE, "no player found -> IDLE")

func test_player_far_away_is_idle() -> void:
	_place_player_at(500.0) # beyond detect_radius (160)
	await wait_physics_frames(2)
	var sm: EnemyStateMachine = _enemy.get_node("StateMachine")
	assert_eq(sm.current, EnemyStateMachine.StateName.IDLE)

func test_player_within_detect_radius_triggers_chase() -> void:
	_place_player_at(100.0) # within detect_radius (160), outside attack_range (28)
	await wait_physics_frames(2)
	var sm: EnemyStateMachine = _enemy.get_node("StateMachine")
	assert_eq(sm.current, EnemyStateMachine.StateName.CHASE)

func test_chase_moves_enemy_toward_player() -> void:
	_place_player_at(100.0)
	var start_pos: Vector2 = _enemy.global_position
	await wait_seconds(0.3)
	assert_gt(_enemy.global_position.x, start_pos.x, "enemy moves toward the player on the +X side during CHASE")

func test_player_within_attack_range_triggers_attack() -> void:
	_place_player_at(20.0) # within attack_range (28)
	await wait_physics_frames(2)
	var sm: EnemyStateMachine = _enemy.get_node("StateMachine")
	assert_eq(sm.current, EnemyStateMachine.StateName.ATTACK)

func test_attack_state_holds_position() -> void:
	_place_player_at(20.0)
	await wait_physics_frames(2)
	var pos_before: Vector2 = _enemy.global_position
	await wait_seconds(0.2)
	assert_eq(_enemy.global_position, pos_before, "ATTACK state does not move the enemy")
