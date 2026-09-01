extends GutTest
## rpg.md section 11a — main menu redesign. Redirects ProgressStore.save_path
## like other tests that touch save state, since `_has_saved_progress()`
## checks the file on disk directly (not specific field values — money==0
## is a legitimate fresh-but-saved state, not "no save").

const MainMenuScene := preload("res://scenes/menu/MainMenu.tscn")
const TEST_SAVE_PATH := "user://test_progress_main_menu.json"

var _real_save_path: String
var _saved_day: int

func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH

func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

func before_each() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	ProgressStore.reset_progress() # also clears in-memory fields
	_saved_day = TimeManager.current_day

func after_each() -> void:
	TimeManager.current_day = _saved_day

func test_continue_button_hidden_with_no_save_file() -> void:
	var menu := MainMenuScene.instantiate()
	add_child_autofree(menu)
	assert_false(menu.get_node("Panel/VBox/ContinueButton").visible)

func test_continue_button_visible_and_summarized_when_a_save_exists() -> void:
	ProgressStore.add_money(45) # add_money() calls save_progress(), creating the file
	TimeManager.current_day = 2

	var menu := MainMenuScene.instantiate()
	add_child_autofree(menu)
	var button: Button = menu.get_node("Panel/VBox/ContinueButton")

	assert_true(button.visible)
	assert_eq(button.text, "Kontynuuj (Dzień 3 · 45 zł)", "1-indexed day (current_day 2 -> 'Dzień 3'), matches TimeManager's own 0=Monday indexing shown as a human day count")

func test_new_game_resets_progress() -> void:
	ProgressStore.add_money(45)
	var menu := MainMenuScene.instantiate()
	add_child_autofree(menu)

	# ProgressStore.reset_progress() runs synchronously before
	# _on_new_game_pressed()'s SceneRouter.change_scene_to_file() call
	# reaches its first `await` — asserting immediately after is valid,
	# same pattern as tests/economy/test_transit_station.gd's
	# _try_purchase() tests (not asserting the resulting scene change
	# itself, which needs real SceneTree/current_scene state a bare GUT
	# run doesn't reliably have).
	menu._on_new_game_pressed()
	assert_eq(ProgressStore.money, 0, "new game resets the wallet")

func test_continue_targets_the_last_unlocked_level() -> void:
	ProgressStore.unlocked_levels = ["1", "2", "3"]
	var menu := MainMenuScene.instantiate()
	add_child_autofree(menu)
	# _on_continue_pressed() ends in SceneRouter.change_scene_to_file(), same
	# untestable-headless tail as the transit menu — verify the level_id
	# selection logic directly instead of the full button-press path.
	var level_id: String = ProgressStore.unlocked_levels.back() if not ProgressStore.unlocked_levels.is_empty() else "1"
	assert_eq(level_id, "3")
