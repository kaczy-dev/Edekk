extends GutTest
## rpg.md section 11b backlog ("Graffiti/ślady gracza") — GraffitiSpawner
## (ninth autoload), same shape of test as test_vfx_spawner.gd: pooled,
## round-robin, no per-hit allocation.

func before_each() -> void:
	# GraffitiSpawner is a persistent autoload — reset visibility/position
	# state left over from a previous test so each test starts clean.
	for mark in GraffitiSpawner._pool:
		mark.visible = false
	GraffitiSpawner._next_index = 0

func test_combat_trace_activates_a_pooled_mark_at_the_right_position() -> void:
	EventBus.combat_trace_requested.emit(Vector2(100, 200))
	var mark: Label = GraffitiSpawner._pool[0]
	assert_true(mark.visible)
	assert_eq(mark.global_position, Vector2(100, 200))

func test_marks_do_not_disappear_on_their_own() -> void:
	EventBus.combat_trace_requested.emit(Vector2(50, 50))
	await wait_seconds(0.5)
	assert_true(GraffitiSpawner._pool[0].visible, "unlike VfxSpawner's burst, a graffiti mark is meant to stay")

func test_pool_does_not_grow_past_max_marks() -> void:
	var initial_count := GraffitiSpawner.get_child_count()
	for i in range(GraffitiSpawner.MAX_MARKS + 15):
		EventBus.combat_trace_requested.emit(Vector2(i, i))
	assert_eq(GraffitiSpawner.get_child_count(), initial_count, "round-robin reuse, no new nodes created")

func test_pool_wraps_around_and_reuses_the_oldest_mark() -> void:
	for i in range(GraffitiSpawner.MAX_MARKS):
		EventBus.combat_trace_requested.emit(Vector2(i, 0))
	EventBus.combat_trace_requested.emit(Vector2(999, 999))
	assert_eq(GraffitiSpawner._pool[0].global_position, Vector2(999, 999), "the (MAX_MARKS+1)th trace should reuse slot 0")
