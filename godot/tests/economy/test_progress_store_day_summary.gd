extends GutTest
## rpg.md section 11 backlog ("Podsumowanie dnia" + "Powiadomienia o niskiej
## energii/pieniądzach") — day_earned/day_spent/day_fights_won tracking and
## the low-money toast in ProgressStore.gd. Redirects save_path like
## test_progress_store_money.gd so this never touches the real save.

const TEST_SAVE_PATH := "user://test_progress_day_summary.json"

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
	# reset_progress() deliberately doesn't touch these (they're not part of
	# the persisted save, see ProgressStore.gd) — but that also means a
	# fight/purchase in an EARLIER test file's real gameplay can leak a
	# nonzero day_fights_won/day_earned/day_spent into this file's first
	# test unless it's zeroed here too.
	ProgressStore.day_earned = 0
	ProgressStore.day_spent = 0
	ProgressStore.day_fights_won = 0
	_toasts.clear()
	EventBus.toast_requested.connect(_on_toast)

func after_each() -> void:
	if EventBus.toast_requested.is_connected(_on_toast):
		EventBus.toast_requested.disconnect(_on_toast)

func _on_toast(text: String) -> void:
	_toasts.append(text)

func test_add_money_tracks_day_earned() -> void:
	ProgressStore.add_money(20)
	assert_eq(ProgressStore.day_earned, 20)

func test_spend_money_tracks_day_spent() -> void:
	ProgressStore.add_money(10)
	ProgressStore.spend_money(4)
	assert_eq(ProgressStore.day_spent, 4)

func test_spend_below_threshold_emits_low_money_toast() -> void:
	ProgressStore.add_money(6)
	ProgressStore.spend_money(3)
	assert_true(ProgressStore.money < ProgressStore.LOW_MONEY_THRESHOLD)
	assert_true(_toasts.size() > 0, "expected a low-money toast")

func test_spend_above_threshold_emits_no_low_money_toast() -> void:
	ProgressStore.add_money(100)
	ProgressStore.spend_money(10)
	assert_eq(_toasts.size(), 0)

func test_enemy_died_increments_day_fights_won() -> void:
	EventBus.enemy_died.emit("some_obj_id")
	assert_eq(ProgressStore.day_fights_won, 1)

func test_day_changed_emits_summary_toast_and_resets_counters() -> void:
	ProgressStore.add_money(20)
	ProgressStore.spend_money(5)
	EventBus.enemy_died.emit("obj")
	_toasts.clear()
	ProgressStore._on_day_changed(2)
	assert_eq(_toasts.size(), 1)
	assert_eq(ProgressStore.day_earned, 0)
	assert_eq(ProgressStore.day_spent, 0)
	assert_eq(ProgressStore.day_fights_won, 0)

func test_day_changed_with_no_activity_emits_no_toast() -> void:
	ProgressStore._on_day_changed(2)
	assert_eq(_toasts.size(), 0)
