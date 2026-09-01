extends GutTest
## rpg.md section 11 backlog ("reakcje policji/reputacji").

var _system: PoliceReactionSystem


func before_each() -> void:
	_system = PoliceReactionSystem.new()
	_system.zone_id = "downtown"
	add_child_autofree(_system)


func test_no_warning_above_first_threshold() -> void:
	watch_signals(EventBus)
	EventBus.reputation_changed.emit("downtown", -5)
	assert_signal_not_emitted(EventBus, "toast_requested")


func test_warns_once_crossing_first_threshold() -> void:
	watch_signals(EventBus)
	EventBus.reputation_changed.emit("downtown", -15)
	assert_signal_emit_count(EventBus, "toast_requested", 1)


func test_does_not_repeat_warning_for_same_level() -> void:
	EventBus.reputation_changed.emit("downtown", -15)
	watch_signals(EventBus)
	EventBus.reputation_changed.emit("downtown", -16)
	assert_signal_not_emitted(EventBus, "toast_requested")


func test_warns_again_when_crossing_a_higher_threshold() -> void:
	EventBus.reputation_changed.emit("downtown", -15)
	watch_signals(EventBus)
	EventBus.reputation_changed.emit("downtown", -30)
	assert_signal_emit_count(EventBus, "toast_requested", 1)


func test_ignores_changes_in_other_zones() -> void:
	watch_signals(EventBus)
	EventBus.reputation_changed.emit("uptown", -50)
	assert_signal_not_emitted(EventBus, "toast_requested")
