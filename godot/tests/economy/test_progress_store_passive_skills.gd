extends GutTest
## rpg.md backlog ("'Umiejętności' jako pasywne bonusy za pieniądze/reputację
## ... zamiast pełnego drzewka") — ProgressStore.purchased_skills, same
## redirected-save_path pattern as test_progress_store_shortcuts.gd.

const TEST_SAVE_PATH := "user://test_progress_passive_skills.json"

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


func test_starts_unpurchased() -> void:
	assert_false(ProgressStore.is_skill_purchased("cheaper_shopping"))


func test_purchase_with_enough_money_succeeds() -> void:
	ProgressStore.add_money(50)
	assert_true(ProgressStore.purchase_skill("cheaper_shopping"))
	assert_true(ProgressStore.is_skill_purchased("cheaper_shopping"))
	assert_eq(ProgressStore.money, 0)


func test_purchase_without_enough_money_fails() -> void:
	ProgressStore.add_money(10)
	assert_false(ProgressStore.purchase_skill("cheaper_shopping"))
	assert_false(ProgressStore.is_skill_purchased("cheaper_shopping"))
	assert_eq(ProgressStore.money, 10, "a failed purchase never charges")


func test_purchasing_twice_does_not_double_charge() -> void:
	ProgressStore.add_money(1000)
	ProgressStore.purchase_skill("cheaper_shopping")
	var money_after_first_purchase := ProgressStore.money
	assert_false(ProgressStore.purchase_skill("cheaper_shopping"))
	assert_eq(ProgressStore.money, money_after_first_purchase)
	assert_eq(ProgressStore.purchased_skills.size(), 1)


func test_unknown_skill_id_fails_without_charging() -> void:
	ProgressStore.add_money(1000)
	assert_false(ProgressStore.purchase_skill("does_not_exist"))
	assert_eq(ProgressStore.money, 1000)


func test_reset_progress_relocks_everything() -> void:
	ProgressStore.add_money(50)
	ProgressStore.purchase_skill("cheaper_shopping")
	ProgressStore.reset_progress()
	assert_false(ProgressStore.is_skill_purchased("cheaper_shopping"))


func test_purchases_persist_across_save_and_load() -> void:
	ProgressStore.add_money(50)
	ProgressStore.purchase_skill("cheaper_shopping")
	ProgressStore.load_progress()
	assert_true(ProgressStore.is_skill_purchased("cheaper_shopping"))
