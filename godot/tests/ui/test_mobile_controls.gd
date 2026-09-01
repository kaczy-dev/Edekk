extends GutTest
## rpg.md section 8 (2026-08-31) — mobile touch controls.

const MobileControlsScene := preload("res://scenes/ui/MobileControls.tscn")

var _real_mobile_controls: String

func before_all() -> void:
	_real_mobile_controls = SettingsStore.mobile_controls

func after_all() -> void:
	SettingsStore.mobile_controls = _real_mobile_controls

func test_should_show_on_forces_true() -> void:
	SettingsStore.mobile_controls = "on"
	assert_true(MobileControls.should_show())

func test_should_show_off_forces_false() -> void:
	SettingsStore.mobile_controls = "off"
	assert_false(MobileControls.should_show())

func test_should_show_auto_matches_touchscreen_availability() -> void:
	SettingsStore.mobile_controls = "auto"
	assert_eq(MobileControls.should_show(), DisplayServer.is_touchscreen_available())

func test_touch_button_presses_and_releases_its_action() -> void:
	var button := TouchButton.new()
	button.action = &"hop"
	add_child_autofree(button)
	assert_false(Input.is_action_pressed("hop"))
	button.button_down.emit()
	assert_true(Input.is_action_pressed("hop"))
	button.button_up.emit()
	assert_false(Input.is_action_pressed("hop"))

## Drives TouchJoystick._update()/_reset() directly rather than through
## simulated InputEventMouseButton/parse_input_event() — verified headless
## GUT runs (no real Window/DisplayServer) never deliver position-based
## mouse events to Node._input() at all (unlike the action-based
## InputEventKey used elsewhere in this test suite, e.g. test_gameplay.gd,
## which Input's global action-state map picks up regardless of a window).
## This still exercises the real axis-mapping logic, just not the OS-event
## plumbing on top of it — the same category of thing this project's other
## tests already accept can't be verified headless (no screenshot/real-
## input-simulation tool, see rpg.md's "nieprzetestowane wizualnie" notes).
func test_touch_joystick_drives_move_actions() -> void:
	var controls := MobileControlsScene.instantiate()
	add_child_autofree(controls)
	await wait_physics_frames(1)

	var joystick := controls.get_node("Joystick") as TouchJoystick
	var pad_center: Vector2 = joystick.get_node("Pad").get_global_rect().get_center()

	joystick._update(pad_center + Vector2(joystick.radius, 0)) # full right
	assert_true(Input.is_action_pressed("move_right"), "dragging the joystick fully right presses move_right")
	assert_false(Input.is_action_pressed("move_left"))

	joystick._reset()
	assert_false(Input.is_action_pressed("move_right"), "releasing the joystick clears the action")
