extends GutTest
## rpg.md backlog ("Tryb 'szybkiego dnia'") — RestSpot.gd. Redirects
## ProgressStore.save_path like test_vending_machine.gd, even though
## RestSpot itself never touches money — TimeManager.advance_minutes() can
## cross a day boundary and fire ProgressStore._on_day_changed(), which
## autosaves.

const RestSpotScene := preload("res://scenes/interactables/RestSpot.tscn")
const TEST_SAVE_PATH := "user://test_progress_rest_spot.json"

var _real_save_path: String
var _spot: RestSpot


func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH


func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func before_each() -> void:
	ProgressStore.reset_progress()
	_spot = RestSpotScene.instantiate()
	add_child_autofree(_spot)


func test_interact_advances_the_clock() -> void:
	var start_hour := TimeManager.current_hour
	_spot.interact(null)
	assert_eq(TimeManager.current_hour, (start_hour + _spot.hours_to_advance) % 24)


func test_interact_requests_a_full_energy_restore() -> void:
	watch_signals(EventBus)
	_spot.interact(null)
	assert_signal_emitted_with_parameters(
		EventBus,
		"energy_restore_requested",
		[Difficulty.MAX_ENERGY],
	)


func test_interact_emits_a_toast() -> void:
	watch_signals(EventBus)
	_spot.interact(null)
	assert_signal_emitted(EventBus, "toast_requested")


func test_can_be_used_repeatedly() -> void:
	var start_hour := TimeManager.current_hour
	_spot.interact(null)
	_spot.interact(null)
	assert_eq(TimeManager.current_hour, (start_hour + _spot.hours_to_advance * 2) % 24)


func test_get_favorite_label_is_stable() -> void:
	assert_eq(_spot.get_favorite_label(), "🛋️ Miejsce odpoczynku")
