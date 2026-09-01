extends GutTest
## rpg.md backlog ("Szybki zapis / mid-level resume") — the manual
## quick_save trigger LevelRuntime._unhandled_input()/_quick_save() adds on
## top of the already-existing periodic checkpoint Timer (see
## tests/economy/test_progress_store_checkpoint.gd for the ProgressStore
## side, and MainMenu._on_continue_pressed() for the resume-on-load side).
## Drives a real InputEventKey through Input.parse_input_event() into a
## real Level2.tscn instance, same technique as
## tests/integration/test_gameplay.gd and tests/combat/test_combat.gd
## (Input.action_press() never reaches is_action_just_pressed() checks the
## way a real event does).

const Level2Scene := preload("res://scenes/levels/Level2.tscn")
const TEST_SAVE_PATH := "user://test_progress_quick_save.json"

var _level: Node
var _player: CharacterBody2D
var _real_save_path: String

func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH

func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

func before_each() -> void:
	ProgressStore.reset_progress()
	_level = Level2Scene.instantiate()
	add_child_autofree(_level)
	await wait_physics_frames(2)
	_player = get_tree().get_first_node_in_group("player")

func _press_and_release_quick_save() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_F5
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_F5
	release.pressed = false
	Input.parse_input_event(release)

func test_quick_save_writes_checkpoint_immediately() -> void:
	assert_not_null(_player, "player should spawn in Level2")
	if _player == null:
		return
	assert_false(ProgressStore.has_checkpoint_for("2"), "no checkpoint before quick-saving")

	_player.global_position = Vector2(321, 654)
	_press_and_release_quick_save()
	await wait_process_frames(2)

	assert_true(ProgressStore.has_checkpoint_for("2"), "quick_save should checkpoint immediately, not wait for the 5s timer")
	assert_eq(ProgressStore.get_checkpoint_position(), Vector2(321, 654))

func test_quick_save_captures_current_hp() -> void:
	if _player == null:
		return
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	assert_not_null(health, "Player.tscn should have a HealthComponent")
	if health == null:
		return
	health.take_damage(3)

	_press_and_release_quick_save()
	await wait_process_frames(2)

	assert_eq(ProgressStore.resume_hp, health.current_hp)

func test_quick_save_emits_confirmation_toast() -> void:
	if _player == null:
		return
	watch_signals(EventBus)
	_press_and_release_quick_save()
	await wait_process_frames(2)
	assert_signal_emitted(EventBus, "toast_requested")

func test_quick_save_does_nothing_after_level_completed() -> void:
	if _player == null:
		return
	_level._level_completed = true
	_press_and_release_quick_save()
	await wait_process_frames(2)
	assert_false(ProgressStore.has_checkpoint_for("2"), "a completed level has nothing left to resume mid-way through")
