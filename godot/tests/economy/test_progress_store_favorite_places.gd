extends GutTest
## rpg.md backlog ("Ulubione miejsca") — ProgressStore.favorite_places,
## toggled by toggle_favorite()/read by is_favorite()/get_favorites(),
## persisted across save/load. Same reset-progress-per-test / redirected
## save_path pattern as test_progress_store_transaction_history.gd.

const TEST_SAVE_PATH := "user://test_progress_favorite_places.json"

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
	assert_eq(ProgressStore.get_favorites().size(), 0)
	assert_false(ProgressStore.is_favorite("1", "npc_1"))

func test_toggle_favorite_adds_an_entry() -> void:
	var now_favorite := ProgressStore.toggle_favorite("1", "npc_1", "Ala")
	assert_true(now_favorite)
	assert_true(ProgressStore.is_favorite("1", "npc_1"))
	assert_eq(ProgressStore.get_favorites().size(), 1)
	var entry: Dictionary = ProgressStore.get_favorites()[0]
	assert_eq(entry.level_id, "1")
	assert_eq(entry.obj_id, "npc_1")
	assert_eq(entry.label, "Ala")

func test_toggle_favorite_again_removes_it() -> void:
	ProgressStore.toggle_favorite("1", "npc_1", "Ala")
	var now_favorite := ProgressStore.toggle_favorite("1", "npc_1", "Ala")
	assert_false(now_favorite)
	assert_false(ProgressStore.is_favorite("1", "npc_1"))
	assert_eq(ProgressStore.get_favorites().size(), 0)

func test_same_obj_id_on_different_levels_is_tracked_separately() -> void:
	ProgressStore.toggle_favorite("1", "vending_a", "Automat")
	ProgressStore.toggle_favorite("2", "vending_a", "Automat")
	assert_true(ProgressStore.is_favorite("1", "vending_a"))
	assert_true(ProgressStore.is_favorite("2", "vending_a"))
	assert_eq(ProgressStore.get_favorites().size(), 2)

func test_favorites_persist_across_save_and_load() -> void:
	ProgressStore.toggle_favorite("3", "npc_bob", "Bob")
	ProgressStore.load_progress()
	assert_true(ProgressStore.is_favorite("3", "npc_bob"))
	assert_eq(ProgressStore.get_favorites().size(), 1)
