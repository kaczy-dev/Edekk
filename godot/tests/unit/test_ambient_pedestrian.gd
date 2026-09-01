extends GutTest
## rpg.md section 6 backlog ("Ruch uliczny / ambient AI"). Forces the
## private `_timer`/`state` fields directly to make the randomized wander
## FSM deterministic for testing — same approach this session already used
## for EnemyStateMachine/InteractionDetector's internals.

const AmbientPedestrianScene := preload("res://scenes/ambient/AmbientPedestrian.tscn")

var _pedestrian: AmbientPedestrian


func before_each() -> void:
	_pedestrian = AmbientPedestrianScene.instantiate()
	add_child_autofree(_pedestrian)
	_pedestrian.global_position = Vector2(500, 500) # away from origin (0,0) to catch accidental resets


func test_starts_idle_with_timer_in_range() -> void:
	assert_eq(_pedestrian.state, AmbientPedestrian.State.IDLE)
	assert_between(_pedestrian._timer, _pedestrian.min_idle_seconds, _pedestrian.max_idle_seconds)


func test_idle_transitions_to_walk_once_timer_elapses() -> void:
	_pedestrian._timer = 0.01
	_pedestrian._physics_process(0.016)
	assert_eq(_pedestrian.state, AmbientPedestrian.State.WALK)


func test_walk_target_is_within_wander_radius_of_spawn_origin() -> void:
	_pedestrian._timer = 0.0
	_pedestrian._physics_process(0.016) # enters WALK, picks _target
	var distance_from_origin: float = _pedestrian._target.distance_to(_pedestrian._origin)
	assert_lte(distance_from_origin, _pedestrian.wander_radius)


func test_walk_moves_toward_the_target() -> void:
	_pedestrian._timer = 0.0
	_pedestrian._physics_process(0.016) # enters WALK
	_pedestrian._target = _pedestrian.global_position + Vector2(100, 0)
	_pedestrian._physics_process(0.016)
	assert_gt(_pedestrian.velocity.x, 0.0, "walks toward a target to its right")


func test_arriving_at_target_returns_to_idle() -> void:
	_pedestrian._timer = 0.0
	_pedestrian._physics_process(0.016) # enters WALK
	_pedestrian._target = _pedestrian.global_position # already "arrived"
	_pedestrian._physics_process(0.016)
	assert_eq(_pedestrian.state, AmbientPedestrian.State.IDLE)


func test_gossip_chance_zero_never_shows_a_line() -> void:
	_pedestrian.gossip_chance = 0.0
	_pedestrian._enter_idle()
	assert_eq(_pedestrian._gossip_label.modulate.a, 0.0, "no gossip started, label stays invisible")


func test_gossip_chance_one_always_picks_a_known_line() -> void:
	_pedestrian.gossip_chance = 1.0
	_pedestrian._enter_idle()
	assert_true(AmbientPedestrian.GOSSIP_LINES.has(_pedestrian._gossip_label.text))
