extends GutTest
## rpg.md section 11 backlog ("Log/dziennik questów") —
## ProgressStore.quest_completion_history/record_quest_completed()/
## has_completed_quest(). Persisted, idempotent per (level_id, quest_id).

const TEST_SAVE_PATH := "user://test_progress_quest_history.json"

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

func test_starts_empty() -> void:
	assert_eq(ProgressStore.quest_completion_history.size(), 0)
	assert_false(ProgressStore.has_completed_quest("1", "some_quest"))

func test_record_quest_completed_appends_an_entry() -> void:
	ProgressStore.record_quest_completed("1", "find_ball")
	assert_eq(ProgressStore.quest_completion_history.size(), 1)
	assert_true(ProgressStore.has_completed_quest("1", "find_ball"))
	var entry: Dictionary = ProgressStore.quest_completion_history[0]
	assert_eq(entry.level_id, "1")
	assert_eq(entry.quest_id, "find_ball")

func test_record_quest_completed_is_idempotent() -> void:
	ProgressStore.record_quest_completed("1", "find_ball")
	ProgressStore.record_quest_completed("1", "find_ball")
	assert_eq(ProgressStore.quest_completion_history.size(), 1, "recording the same completion twice should not duplicate")

func test_same_quest_id_on_a_different_level_is_a_separate_entry() -> void:
	ProgressStore.record_quest_completed("1", "find_ball")
	ProgressStore.record_quest_completed("2", "find_ball")
	assert_eq(ProgressStore.quest_completion_history.size(), 2)

func test_history_persists_across_save_and_load() -> void:
	ProgressStore.record_quest_completed("3", "talk_to_cat")
	ProgressStore.load_progress()
	assert_true(ProgressStore.has_completed_quest("3", "talk_to_cat"))
