extends GutTest
## rpg.md section 11 backlog ("losowe wydarzenia uliczne").

var _spawner: StreetEventSpawner


func before_each() -> void:
	_spawner = StreetEventSpawner.new()
	add_child_autofree(_spawner)


func test_starts_with_a_positive_timer_in_range() -> void:
	assert_between(
		_spawner._timer,
		StreetEventSpawner.MIN_INTERVAL_SECONDS,
		StreetEventSpawner.MAX_INTERVAL_SECONDS,
	)


func test_process_does_nothing_before_timer_elapses() -> void:
	_spawner._timer = 5.0
	watch_signals(EventBus)
	_spawner._process(0.016)
	assert_signal_not_emitted(EventBus, "toast_requested")


func test_process_emits_a_known_event_once_timer_elapses() -> void:
	_spawner._timer = 0.0
	watch_signals(EventBus)
	_spawner._process(0.016)
	assert_signal_emitted(EventBus, "toast_requested")
	var text: String = get_signal_parameters(EventBus, "toast_requested")[0]
	assert_true(StreetEventSpawner.EVENTS.has(text))


func test_process_rolls_a_fresh_timer_after_triggering() -> void:
	_spawner._timer = 0.0
	_spawner._process(0.016)
	assert_between(
		_spawner._timer,
		StreetEventSpawner.MIN_INTERVAL_SECONDS,
		StreetEventSpawner.MAX_INTERVAL_SECONDS,
	)
