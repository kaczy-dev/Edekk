extends GutTest
## docs/ROADMAP.md section 12 / rpg.md section 8 (2026-08-31) — sticky
## interaction target (hysteresis) and buffered interact. Drives
## InteractionDetector's internals directly (populating `_candidates` and
## calling `_process(delta)`) rather than through real Area2D physics
## overlap — deterministic distances matter here, not whether Godot's
## physics actually reports an overlap, which test_gameplay.gd's
## overlap-driven interaction test already covers.

class FakeInteractable:
	extends Area2D
	var interact_count := 0
	func interact(_player: Node) -> void:
		interact_count += 1

class FakeFavoritable:
	extends Area2D
	var obj_id: String = "fake_1"
	var toggle_count := 0
	func interact(_player: Node) -> void:
		pass
	func get_favorite_label() -> String:
		return "Fake"

var _detector: InteractionDetector
var _player_stub: Node2D

func before_each() -> void:
	_player_stub = Node2D.new()
	add_child_autofree(_player_stub)

	_detector = InteractionDetector.new()
	_player_stub.add_child(_detector)
	_detector.global_position = Vector2.ZERO

func _make_candidate(distance: float) -> FakeInteractable:
	var c := FakeInteractable.new()
	add_child_autofree(c)
	c.global_position = Vector2(distance, 0)
	return c

func test_picks_the_only_candidate() -> void:
	var a := _make_candidate(50)
	_detector._candidates = [a]
	_detector._process(0.016)
	assert_eq(_detector._nearest, a)

func test_sticky_target_ignores_a_slightly_closer_candidate() -> void:
	var a := _make_candidate(100)
	_detector._candidates = [a]
	_detector._process(0.016)
	assert_eq(_detector._nearest, a)

	# b is closer (90 < 100) but not by the 15% margin (needs < 85) — a should stick.
	var b := _make_candidate(90)
	_detector._candidates = [a, b]
	_detector._process(0.016)
	assert_eq(_detector._nearest, a, "candidate must be >15%% closer to steal the target, not just closer")

func test_sticky_target_switches_once_a_candidate_is_clearly_closer() -> void:
	var a := _make_candidate(100)
	_detector._candidates = [a]
	_detector._process(0.016)

	var b := _make_candidate(70) # well under the 85-unit margin threshold
	_detector._candidates = [a, b]
	_detector._process(0.016)
	assert_eq(_detector._nearest, b, "a clearly closer candidate does take over")

func test_target_switches_when_current_nearest_leaves_range() -> void:
	var a := _make_candidate(50)
	_detector._candidates = [a]
	_detector._process(0.016)
	assert_eq(_detector._nearest, a)

	var b := _make_candidate(80)
	_detector._candidates = [b] # a exited range
	_detector._process(0.016)
	assert_eq(_detector._nearest, b, "the old target leaving range forces a switch even without a margin")

func test_buffered_interact_fires_once_a_target_appears_in_time() -> void:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	_detector._unhandled_input(ev) # nothing in range yet — buffers instead of dropping

	var a := _make_candidate(50)
	_detector._candidates = [a]
	_detector._process(0.05) # well within BUFFER_WINDOW (0.15s)

	assert_eq(a.interact_count, 1, "buffered interact fires the moment a target becomes nearest")

func test_buffered_interact_expires_after_the_window() -> void:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	_detector._unhandled_input(ev)

	_detector._process(0.2) # past BUFFER_WINDOW (0.15s), still nothing in range

	var a := _make_candidate(50)
	_detector._candidates = [a]
	_detector._process(0.016)

	assert_eq(a.interact_count, 0, "an expired buffer does not fire on a later, unrelated target appearance")

## rpg.md backlog ("Ulubione miejsca") — the "favorite" action emits
## EventBus.favorite_toggle_requested with the nearest target's obj_id/
## label when it exposes get_favorite_label(), duck-typed the same way
## `interact()` already is above.
func test_favorite_action_emits_bus_signal_for_a_favoritable_target() -> void:
	var a := FakeFavoritable.new()
	add_child_autofree(a)
	a.global_position = Vector2(20, 0)
	_detector._candidates = [a]
	_detector._process(0.016)

	var received := []
	var callback := func(obj_id: String, label: String) -> void:
		received.append([obj_id, label])
	EventBus.favorite_toggle_requested.connect(callback)

	var ev := InputEventAction.new()
	ev.action = &"favorite"
	ev.pressed = true
	_detector._unhandled_input(ev)

	EventBus.favorite_toggle_requested.disconnect(callback)
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], "fake_1")
	assert_eq(received[0][1], "Fake")

func test_favorite_action_is_ignored_for_a_plain_interactable() -> void:
	var a := _make_candidate(20)
	_detector._candidates = [a]
	_detector._process(0.016)

	var received := []
	var callback := func(obj_id: String, label: String) -> void:
		received.append([obj_id, label])
	EventBus.favorite_toggle_requested.connect(callback)

	var ev := InputEventAction.new()
	ev.action = &"favorite"
	ev.pressed = true
	_detector._unhandled_input(ev)

	EventBus.favorite_toggle_requested.disconnect(callback)
	assert_eq(received.size(), 0, "a target with no get_favorite_label() must not emit")

func test_favorite_action_is_ignored_when_nothing_is_nearest() -> void:
	var received := []
	var callback := func(obj_id: String, label: String) -> void:
		received.append([obj_id, label])
	EventBus.favorite_toggle_requested.connect(callback)

	var ev := InputEventAction.new()
	ev.action = &"favorite"
	ev.pressed = true
	_detector._unhandled_input(ev)

	EventBus.favorite_toggle_requested.disconnect(callback)
	assert_eq(received.size(), 0)
