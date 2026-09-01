extends GutTest
## rpg.md backlog ("Kryjówki/skróty odblokowywane po pokonaniu wroga lub
## zapłacie") — ShortcutGate.gd. Redirects ProgressStore.save_path like
## test_vending_machine.gd (interact() -> spend_money()/unlock_shortcut()
## both autosave).

const ShortcutGateScene := preload("res://scenes/interactables/ShortcutGate.tscn")
const TEST_SAVE_PATH := "user://test_progress_shortcut_gate.json"

var _real_save_path: String
var _gate: ShortcutGate


func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH


func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func before_each() -> void:
	ProgressStore.reset_progress()


func _spawn(gate_id: String, cost: int, required_enemy_id: String = "") -> ShortcutGate:
	var gate := ShortcutGateScene.instantiate() as ShortcutGate
	gate.gate_id = gate_id
	gate.unlock_cost = cost
	gate.required_enemy_id = required_enemy_id
	add_child_autofree(gate)
	return gate


func test_locked_gate_blocks_the_passage() -> void:
	_gate = _spawn("gate_1", 20)
	var blocker: CollisionShape2D = _gate.get_node("Blocker/CollisionShape2D")
	assert_false(blocker.disabled)


func test_interact_without_enough_money_does_nothing() -> void:
	_gate = _spawn("gate_1", 20)
	watch_signals(EventBus)
	_gate.interact(null)
	assert_false(ProgressStore.is_shortcut_unlocked("gate_1"))
	assert_signal_emitted(EventBus, "toast_requested")


func test_interact_with_enough_money_unlocks_and_disables_blocker() -> void:
	_gate = _spawn("gate_1", 20)
	ProgressStore.add_money(20)
	_gate.interact(null)
	await get_tree().process_frame
	assert_true(ProgressStore.is_shortcut_unlocked("gate_1"))
	assert_eq(ProgressStore.money, 0)
	var blocker: CollisionShape2D = _gate.get_node("Blocker/CollisionShape2D")
	assert_true(blocker.disabled)


func test_defeating_required_enemy_unlocks_for_free() -> void:
	_gate = _spawn("gate_2", 20, "thug")
	EventBus.enemy_died.emit("thug")
	ProgressStore.add_money(0)
	_gate.interact(null)
	assert_true(ProgressStore.is_shortcut_unlocked("gate_2"))
	assert_eq(ProgressStore.money, 0, "the enemy-defeat path never spends money")


func test_unrelated_enemy_death_does_not_unlock() -> void:
	_gate = _spawn("gate_3", 20, "thug")
	EventBus.enemy_died.emit("bandit")
	_gate.interact(null)
	assert_false(ProgressStore.is_shortcut_unlocked("gate_3"))


func test_already_unlocked_gate_starts_open_on_ready() -> void:
	ProgressStore.unlock_shortcut("gate_4")
	_gate = _spawn("gate_4", 20)
	await get_tree().process_frame
	var blocker: CollisionShape2D = _gate.get_node("Blocker/CollisionShape2D")
	assert_true(blocker.disabled)


func test_interacting_with_an_already_unlocked_gate_is_a_no_op() -> void:
	ProgressStore.unlock_shortcut("gate_5")
	_gate = _spawn("gate_5", 20)
	ProgressStore.add_money(20)
	_gate.interact(null)
	assert_eq(ProgressStore.money, 20, "already-unlocked gates never charge again")
