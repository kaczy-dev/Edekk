extends GutTest
## rpg.md section 11 backlog ("Powiadomienia o niskiej energii") —
## LevelRuntime._check_low_energy_toast(), threshold-crossing only (not
## per-frame spam while energy sits below the line). Instantiates a real
## level like test_gameplay.gd/test_level7.gd, since energy state lives on
## LevelRuntime, not something callable in isolation.

const Level2Scene := preload("res://scenes/levels/Level2.tscn")
const TEST_SAVE_PATH := "user://test_progress_low_energy.json"

var _level
var _real_save_path: String
var _toasts: Array[String] = []

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
	_toasts.clear()
	EventBus.toast_requested.connect(_on_toast)

func after_each() -> void:
	if EventBus.toast_requested.is_connected(_on_toast):
		EventBus.toast_requested.disconnect(_on_toast)

func _on_toast(text: String) -> void:
	_toasts.append(text)

func test_crossing_below_threshold_emits_one_toast() -> void:
	_level._energy = 50.0
	_level._was_low_energy = false
	_level._check_low_energy_toast()
	assert_eq(_toasts.size(), 0, "still above threshold, no toast yet")

	_level._energy = 10.0
	_level._check_low_energy_toast()
	assert_eq(_toasts.size(), 1, "crossing below threshold should toast once")

func test_staying_below_threshold_does_not_repeat_toast() -> void:
	_level._energy = 10.0
	_level._check_low_energy_toast()
	_level._energy = 5.0
	_level._check_low_energy_toast()
	assert_eq(_toasts.size(), 1, "no repeat toast while still below threshold")

func test_recovering_above_threshold_resets_the_flag() -> void:
	_level._energy = 10.0
	_level._check_low_energy_toast()
	_level._energy = 90.0
	_level._check_low_energy_toast()
	assert_eq(_toasts.size(), 1, "recovering shouldn't itself toast")

	_level._energy = 10.0
	_level._check_low_energy_toast()
	assert_eq(_toasts.size(), 2, "dropping low again after recovery should toast again")

func test_restore_energy_also_checks_the_threshold() -> void:
	_level._energy = 10.0
	_level._was_low_energy = false
	_level.restore_energy(50.0)
	assert_eq(_toasts.size(), 0, "restoring above the threshold shouldn't toast")
