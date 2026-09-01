extends GutTest
## rpg.md section 6 backlog ("Reputacja w dzielnicach"). Same disposable
## save_path pattern as test_progress_store_money.gd.

const TEST_SAVE_PATH := "user://test_progress_reputation.json"

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

func test_unknown_zone_defaults_to_zero() -> void:
	assert_eq(ProgressStore.get_reputation("centrum"), 0)

func test_add_reputation_accumulates_per_zone() -> void:
	ProgressStore.add_reputation("centrum", 5)
	ProgressStore.add_reputation("centrum", 3)
	assert_eq(ProgressStore.get_reputation("centrum"), 8)

func test_reputation_is_independent_per_zone() -> void:
	ProgressStore.add_reputation("centrum", 5)
	ProgressStore.add_reputation("stare_miasto", -2)
	assert_eq(ProgressStore.get_reputation("centrum"), 5)
	assert_eq(ProgressStore.get_reputation("stare_miasto"), -2)

func test_negative_amount_is_allowed_reputation_can_drop() -> void:
	ProgressStore.add_reputation("centrum", 10)
	ProgressStore.add_reputation("centrum", -15)
	assert_eq(ProgressStore.get_reputation("centrum"), -5, "no floor at 0 — a zone can have negative standing")

func test_zero_amount_is_a_noop_and_emits_nothing() -> void:
	watch_signals(EventBus)
	ProgressStore.add_reputation("centrum", 0)
	assert_eq(ProgressStore.get_reputation("centrum"), 0)
	assert_signal_not_emitted(EventBus, "reputation_changed")

func test_add_reputation_emits_event_bus_signal() -> void:
	watch_signals(EventBus)
	ProgressStore.add_reputation("centrum", 7)
	assert_signal_emitted_with_parameters(EventBus, "reputation_changed", ["centrum", 7])

func test_reputation_persists_across_save_and_load() -> void:
	ProgressStore.add_reputation("centrum", 12)
	ProgressStore.load_progress()
	assert_eq(ProgressStore.get_reputation("centrum"), 12)
