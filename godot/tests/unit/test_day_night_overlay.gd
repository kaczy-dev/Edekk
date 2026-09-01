extends GutTest
## rpg.md section 6 backlog. DayNightOverlay.night_factor() reads
## TimeManager directly (see its own header for why this is a separate
## overlay from AtmosphereFX.gd's mood system) — tested via a bare instance
## (never added to the tree, no _process ticking) so only the pure
## calculation is under test.

var _overlay: DayNightOverlay
var _saved_hour: int
var _saved_minute: int

func before_each() -> void:
	_saved_hour = TimeManager.current_hour
	_saved_minute = TimeManager.current_minute
	_overlay = DayNightOverlay.new()

func after_each() -> void:
	TimeManager.current_hour = _saved_hour
	TimeManager.current_minute = _saved_minute
	_overlay.free()

func test_full_night_factor_at_midnight() -> void:
	TimeManager.current_hour = 0
	TimeManager.current_minute = 0
	assert_eq(_overlay.night_factor(), 1.0)

func test_zero_factor_at_noon() -> void:
	TimeManager.current_hour = 12
	TimeManager.current_minute = 0
	assert_eq(_overlay.night_factor(), 0.0)

func test_half_faded_at_dusk_midpoint() -> void:
	TimeManager.current_hour = 20 # 20:00, midpoint of 19:00-21:00 dusk window
	TimeManager.current_minute = 0
	assert_almost_eq(_overlay.night_factor(), 0.5, 0.01)

func test_half_faded_at_dawn_midpoint() -> void:
	TimeManager.current_hour = 6 # 06:00, midpoint of 05:00-07:00 dawn window
	TimeManager.current_minute = 0
	assert_almost_eq(_overlay.night_factor(), 0.5, 0.01)
