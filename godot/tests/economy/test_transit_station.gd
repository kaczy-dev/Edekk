extends GutTest
## rpg.md section 6 backlog ("Metro i szybka podróż"). Redirects
## ProgressStore.save_path like the other economy tests. Tests the
## money/clock gating via TransitMenu._try_purchase() directly rather than
## the full _on_destination_selected() flow — that method also triggers
## SceneRouter's real get_tree().change_scene_to_file(), which needs actual
## SceneTree/current_scene state a bare GUT run doesn't have (confirmed:
## calling it here left orphaned nodes and engine-level "Method/function
## failed" errors even though the money/clock assertions themselves were
## correct — a test-environment artifact, not a production bug, but reason
## enough to test the two responsibilities separately).

const TEST_SAVE_PATH := "user://test_progress_transit.json"

var _real_save_path: String
var _saved_hour: int
var _saved_minute: int
var _station: TransitStation
var _destination: TransitDestination

func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH

func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

func before_each() -> void:
	ProgressStore.reset_progress()
	_saved_hour = TimeManager.current_hour
	_saved_minute = TimeManager.current_minute

	_destination = TransitDestination.new()
	_destination.display_name = "Test Station"
	_destination.target_scene_path = "res://scenes/dev/TestCombat.tscn"
	_destination.cost = 4
	_destination.travel_minutes = 30

	# Not added to the tree: interact() with an empty destinations list (the
	# only case tested against `_station` directly, see below) returns
	# early via a toast and never calls get_tree() — no _ready() child
	# lookups (IconLabel) needed for that path.
	_station = TransitStation.new()
	_station.destinations = [_destination]

func after_each() -> void:
	TimeManager.current_hour = _saved_hour
	TimeManager.current_minute = _saved_minute
	_station.free() # never entered the tree, so add_child_autofree can't clean it up

func test_empty_destinations_toasts_instead_of_opening_a_menu() -> void:
	_station.destinations = []
	watch_signals(EventBus)
	_station.interact(null)
	assert_signal_emitted(EventBus, "toast_requested")

func test_affordable_purchase_spends_money_and_advances_clock() -> void:
	ProgressStore.add_money(10)
	TimeManager.current_hour = 10
	TimeManager.current_minute = 0

	# _try_purchase() touches no node children (@onready _panel/_title/_list
	# only resolve when instanced from TransitMenu.tscn, which this bare
	# TransitMenu.new() isn't) and never calls get_tree() — safe to call
	# directly without tree membership.
	var menu := TransitMenu.new()
	var ok := menu._try_purchase(_destination)
	menu.free()

	assert_true(ok)
	assert_eq(ProgressStore.money, 10 - _destination.cost)
	assert_eq(TimeManager.current_hour, 10)
	assert_eq(TimeManager.current_minute, 30, "advance_minutes(30) moves the clock forward by exactly the travel time")

func test_unaffordable_purchase_changes_nothing() -> void:
	ProgressStore.add_money(0)
	TimeManager.current_hour = 10
	TimeManager.current_minute = 0
	watch_signals(EventBus)

	# _try_purchase() touches no node children (@onready _panel/_title/_list
	# only resolve when instanced from TransitMenu.tscn, which this bare
	# TransitMenu.new() isn't) and never calls get_tree() — safe to call
	# directly without tree membership.
	var menu := TransitMenu.new()
	var ok := menu._try_purchase(_destination)
	menu.free()

	assert_false(ok)
	assert_eq(ProgressStore.money, 0)
	assert_eq(TimeManager.current_minute, 0, "an unaffordable ticket must not advance the clock either")
	assert_signal_emitted(EventBus, "toast_requested")
