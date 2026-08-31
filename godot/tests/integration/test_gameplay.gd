extends GutTest
## GUT port of the ad-hoc SmokeTest.gd from earlier in this migration session
## (see plan31-08.md) — same assertions, GUT conventions (assert_*,
## add_child_autofree, wait_seconds/wait_frames) instead of hand-rolled
## PASS/FAIL bookkeeping. Kept as one sequential test_full_gameplay_flow()
## rather than fully decomposed into independent per-behavior test methods —
## the state builds progressively (energy after movement, hop after
## squash-tween setup) and splitting it now would mean re-deriving that
## setup per test; a pragmatic middle ground, not the final shape. Still
## drives real Input events via Input.parse_input_event() — NOT
## Input.action_press(), which never reaches _unhandled_input() (verified
## before the original SmokeTest.gd was written).
##
## Run via GUT's CLI runner for CI:
##   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
## IMPORTANT: this test calls ProgressStore.reset_progress(), which writes
## the REAL user://progress.json — back it up before running outside of a
## disposable/CI environment and restore after (see plan31-08.md's
## "automatyczny smoke test" sections for why and how this session did it
## manually around every MCP-driven test run).

const Level2Scene := preload("res://scenes/levels/Level2.tscn")

var _level: Node
var _player: CharacterBody2D

func before_each() -> void:
	ProgressStore.reset_progress()
	_level = Level2Scene.instantiate()
	add_child_autofree(_level)
	await wait_physics_frames(2)
	_player = get_tree().get_first_node_in_group("player")

func _press_key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)

func _release_key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = false
	Input.parse_input_event(ev)

func test_full_gameplay_flow() -> void:
	assert_not_null(_player, "player should spawn in Level2")
	if _player == null:
		return

	# --- Energy: drains while sprinting, recovers while stopped ---
	var start_energy: float = _level._energy
	_press_key(KEY_D)
	_press_key(KEY_SHIFT)
	await wait_seconds(1.0)
	var drained_energy: float = _level._energy
	assert_lt(drained_energy, start_energy, "energy drains while sprinting")
	_release_key(KEY_D)
	_release_key(KEY_SHIFT)
	await wait_seconds(0.5) # let friction actually bring velocity to ~0
	var stopped_energy: float = _level._energy
	await wait_seconds(1.0)
	assert_gt(_level._energy, stopped_energy, "energy recovers while stopped")

	# --- Interaction ("Wciśnij E"): item ---
	var item := _level.get_node_or_null("Item_m1")
	assert_not_null(item, "Item_m1 node exists in built scene")
	if item != null:
		var target: Vector2 = item.global_position + Vector2(60, 0) # inside 100px interaction radius, outside item's own ~25px overlap box
		_player.global_position = target
		_player.velocity = Vector2.ZERO
		await wait_seconds(0.3)
		assert_true(is_instance_valid(item), "item NOT auto-collected by mere 60px proximity")
		_press_key(KEY_E)
		await wait_physics_frames(1)
		_release_key(KEY_E)
		await wait_seconds(0.2)
		assert_false(is_instance_valid(item), "pressing E collects the nearby item")

	# --- Interaction: NPC (talk + gift) ---
	var npc := _level.get_node_or_null("Npc_squirrel")
	assert_not_null(npc, "Npc_squirrel node exists in built scene")
	if npc != null:
		var target: Vector2 = npc.global_position + Vector2(65, 0) # outside NPC's own 40px half-extent
		_player.global_position = target
		_player.velocity = Vector2.ZERO
		await wait_seconds(0.3)
		_press_key(KEY_E)
		await wait_physics_frames(1)
		_release_key(KEY_E)
		await wait_seconds(0.2)
		assert_true(_level._talked.has("squirrel"), "pressing E near NPC marks it talked")
		assert_true(_level._collected_ids.has("squirrel-gift"), "talking to squirrel grants the yarn gift")

	# --- Sprint 3 juice: squash/stretch on hop ---
	var sprite := _player.get_node("Sprite2D") as AnimatedSprite2D
	var base_scale: Vector2 = sprite.scale
	_press_key(KEY_SPACE)
	await wait_physics_frames(1)
	_release_key(KEY_SPACE)
	await wait_seconds(0.08)
	assert_ne(sprite.scale, base_scale, "sprite scale changes during hop flight (squash/stretch active)")
	await wait_seconds(0.6)
	assert_almost_eq(sprite.scale.x, base_scale.x, 0.01, "sprite scale returns to base after hop lands")

	# --- Część 11: StatusEffectComponent (no in-game consumer, tests the public API directly) ---
	var status := _player.get_node("StatusEffects") as StatusEffectComponent
	status.apply_effect(StatusEffectComponent.EffectType.SPEED_BOOST, 0.25)
	assert_almost_eq(status.speed_multiplier, 1.5, 0.001, "SPEED_BOOST sets speed_multiplier to 1.5 immediately")
	await wait_seconds(0.35)
	assert_almost_eq(status.speed_multiplier, 1.0, 0.001, "SPEED_BOOST expires back to 1.0")

	_player.velocity = Vector2.ZERO
	_press_key(KEY_D)
	status.apply_effect(StatusEffectComponent.EffectType.PARALYSIS, 0.3)
	assert_true(status.paralyzed, "PARALYSIS sets paralyzed flag")
	await wait_seconds(0.15)
	assert_lt(_player.velocity.length(), 1.0, "held movement input produces no velocity while paralyzed")
	await wait_seconds(0.3)
	_release_key(KEY_D)
	assert_false(status.paralyzed, "PARALYSIS expires and clears the flag")

	# --- Część 12: DebugConsole hooks on LevelRuntime ---
	_level.debug_god_mode = true
	await wait_physics_frames(1)
	assert_almost_eq(_level._energy, Difficulty.MAX_ENERGY, 0.001, "debug_god_mode forces energy to max")
	_level.debug_god_mode = false

	_level.debug_give_item(&"star", 3)
	assert_eq(_level._debug_bonus_inventory.get(&"star", 0), 3, "debug_give_item records 3x star in the bonus inventory")

	# --- Player state machine (Idle/Walk/Sprint/Hop classifier) ---
	var sm := _player.get_node("StateMachine") as PlayerStateMachine
	_player.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	assert_eq(sm.current, PlayerStateMachine.StateName.IDLE, "state machine settles in IDLE when stationary")

	_press_key(KEY_D)
	await wait_seconds(0.3)
	assert_eq(sm.current, PlayerStateMachine.StateName.WALK, "state machine enters WALK on held movement input")

	_press_key(KEY_SHIFT)
	await wait_seconds(0.3)
	assert_eq(sm.current, PlayerStateMachine.StateName.SPRINT, "state machine enters SPRINT when sprint held while moving")

	var ghost_count := 0
	for child in _level.get_children():
		if child is Sprite2D:
			ghost_count += 1
	assert_gt(ghost_count, 0, "sprinting spawns at least one ghost-trail Sprite2D (found %d)" % ghost_count)

	_release_key(KEY_D)
	_release_key(KEY_SHIFT)
	await wait_seconds(0.3)
	_press_key(KEY_SPACE)
	await wait_physics_frames(1)
	_release_key(KEY_SPACE)
	await wait_physics_frames(1)
	assert_eq(sm.current, PlayerStateMachine.StateName.HOP, "state machine enters HOP while PlayerHop is active")
