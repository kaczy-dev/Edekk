extends GutTest
## rpg.md section 6 backlog ("Cykl dobowy") — TimeManager is a real autoload
## that also ticks in _process() every real second; tests call
## _advance_minute()/advance_minutes() directly (deterministic) rather than
## waiting on real time, and save/restore its state so this doesn't leak
## into other test files running in the same process (same pattern as
## test_gameplay.gd swapping ProgressStore.save_path).

var _saved_minute: int
var _saved_hour: int
var _saved_day: int

func before_each() -> void:
	_saved_minute = TimeManager.current_minute
	_saved_hour = TimeManager.current_hour
	_saved_day = TimeManager.current_day

func after_each() -> void:
	TimeManager.current_minute = _saved_minute
	TimeManager.current_hour = _saved_hour
	TimeManager.current_day = _saved_day

func test_advance_minute_rolls_into_next_hour() -> void:
	TimeManager.current_hour = 10
	TimeManager.current_minute = 59
	watch_signals(TimeManager)
	TimeManager._advance_minute()
	assert_eq(TimeManager.current_minute, 0)
	assert_eq(TimeManager.current_hour, 11)
	assert_signal_emitted_with_parameters(TimeManager, "hour_changed", [11])

func test_hour_wraps_at_midnight_and_advances_day() -> void:
	TimeManager.current_hour = 23
	TimeManager.current_minute = 59
	TimeManager.current_day = 2
	watch_signals(TimeManager)
	TimeManager._advance_minute()
	assert_eq(TimeManager.current_hour, 0)
	assert_eq(TimeManager.current_day, 3)
	assert_signal_emitted_with_parameters(TimeManager, "day_changed", [3])

func test_day_wraps_after_sunday() -> void:
	TimeManager.current_hour = 23
	TimeManager.current_minute = 59
	TimeManager.current_day = 6
	TimeManager._advance_minute()
	assert_eq(TimeManager.current_day, 0, "day index wraps 6 (Sunday) back to 0 (Monday)")

func test_is_night_true_late_and_early() -> void:
	TimeManager.current_hour = 23
	assert_true(TimeManager.is_night())
	TimeManager.current_hour = 3
	assert_true(TimeManager.is_night())

func test_is_night_false_during_the_day() -> void:
	TimeManager.current_hour = 14
	assert_false(TimeManager.is_night())

func test_advance_minutes_only_fires_hour_changed_for_hours_actually_crossed() -> void:
	TimeManager.current_hour = 10
	TimeManager.current_minute = 50
	watch_signals(TimeManager)
	TimeManager.advance_minutes(30) # crosses 11:00 once, lands at 11:20
	assert_eq(TimeManager.current_hour, 11)
	assert_eq(TimeManager.current_minute, 20)
	assert_signal_emit_count(TimeManager, "hour_changed", 1)

func test_time_string_is_zero_padded() -> void:
	TimeManager.current_hour = 9
	TimeManager.current_minute = 5
	assert_eq(TimeManager.time_string(), "09:05")
