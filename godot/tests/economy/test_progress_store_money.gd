extends GutTest
## rpg.md section 6 backlog ("Ekonomia miejska") — ProgressStore.money/
## add_money()/spend_money(). Redirects save_path to a disposable file, same
## pattern as test_gameplay.gd/test_level7.gd, so this never touches the
## real user://progress.json.

const TEST_SAVE_PATH := "user://test_progress_money.json"

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
	assert_eq(ProgressStore.money, 0)

func test_add_money_increases_balance() -> void:
	ProgressStore.add_money(20)
	assert_eq(ProgressStore.money, 20)

func test_spend_money_succeeds_when_affordable() -> void:
	ProgressStore.add_money(10)
	var ok := ProgressStore.spend_money(5)
	assert_true(ok)
	assert_eq(ProgressStore.money, 5)

func test_spend_money_fails_when_insufficient_and_changes_nothing() -> void:
	ProgressStore.add_money(3)
	var ok := ProgressStore.spend_money(5)
	assert_false(ok)
	assert_eq(ProgressStore.money, 3, "a failed purchase must not deduct anything")

func test_spend_zero_or_negative_is_a_noop() -> void:
	ProgressStore.add_money(10)
	assert_false(ProgressStore.spend_money(0))
	assert_false(ProgressStore.spend_money(-5))
	assert_eq(ProgressStore.money, 10)

func test_money_persists_across_save_and_load() -> void:
	ProgressStore.add_money(15)
	ProgressStore.load_progress() # re-reads the file add_money() just wrote
	assert_eq(ProgressStore.money, 15)
