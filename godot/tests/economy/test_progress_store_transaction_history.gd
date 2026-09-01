extends GutTest
## rpg.md section 11 backlog ("Historia transakcji") —
## ProgressStore.transaction_history, appended by add_money()/spend_money(),
## capped at MAX_TRANSACTION_HISTORY, persisted across save/load.

const TEST_SAVE_PATH := "user://test_progress_transaction_history.json"

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
	assert_eq(ProgressStore.transaction_history.size(), 0)

func test_add_money_appends_an_earn_entry() -> void:
	ProgressStore.add_money(15)
	assert_eq(ProgressStore.transaction_history.size(), 1)
	var entry: Dictionary = ProgressStore.transaction_history[0]
	assert_eq(entry.type, "earn")
	assert_eq(entry.amount, 15)

func test_spend_money_appends_a_spend_entry() -> void:
	ProgressStore.add_money(20)
	ProgressStore.spend_money(5)
	assert_eq(ProgressStore.transaction_history.size(), 2)
	var entry: Dictionary = ProgressStore.transaction_history[1]
	assert_eq(entry.type, "spend")
	assert_eq(entry.amount, 5)

func test_failed_spend_does_not_append_an_entry() -> void:
	ProgressStore.add_money(3)
	ProgressStore.spend_money(10)
	assert_eq(ProgressStore.transaction_history.size(), 1, "only the add_money entry should exist")

func test_history_is_capped_at_max_size() -> void:
	for i in range(ProgressStore.MAX_TRANSACTION_HISTORY + 10):
		ProgressStore.add_money(1)
	assert_eq(ProgressStore.transaction_history.size(), ProgressStore.MAX_TRANSACTION_HISTORY)

func test_history_persists_across_save_and_load() -> void:
	ProgressStore.add_money(7)
	ProgressStore.load_progress()
	assert_eq(ProgressStore.transaction_history.size(), 1)
	# JSON round-trips ints as floats — cast back before comparing, same
	# reasoning as best_level_times/day comparisons elsewhere in this file.
	assert_eq(int(ProgressStore.transaction_history[0].amount), 7)
