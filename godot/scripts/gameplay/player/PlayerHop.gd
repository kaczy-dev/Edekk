class_name PlayerHop
extends Node
## Hop (Space) — ported from LevelScene.ts hop* methods. See
## docs/migration/GAMEPLAY_BEHAVIOR.md, section "Hop (Space)".
##
## Pure state/logic component: it does not touch the CharacterBody2D or
## move_and_slide() itself. PlayerMovement.gd calls update() once per physics
## frame, before applying its own velocity, and uses the returned override
## (or falls back to normal movement when null). This keeps ordering
## explicit instead of relying on Godot's child-node process order.
##
## NOT yet ported (visual only, no camera/dust hooks wired up): squash
## anticipation, paw dust, camera shake on landing — hop_started/hop_landed
## are emitted so those can attach later without touching this file.

signal hop_started(direction: Vector2)
signal hop_landed

const DURATION := 0.32 # seconds
const SPEED := 361.0 # RUN_SPEED * 0.95
const ARC_HEIGHT := 22.0 # px, visual sprite offset only
const BUFFER_WINDOW := 0.15 # jump buffering: press up to 150ms early
const COYOTE_WINDOW := 0.12 # coyote time: direction up to 120ms stale still counts
const COOLDOWN := 0.26 # after landing, before the next hop can start

var _cooldown_remaining := 0.0
var _buffer_remaining := 0.0
var _active_remaining := 0.0
var _time_since_moving := 999.0
var _facing := Vector2.DOWN
var _last_hop_direction := Vector2.ZERO
var _hop_direction := Vector2.ZERO

## Call once per physics frame. Returns the velocity to apply this frame
## while a hop is active, or null when the caller should compute its own
## (normal walk/sprint) velocity instead.
func update(delta: float, input_dir: Vector2) -> Variant:
	if input_dir != Vector2.ZERO:
		_facing = input_dir.normalized()
		_time_since_moving = 0.0
	else:
		_time_since_moving += delta

	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	_buffer_remaining = maxf(0.0, _buffer_remaining - delta)

	if Input.is_action_just_pressed("hop"):
		if _can_start():
			_start(input_dir)
		else:
			_buffer_remaining = BUFFER_WINDOW

	if _buffer_remaining > 0.0 and _can_start():
		_start(input_dir)
		_buffer_remaining = 0.0

	if _active_remaining <= 0.0:
		return null

	_active_remaining -= delta
	if _active_remaining <= 0.0:
		_cooldown_remaining = COOLDOWN
		hop_landed.emit()
		return null

	return _hop_direction * SPEED

## Read-only: true while a hop is actively overriding movement this frame.
## Added for PlayerStateMachine.gd's classifier — doesn't affect update()'s
## own logic at all, just exposes the same condition update() already
## checks internally (`_active_remaining <= 0.0`).
func is_active() -> bool:
	return _active_remaining > 0.0

## 0 at launch/landing, 1 at the peak of the arc. Drive a sprite's visual
## y-offset with this (e.g. `sprite.position.y = -hop.arc_progress() * PlayerHop.ARC_HEIGHT`).
func arc_progress() -> float:
	if _active_remaining <= 0.0:
		return 0.0
	var t := 1.0 - (_active_remaining / DURATION)
	return sin(t * PI)

func _can_start() -> bool:
	return _cooldown_remaining <= 0.0 and _active_remaining <= 0.0

func _start(input_dir: Vector2) -> void:
	var dir := input_dir
	if dir == Vector2.ZERO:
		dir = _last_hop_direction if (_time_since_moving <= COYOTE_WINDOW and _last_hop_direction != Vector2.ZERO) else _facing
	dir = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	_hop_direction = dir
	_last_hop_direction = dir
	_active_remaining = DURATION
	hop_started.emit(dir)
