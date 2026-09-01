extends GutTest
## rpg.md section 6 backlog. Redirects ProgressStore.save_path like
## test_progress_store_money.gd — VendingMachine.interact() calls
## ProgressStore.spend_money(), which autosaves.

const VendingMachineScene := preload("res://scenes/economy/VendingMachine.tscn")
const TEST_SAVE_PATH := "user://test_progress_vending.json"

var _real_save_path: String
var _machine: VendingMachine

func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH

func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

func before_each() -> void:
	ProgressStore.reset_progress()
	_machine = VendingMachineScene.instantiate()
	add_child_autofree(_machine)

func test_successful_purchase_spends_money_and_restores_energy() -> void:
	ProgressStore.add_money(10)
	watch_signals(EventBus)
	_machine.interact(null)
	assert_eq(ProgressStore.money, 10 - _machine.cost)
	assert_signal_emitted_with_parameters(EventBus, "energy_restore_requested", [_machine.energy_restored])
	assert_signal_emitted_with_parameters(EventBus, "item_purchased", [&"cola", _machine.cost])
	assert_signal_emitted(EventBus, "toast_requested")

func test_failed_purchase_emits_only_a_toast() -> void:
	ProgressStore.add_money(0) # can't afford default cost
	watch_signals(EventBus)
	_machine.interact(null)
	assert_eq(ProgressStore.money, 0, "an unaffordable purchase changes nothing")
	assert_signal_not_emitted(EventBus, "energy_restore_requested")
	assert_signal_not_emitted(EventBus, "item_purchased")
	assert_signal_emitted(EventBus, "toast_requested", "a failure still tells the player why, via a toast")

## rpg.md section 11 backlog ("Panel trudności... ceny") — `cost` on the
## placed node is the medium baseline; the actual charge is
## Difficulty.scaled_price(cost, SettingsStore.difficulty).
func test_purchase_price_scales_with_difficulty() -> void:
	var real_difficulty := SettingsStore.difficulty
	SettingsStore.difficulty = "hard"
	ProgressStore.add_money(100)
	_machine.interact(null)
	var expected_price := Difficulty.scaled_price(_machine.cost, "hard")
	assert_eq(ProgressStore.money, 100 - expected_price)
	SettingsStore.difficulty = real_difficulty

## rpg.md section 11b backlog ("Sezonowe/dzienne promocje w automatach") —
## TimeManager.current_day 2/5 (Wed/Sat) knocks 20% off, applied on top of
## the difficulty multiplier already covered above.
func test_promo_day_discounts_the_price() -> void:
	var real_day := TimeManager.current_day
	TimeManager.current_day = 2
	ProgressStore.add_money(100)
	_machine.interact(null)
	var expected_price := maxi(0, roundi(Difficulty.scaled_price(_machine.cost, SettingsStore.difficulty) * VendingMachine.PROMO_DISCOUNT))
	assert_eq(ProgressStore.money, 100 - expected_price)
	TimeManager.current_day = real_day

func test_non_promo_day_charges_full_price() -> void:
	var real_day := TimeManager.current_day
	TimeManager.current_day = 0
	ProgressStore.add_money(100)
	_machine.interact(null)
	var expected_price := Difficulty.scaled_price(_machine.cost, SettingsStore.difficulty)
	assert_eq(ProgressStore.money, 100 - expected_price)
	TimeManager.current_day = real_day

func test_promo_badge_visibility_follows_the_day() -> void:
	var real_day := TimeManager.current_day
	TimeManager.current_day = 2
	assert_true(_machine._is_promo_active())
	TimeManager.current_day = 1
	assert_false(_machine._is_promo_active())
	TimeManager.current_day = real_day
