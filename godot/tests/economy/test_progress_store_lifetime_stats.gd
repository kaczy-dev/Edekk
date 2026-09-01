extends GutTest
## rpg.md section 11 backlog ("Osiągnięcia/statystyki życiowe") —
## total_enemies_defeated/total_money_earned/total_days_survived. Unlike
## day_earned/day_spent/day_fights_won (test_progress_store_day_summary.gd),
## these never reset and DO persist — that's the whole point of "lifetime".

const TEST_SAVE_PATH := "user://test_progress_lifetime_stats.json"

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

func test_starts_at_zero() -> void:
	assert_eq(ProgressStore.total_enemies_defeated, 0)
	assert_eq(ProgressStore.total_money_earned, 0)
	assert_eq(ProgressStore.total_days_survived, 0)

func test_enemy_died_increments_lifetime_total() -> void:
	EventBus.enemy_died.emit("obj_a")
	EventBus.enemy_died.emit("obj_b")
	assert_eq(ProgressStore.total_enemies_defeated, 2)

func test_add_money_increments_lifetime_total() -> void:
	ProgressStore.add_money(10)
	ProgressStore.add_money(5)
	assert_eq(ProgressStore.total_money_earned, 15)

func test_spend_money_does_not_reduce_lifetime_earned() -> void:
	ProgressStore.add_money(20)
	ProgressStore.spend_money(15)
	assert_eq(ProgressStore.total_money_earned, 20, "lifetime earned tracks income, not current balance")

func test_day_changed_increments_days_survived() -> void:
	ProgressStore._on_day_changed(1)
	ProgressStore._on_day_changed(2)
	assert_eq(ProgressStore.total_days_survived, 2)

func test_day_summary_reset_does_not_reset_lifetime_totals() -> void:
	ProgressStore.add_money(20)
	EventBus.enemy_died.emit("obj")
	ProgressStore._on_day_changed(1)
	assert_eq(ProgressStore.total_money_earned, 20)
	assert_eq(ProgressStore.total_enemies_defeated, 1)
	assert_eq(ProgressStore.day_earned, 0, "day_earned resets, unlike the lifetime total")

func test_lifetime_stats_persist_across_save_and_load() -> void:
	ProgressStore.add_money(30)
	EventBus.enemy_died.emit("obj")
	ProgressStore._on_day_changed(1)
	ProgressStore.load_progress()
	assert_eq(ProgressStore.total_money_earned, 30)
	assert_eq(ProgressStore.total_enemies_defeated, 1)
	assert_eq(ProgressStore.total_days_survived, 1)
