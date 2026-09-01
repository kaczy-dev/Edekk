extends GutTest
## rpg.md backlog ("Rebindowanie klawiszy") — SettingsStore.set_keybind()/
## reset_keybind()/reset_all_keybinds()/get_key_label(), and that a rebind
## actually changes what InputMap reports (not just SettingsStore's own
## bookkeeping). Redirects SAVE_PATH to a disposable file, same pattern as
## test_progress_store_checkpoint.gd, so this never touches the real
## user://settings.json.

const TEST_SAVE_PATH := "user://test_settings_rebind.json"

var _real_save_path: String
var _real_keybinds: Dictionary

func before_all() -> void:
	_real_save_path = SettingsStore.SAVE_PATH
	SettingsStore.SAVE_PATH = TEST_SAVE_PATH

func after_all() -> void:
	SettingsStore.SAVE_PATH = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

func before_each() -> void:
	_real_keybinds = SettingsStore.custom_keybinds.duplicate()
	SettingsStore.custom_keybinds = {}

func after_each() -> void:
	# Restore every action this test may have touched to the engine's real
	# default, so later test files (and a real play session in this same
	# process, e.g. GUT's own editor run) never inherit a test's rebind.
	SettingsStore.reset_all_keybinds()
	SettingsStore.custom_keybinds = _real_keybinds
	for action: String in _real_keybinds:
		SettingsStore._apply_single_keybind(action, _real_keybinds[action])

func test_default_key_label_matches_project_settings() -> void:
	assert_eq(SettingsStore.get_key_label("attack"), OS.get_keycode_string(KEY_J))

func test_set_keybind_changes_inputmap_and_label() -> void:
	SettingsStore.set_keybind("attack", KEY_K)
	assert_eq(SettingsStore.get_key_label("attack"), OS.get_keycode_string(KEY_K))
	var found := false
	for ev in InputMap.action_get_events("attack"):
		if ev is InputEventKey and ev.physical_keycode == KEY_K:
			found = true
	assert_true(found, "InputMap should carry the new key for 'attack'")

func test_set_keybind_rejects_unknown_action() -> void:
	SettingsStore.set_keybind("not_a_real_action", KEY_K)
	assert_false(SettingsStore.custom_keybinds.has("not_a_real_action"))

func test_reset_keybind_restores_default() -> void:
	SettingsStore.set_keybind("hop", KEY_K)
	SettingsStore.reset_keybind("hop")
	assert_eq(SettingsStore.get_key_label("hop"), OS.get_keycode_string(KEY_SPACE))
	assert_false(SettingsStore.custom_keybinds.has("hop"))

func test_conflicting_rebind_clears_the_other_action() -> void:
	# 'attack' defaults to J; rebinding 'hop' onto J must free 'attack'
	# rather than leaving both actions firing on the same keypress.
	SettingsStore.set_keybind("hop", KEY_J)
	assert_eq(SettingsStore.get_key_label("hop"), OS.get_keycode_string(KEY_J))
	assert_eq(SettingsStore.get_key_label("attack"), "—")

func test_reset_all_keybinds_clears_every_override() -> void:
	SettingsStore.set_keybind("attack", KEY_K)
	SettingsStore.set_keybind("hop", KEY_L)
	SettingsStore.reset_all_keybinds()
	assert_true(SettingsStore.custom_keybinds.is_empty())
	assert_eq(SettingsStore.get_key_label("attack"), OS.get_keycode_string(KEY_J))
	assert_eq(SettingsStore.get_key_label("hop"), OS.get_keycode_string(KEY_SPACE))

func test_keybind_persists_across_save_and_load() -> void:
	SettingsStore.set_keybind("interact", KEY_F)
	SettingsStore.load_settings() # re-reads the file set_keybind() just wrote
	assert_eq(SettingsStore.custom_keybinds.get("interact"), KEY_F)
