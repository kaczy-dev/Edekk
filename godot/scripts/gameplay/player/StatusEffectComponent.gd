class_name StatusEffectComponent
extends Node
## Modular status-effect component per plan31-08.md "Część 11" — attached to
## Player.tscn as `StatusEffects`. Zero consumers today: no ported level has
## a water/food/danger trigger object that would call apply_effect() (see
## MIGRATION_MATRIX.md's danger-trigger row — data exists, no object kind
## builds one yet). Built anyway on explicit request, kept intentionally
## simple until a real consumer states actual requirements.
##
## Only ONE effect active at a time — applying a new one replaces whatever
## was running, no stacking/priority resolution. Building elaborate
## multi-effect resolution for a system nothing calls yet would be guessing
## at requirements; this is the smallest version that satisfies "a
## modular component PlayerMovement reads a multiplier/flag from", not a
## complete status-effect framework.

enum EffectType { SPEED_BOOST, SLOW, PARALYSIS }

const SPEED_BOOST_MULTIPLIER := 1.5
const SLOW_MULTIPLIER := 0.5

## Read by PlayerMovement.gd each physics frame to scale WALK_SPEED/RUN_SPEED.
var speed_multiplier: float = 1.0
## Read by PlayerMovement.gd to zero out input entirely while true.
var paralyzed: bool = false

## -1 (no EffectType value) means "no effect active" — kept as a plain int
## rather than EffectType since -1 isn't a member of the enum.
var _active_type: int = -1
var _timer: SceneTreeTimer

func apply_effect(type: EffectType, duration: float) -> void:
	_clear_current()
	_active_type = type
	match type:
		EffectType.SPEED_BOOST:
			speed_multiplier = SPEED_BOOST_MULTIPLIER
		EffectType.SLOW:
			speed_multiplier = SLOW_MULTIPLIER
		EffectType.PARALYSIS:
			paralyzed = true
	_timer = get_tree().create_timer(duration)
	_timer.timeout.connect(_on_expired)

func _clear_current() -> void:
	if _timer != null and _timer.timeout.is_connected(_on_expired):
		_timer.timeout.disconnect(_on_expired)
	speed_multiplier = 1.0
	paralyzed = false

func _on_expired() -> void:
	speed_multiplier = 1.0
	paralyzed = false
	_active_type = -1
