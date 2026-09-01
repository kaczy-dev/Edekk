extends GutTest
## rpg.md section 11 backlog ("pogoda niezależna od cyklu dobowego").
## WeatherOverlay is instanced via its scene (not bare .new()) because its
## @onready fields need real $ColorRect/$RainParticles children — same
## pattern as test_ambient_pedestrian.gd.

const WeatherOverlayScene := preload("res://scenes/ui/WeatherOverlay.tscn")

var _overlay: WeatherOverlay


func before_each() -> void:
	_overlay = WeatherOverlayScene.instantiate()
	add_child_autofree(_overlay)


func test_starts_with_a_valid_state_and_positive_timer() -> void:
	assert_true(
		_overlay.state
		in [WeatherOverlay.State.CLEAR, WeatherOverlay.State.RAIN, WeatherOverlay.State.FOG]
	)
	assert_gt(_overlay._timer, 0.0)


func test_color_for_clear_is_fully_transparent() -> void:
	assert_eq(_overlay._color_for(WeatherOverlay.State.CLEAR).a, 0.0)


func test_color_for_rain_and_fog_are_visible() -> void:
	assert_gt(_overlay._color_for(WeatherOverlay.State.RAIN).a, 0.0)
	assert_gt(_overlay._color_for(WeatherOverlay.State.FOG).a, 0.0)


func test_apply_state_instant_sets_rect_color_immediately() -> void:
	_overlay.state = WeatherOverlay.State.FOG
	_overlay._apply_state(true)
	assert_eq(_overlay._rect.color, WeatherOverlay.FOG_COLOR)


func test_apply_state_rain_enables_particle_emission() -> void:
	_overlay.state = WeatherOverlay.State.RAIN
	_overlay._apply_state(true)
	assert_true(_overlay._rain_particles.emitting)


func test_apply_state_non_rain_disables_particle_emission() -> void:
	_overlay.state = WeatherOverlay.State.CLEAR
	_overlay._apply_state(true)
	assert_false(_overlay._rain_particles.emitting)


func test_process_picks_new_state_once_timer_elapses() -> void:
	_overlay._timer = 0.01
	_overlay._process(0.016)
	assert_gt(_overlay._timer, 0.0, "a fresh MIN..MAX timer was rolled for the next state")
