extends GutTest
## rpg.md section 11 backlog ("Log/dziennik questów") —
## LevelRuntime._update_status()'s newly-done detection: records into
## ProgressStore.quest_completion_history exactly once and fires a
## "Ukończono: ..." toast. Uses Level2's real "q2-squirrel" talk quest
## (data/levels/level_2.tres) via the real EventBus.npc_talked signal path,
## same as a player actually talking to the squirrel would trigger.

const Level2Scene := preload("res://scenes/levels/Level2.tscn")
const TEST_SAVE_PATH := "user://test_progress_quest_journal.json"

var _level
var _real_save_path: String
var _toasts: Array[String] = []

func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH

func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

func before_each() -> void:
	ProgressStore.reset_progress()
	_level = Level2Scene.instantiate()
	add_child_autofree(_level)
	await wait_physics_frames(2)
	_toasts.clear()
	EventBus.toast_requested.connect(_on_toast)

func after_each() -> void:
	if EventBus.toast_requested.is_connected(_on_toast):
		EventBus.toast_requested.disconnect(_on_toast)

func _on_toast(text: String) -> void:
	_toasts.append(text)

func test_talking_to_the_npc_records_the_quest_as_completed() -> void:
	assert_false(ProgressStore.has_completed_quest("2", "q2-squirrel"))
	EventBus.npc_talked.emit("squirrel", "squirrel")
	await wait_physics_frames(1)
	assert_true(ProgressStore.has_completed_quest("2", "q2-squirrel"))

func test_completing_a_quest_emits_exactly_one_toast() -> void:
	EventBus.npc_talked.emit("squirrel", "squirrel")
	await wait_physics_frames(1)
	var completion_toasts := _toasts.filter(func(t: String) -> bool: return t.begins_with("Ukończono:"))
	assert_eq(completion_toasts.size(), 1)

func test_status_updates_after_completion_do_not_re_record_or_re_toast() -> void:
	EventBus.npc_talked.emit("squirrel", "squirrel")
	await wait_physics_frames(1)
	_toasts.clear()
	_level._update_status() # simulate another periodic tick while already done
	var completion_toasts := _toasts.filter(func(t: String) -> bool: return t.begins_with("Ukończono:"))
	assert_eq(completion_toasts.size(), 0, "already-done quests must not re-toast every tick")
	assert_eq(ProgressStore.quest_completion_history.size(), 1)
