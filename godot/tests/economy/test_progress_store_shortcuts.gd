extends GutTest
## rpg.md backlog ("Kryjówki/skróty") — ProgressStore.unlocked_shortcuts,
## same redirected-save_path pattern as test_progress_store_favorite_places.gd.

const TEST_SAVE_PATH := "user://test_progress_shortcuts.json"

var _real_save_path: String


func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH


func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func before_each() -> void:
	ProgressStore.reset_progress()


func test_starts_locked() -> void:
	assert_false(ProgressStore.is_shortcut_unlocked("gate_1"))


func test_unlock_shortcut_marks_it_unlocked() -> void:
	ProgressStore.unlock_shortcut("gate_1")
	assert_true(ProgressStore.is_shortcut_unlocked("gate_1"))


func test_unlocking_twice_does_not_duplicate() -> void:
	ProgressStore.unlock_shortcut("gate_1")
	ProgressStore.unlock_shortcut("gate_1")
	assert_eq(ProgressStore.unlocked_shortcuts.size(), 1)


func test_reset_progress_relocks_everything() -> void:
	ProgressStore.unlock_shortcut("gate_1")
	ProgressStore.reset_progress()
	assert_false(ProgressStore.is_shortcut_unlocked("gate_1"))


func test_unlocks_persist_across_save_and_load() -> void:
	ProgressStore.unlock_shortcut("gate_1")
	ProgressStore.load_progress()
	assert_true(ProgressStore.is_shortcut_unlocked("gate_1"))
