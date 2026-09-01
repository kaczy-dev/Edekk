extends GutTest
## rpg.md section 11 backlog ("Szybki zapis / mid-level resume") —
## ProgressStore.save_checkpoint()/clear_checkpoint()/has_checkpoint_for().
## Redirects save_path to a disposable file, same pattern as
## test_progress_store_money.gd, so this never touches the real
## user://progress.json.

const TEST_SAVE_PATH := "user://test_progress_checkpoint.json"

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

func test_starts_with_no_checkpoint() -> void:
	assert_false(ProgressStore.has_checkpoint_for("2"))

func test_save_checkpoint_records_level_position_and_hp() -> void:
	ProgressStore.save_checkpoint("2", Vector2(120, -40), 7)
	assert_true(ProgressStore.has_checkpoint_for("2"))
	assert_eq(ProgressStore.get_checkpoint_position(), Vector2(120, -40))
	assert_eq(ProgressStore.resume_hp, 7)

func test_checkpoint_is_scoped_to_its_own_level() -> void:
	ProgressStore.save_checkpoint("2", Vector2(120, -40), 7)
	assert_false(ProgressStore.has_checkpoint_for("3"), "a checkpoint from level 2 must not apply to level 3")

func test_clear_checkpoint_resets_state() -> void:
	ProgressStore.save_checkpoint("2", Vector2(120, -40), 7)
	ProgressStore.clear_checkpoint()
	assert_false(ProgressStore.has_checkpoint_for("2"))
	assert_eq(ProgressStore.resume_hp, -1)

func test_checkpoint_persists_across_save_and_load() -> void:
	ProgressStore.save_checkpoint("4", Vector2(10, 20), 3)
	ProgressStore.load_progress() # re-reads the file save_checkpoint() just wrote
	assert_true(ProgressStore.has_checkpoint_for("4"))
	assert_eq(ProgressStore.get_checkpoint_position(), Vector2(10, 20))
	assert_eq(ProgressStore.resume_hp, 3)

func test_saving_a_newer_checkpoint_overwrites_the_previous_one() -> void:
	ProgressStore.save_checkpoint("2", Vector2(1, 1), 5)
	ProgressStore.save_checkpoint("2", Vector2(2, 2), 9)
	assert_eq(ProgressStore.get_checkpoint_position(), Vector2(2, 2))
	assert_eq(ProgressStore.resume_hp, 9)
