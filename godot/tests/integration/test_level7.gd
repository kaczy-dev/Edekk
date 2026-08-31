extends GutTest
## GUT port of the ad-hoc Level7SmokeTest.gd — full end-to-end playthrough
## of Level 7 ("Salon"): collect bowl + ball, reach the door, verify level
## completion and progress persistence.
##
## Redirects ProgressStore.save_path to a disposable file for the duration
## of this script (see test_gameplay.gd's before_all()/after_all() for the
## same pattern and why) — this test also calls reset_progress(), which used
## to write the REAL user://progress.json.

const Level7Scene := preload("res://scenes/levels/Level7.tscn")
const TEST_SAVE_PATH := "user://test_progress.json"

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
	_level = Level7Scene.instantiate()
	add_child_autofree(_level)
	await wait_physics_frames(2)
	_player = get_tree().get_first_node_in_group("player")

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

func _collect_via_e(node_name: String) -> void:
	var node := _level.get_node_or_null(node_name)
	assert_not_null(node, "%s node exists in built scene" % node_name)
	if node == null:
		return
	_player.global_position = node.global_position
	_player.velocity = Vector2.ZERO
	await wait_seconds(0.15)
	_press_key(KEY_E)
	await wait_physics_frames(1)
	_release_key(KEY_E)
	await wait_seconds(0.15)

func test_full_playthrough_completes_the_level() -> void:
	assert_not_null(_player, "player spawned in Level7")
	if _player == null:
		return

	await _collect_via_e("Item_i-bowl")
	assert_true(_level._collected_ids.has("i-bowl"), "bowl collected")
	await _collect_via_e("Item_i-ball")
	assert_true(_level._collected_ids.has("i-ball"), "ball collected")

	var door := _level.get_node_or_null("Goal_door")
	assert_not_null(door, "Goal_door node exists in built scene")
	if door == null:
		return
	_player.global_position = door.global_position
	_player.velocity = Vector2.ZERO
	await wait_seconds(0.3)

	assert_true(_level._level_completed, "reaching the door with both items completes the level")
	assert_true(ProgressStore.is_completed("7"), "ProgressStore records level 7 as completed")
	assert_false(ProgressStore.is_unlocked("8"), "level 8 does NOT get auto-unlocked (7 is the last level)")
