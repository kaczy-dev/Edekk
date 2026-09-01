extends GutTest
## rpg.md backlog ("Losowe potyczki uliczne (zależne od pory dnia/
## reputacji)") — StreetAmbushSpawner.gd. Redirects ProgressStore.save_path
## like other economy/reputation tests since add_reputation() autosaves.

const PlayerScene := preload("res://scenes/player/Player.tscn")
const TEST_SAVE_PATH := "user://test_progress_street_ambush.json"

var _real_save_path: String
var _real_day: int
var _real_hour: int
var _spawner: StreetAmbushSpawner
var _player: Node2D


func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH


func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func before_each() -> void:
	ProgressStore.reset_progress()
	_real_day = TimeManager.current_day
	_real_hour = TimeManager.current_hour

	_player = PlayerScene.instantiate()
	add_child_autofree(_player)

	_spawner = StreetAmbushSpawner.new()
	_spawner.zone_id = "test_zone"
	add_child_autofree(_spawner)


func after_each() -> void:
	TimeManager.current_hour = _real_hour
	TimeManager.current_day = _real_day


func _make_dangerous_at_night() -> void:
	TimeManager.current_hour = 23
	ProgressStore.add_reputation("test_zone", -20)


func test_does_not_ambush_during_the_day_even_with_bad_reputation() -> void:
	TimeManager.current_hour = 12
	ProgressStore.add_reputation("test_zone", -20)
	assert_false(_spawner._can_ambush())


func test_does_not_ambush_at_night_with_good_reputation() -> void:
	TimeManager.current_hour = 23
	assert_false(_spawner._can_ambush())


func test_ambushes_at_night_with_bad_reputation() -> void:
	_make_dangerous_at_night()
	assert_true(_spawner._can_ambush())


func test_spawn_ambush_adds_one_enemy_near_the_player() -> void:
	_make_dangerous_at_night()
	_spawner._spawn_ambush()
	assert_not_null(_spawner._active_enemy)
	# Checked before any physics frame runs — the enemy's own StateMachine
	# starts chasing the player immediately, so the exact SPAWN_DISTANCE only
	# holds at the instant of placement, not a frame later.
	var distance := _spawner._active_enemy.global_position.distance_to(_player.global_position)
	assert_almost_eq(distance, StreetAmbushSpawner.SPAWN_DISTANCE, 1.0)
	_spawner._active_enemy.queue_free()


func test_cannot_ambush_again_while_the_previous_enemy_is_still_alive() -> void:
	_make_dangerous_at_night()
	_spawner._spawn_ambush()
	await wait_physics_frames(1)
	assert_false(_spawner._can_ambush(), "an active ambush enemy blocks a second one")
	_spawner._active_enemy.queue_free()


func test_spawn_ambush_emits_a_warning_toast() -> void:
	_make_dangerous_at_night()
	watch_signals(EventBus)
	_spawner._spawn_ambush()
	await wait_physics_frames(1)
	assert_signal_emitted(EventBus, "toast_requested")
	_spawner._active_enemy.queue_free()
