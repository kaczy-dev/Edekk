extends GutTest
## GUT port of the ad-hoc MenuSmokeTest.gd — SceneRouter's real
## change_scene_to_file() fade+swap (triggered by emitting the actual
## Settings button's `pressed` signal, not a reimplementation) and
## DebugConsole's `~` toggle + graceful no-active-level command handling.

const LevelSelectScene := preload("res://scenes/menu/LevelSelect.tscn")

func test_settings_button_routes_through_scene_router() -> void:
	# Instantiated under the scene tree root (not add_child_autofree onto
	# this test node) and made current_scene, mirroring how a real
	# menu-to-menu transition actually happens — SceneRouter reads
	# get_tree().current_scene. A frame of delay first: the tree is still
	# finishing setup of this test's own scene at this point, and
	# root.add_child() during that window fails ("Parent node is busy
	# setting up children").
	await wait_physics_frames(1)
	var menu := LevelSelectScene.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await wait_physics_frames(2)

	var settings_button: Button = menu.get_node("Panel/Content/SettingsButton")
	assert_not_null(settings_button, "LevelSelectMenu has a SettingsButton node")
	settings_button.pressed.emit()
	# SceneRouter fade is 0.25s out + 0.25s in = 0.5s total; give it margin.
	await wait_seconds(0.8)
	var current := get_tree().current_scene
	var current_name: String = str(current.name) if current != null else "null"
	var current_is_settings: bool = current != null and current.get_script() != null and current.get_script().get_global_name() == &"SettingsMenu"
	assert_true(current_is_settings, "SettingsButton press -> SceneRouter swaps current_scene to SettingsMenu (got %s)" % current_name)

	current.queue_free()

func test_debug_console_toggle_and_graceful_no_level() -> void:
	assert_false(DebugConsole._panel.visible, "DebugConsole panel starts hidden")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_QUOTELEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_physics_frames(1)
	assert_true(DebugConsole._panel.visible, "backtick toggles DebugConsole panel visible")

	# No LevelRuntime active — commands touching level state must fail
	# gracefully, not crash.
	DebugConsole._run_command("/god")
	DebugConsole._run_command("/give_item mouse 1")
	pass_test("/god and /give_item with no active LevelRuntime don't crash the console")

	var ev_up := InputEventKey.new()
	ev_up.physical_keycode = KEY_QUOTELEFT
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	# Leave the panel state as the toggle left it — DebugConsole is an
	# autoload, its state persists into whatever runs next in this session.
	DebugConsole._panel.visible = false
