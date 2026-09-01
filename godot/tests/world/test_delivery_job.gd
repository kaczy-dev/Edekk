extends GutTest
## rpg.md backlog ("Tryb 'dostawa'") — DeliveryPickup.gd/DeliveryDropoff.gd,
## a job_id-paired courier pair. Redirects ProgressStore.save_path like
## test_vending_machine.gd — both nodes autosave via ProgressStore.

const PickupScene := preload("res://scenes/interactables/DeliveryPickup.tscn")
const DropoffScene := preload("res://scenes/interactables/DeliveryDropoff.tscn")
const TEST_SAVE_PATH := "user://test_progress_delivery_job.json"

var _real_save_path: String
var _pickup: DeliveryPickup
var _dropoff: DeliveryDropoff


func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH


func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func before_each() -> void:
	ProgressStore.reset_progress()
	_pickup = PickupScene.instantiate()
	_pickup.job_id = "job_1"
	add_child_autofree(_pickup)
	_dropoff = DropoffScene.instantiate()
	_dropoff.job_id = "job_1"
	_dropoff.reward_money = 30
	add_child_autofree(_dropoff)


func test_dropoff_without_pickup_fails() -> void:
	watch_signals(EventBus)
	_dropoff.interact(null)
	assert_eq(ProgressStore.money, 0)
	assert_signal_emitted(EventBus, "toast_requested")


func test_pickup_then_dropoff_pays_the_reward() -> void:
	_pickup.interact(null)
	assert_true(ProgressStore.is_carrying_parcel("job_1"))
	_dropoff.interact(null)
	assert_eq(ProgressStore.money, 30)
	assert_false(ProgressStore.is_carrying_parcel("job_1"))


func test_picking_up_twice_does_not_duplicate() -> void:
	_pickup.interact(null)
	_pickup.interact(null)
	assert_eq(ProgressStore.carrying_parcels.size(), 1)


func test_delivering_twice_pays_only_once() -> void:
	_pickup.interact(null)
	_dropoff.interact(null)
	var money_after_first_delivery := ProgressStore.money
	_dropoff.interact(null)
	assert_eq(ProgressStore.money, money_after_first_delivery, "no parcel left to deliver again")


func test_different_job_ids_do_not_interfere() -> void:
	var other_dropoff := DropoffScene.instantiate()
	other_dropoff.job_id = "job_2"
	add_child_autofree(other_dropoff)

	_pickup.interact(null) # picks up job_1
	other_dropoff.interact(null) # job_2 was never picked up
	assert_eq(ProgressStore.money, 0)
	assert_true(ProgressStore.is_carrying_parcel("job_1"))
