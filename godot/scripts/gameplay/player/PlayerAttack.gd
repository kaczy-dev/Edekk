class_name PlayerAttack
extends Node
## Player attack timing — rpg.md section 4, feature/rpg-combat. Same shape as
## PlayerHop.gd: a pure timing/logic component PlayerMovement.gd calls once
## per physics frame, exposing signals for the visual layer (PlayerVisuals)
## and the hit-detection layer (PlayerHitbox) to react to, rather than
## touching the sprite or Area2D itself.
##
## No hop-style "buffer/coyote" input forgiveness here — attacks are a
## simpler primary action with no analogous "was already moving" edge case
## to smooth over; a straightforward just_pressed + cooldown gate is the
## right amount of complexity for the first cut.

signal attack_started
## Fired once, mid-swing, when the hitbox should actually check for hits —
## see PlayerHitbox.apply_hits(), connected to this from PlayerMovement.
signal attack_hit_window_started
signal attack_ended

const DURATION := 0.35 # seconds, total animation-equivalent lock
const HIT_WINDOW_AT := 0.15 # seconds into the swing when the hit registers
const COOLDOWN := 0.25 # after the swing ends, before the next can start

var _cooldown_remaining := 0.0
var _active_remaining := 0.0
var _hit_window_fired := false

func update(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	if Input.is_action_just_pressed("attack") and _can_start():
		_start()

	if _active_remaining <= 0.0:
		return

	_active_remaining -= delta
	var elapsed := DURATION - _active_remaining
	if not _hit_window_fired and elapsed >= HIT_WINDOW_AT:
		_hit_window_fired = true
		attack_hit_window_started.emit()

	if _active_remaining <= 0.0:
		_cooldown_remaining = COOLDOWN
		attack_ended.emit()

## Read by PlayerStateMachine's classifier — same role as PlayerHop.is_active().
func is_active() -> bool:
	return _active_remaining > 0.0

func _can_start() -> bool:
	return _cooldown_remaining <= 0.0 and _active_remaining <= 0.0

func _start() -> void:
	_active_remaining = DURATION
	_hit_window_fired = false
	AudioService.play_swing()
	attack_started.emit()
