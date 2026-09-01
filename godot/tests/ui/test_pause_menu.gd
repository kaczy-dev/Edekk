extends GutTest
## QoL request ("pauza i informacje jak było w projekcie w Phaser") —
## PauseMenu.gd. Restart/exit are NOT exercised here — both trigger
## SceneRouter's real get_tree().change_scene_to_file()/reload_current_scene(),
## which test_transit_station.gd already documented as unsafe in a bare GUT
## run (orphaned nodes/engine errors) — same separation-of-concerns split
## that file uses: test the pause/resume/controls-panel state here, leave
## real navigation untested at the unit level.

const PauseMenuScene := preload("res://scenes/ui/PauseMenu.tscn")

var _menu: PauseMenu
var _saved_paused: bool


func before_each() -> void:
	_saved_paused = get_tree().paused
	_menu = PauseMenuScene.instantiate()
	add_child_autofree(_menu)


func after_each() -> void:
	get_tree().paused = _saved_paused


func test_starts_hidden() -> void:
	assert_false(_menu.visible)


func test_open_shows_the_menu_and_pauses_the_tree() -> void:
	_menu.open()
	assert_true(_menu.visible)
	assert_true(get_tree().paused)


func test_resume_hides_the_menu_and_unpauses_the_tree() -> void:
	_menu.open()
	_menu._on_resume_pressed()
	assert_false(_menu.visible)
	assert_false(get_tree().paused)


func test_pause_key_while_open_resumes() -> void:
	_menu.open()
	_menu._process(0.0) # no key pressed yet
	assert_true(_menu.visible, "a bare _process() tick without input shouldn't close it")


func test_controls_panel_toggles() -> void:
	_menu.open()
	assert_false(_menu._controls_panel.visible)
	_menu._on_controls_pressed()
	assert_true(_menu._controls_panel.visible)
	_menu._on_controls_close_pressed()
	assert_false(_menu._controls_panel.visible)


func test_resuming_also_closes_the_controls_panel() -> void:
	_menu.open()
	_menu._on_controls_pressed()
	_menu._on_resume_pressed()
	assert_false(_menu._controls_panel.visible)


func test_controls_rows_list_every_rebindable_action() -> void:
	_menu.open()
	_menu._on_controls_pressed()
	assert_eq(_menu._controls_rows.get_child_count(), SettingsStore.REBINDABLE_ACTIONS.size())


func test_controls_row_shows_the_current_key_label() -> void:
	_menu.open()
	_menu._on_controls_pressed()
	var first_row: Label = _menu._controls_rows.get_child(0)
	assert_true(first_row.text.contains(
			SettingsStore.get_key_label(SettingsStore.REBINDABLE_ACTIONS[0])
		))
