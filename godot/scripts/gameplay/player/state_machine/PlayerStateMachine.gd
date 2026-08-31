class_name PlayerStateMachine
extends Node
## plan31-08.md's "Rozszerzona Maszyna Stanów" section, adapted to actually
## fit this game rather than following the spec's generic
## Idle/Run/Jump/Fall template verbatim (this is a top-down cat game with no
## gravity axis — Jump/Fall describe a platformer, and this project's
## conventions elsewhere (Hop mechanics ported from Phaser, not a literal
## re-templating — see god/godot2.md) already establish "understand the
## responsibility, don't 1:1 translate a template" as the house style).
## States here are Idle/Walk/Sprint/Hop, matching what PlayerMovement.gd
## already computes.
##
## UPDATE (branch migration/player-physics, plan31-08.md "principal lead"
## follow-up #4): PlayerHopState.physics_update() now DOES own the Hop
## velocity write — see PlayerHopState.gd — scoped to just the Hop state
## (the most isolated one, per the user's own recommendation for this
## follow-up). Walk/Sprint/Idle's accel/friction/drift/lean stay in
## PlayerMovement.gd for now; this remains an observability layer for those
## three, real physics authority for Hop. GUT's 37 assertions (incl. the
## HOP-classification test in test_gameplay.gd) passed unchanged before and
## after this change; a full manual retest of hop feel in the editor is
## still required before merge (see plan31-08.md's original caution about
## this exact refactor — no input-simulation/screenshot tool exists to
## visually re-verify a rewrite, only assertions on state/velocity values).

enum StateName { IDLE, WALK, SPRINT, HOP }

## Anim-move threshold duplicated from PlayerMovement.gd's own
## ANIM_MOVE_THRESHOLD (that constant isn't reachable from here —
## PlayerMovement.gd has no class_name, only a scene-attached script — and
## adding one purely to share one float wasn't worth the surface-area
## increase on the tested movement script for this).
const MOVE_THRESHOLD := 5.0

var current: StateName = StateName.IDLE

var _player: CharacterBody2D
var _hop: PlayerHop
var _states: Dictionary[StateName, PlayerState] = {}

func setup(player: CharacterBody2D, hop: PlayerHop) -> void:
	_player = player
	_hop = hop
	_states = {
		StateName.IDLE: PlayerIdleState.new(),
		StateName.WALK: PlayerWalkState.new(),
		StateName.SPRINT: PlayerSprintState.new(),
		StateName.HOP: PlayerHopState.new(),
	}
	for state in _states.values():
		state.player = player
		add_child(state)
	_states[current].enter()

## Called from PlayerMovement._physics_process(). `hop_velocity` is this
## frame's return value from PlayerHop.update() (null when no hop is
## active/starting this frame, a Vector2 velocity override otherwise) —
## passed in rather than re-read via `_hop.is_active()` so classification
## and PlayerHopState's velocity write both agree on the exact same value,
## with no risk of PlayerHop's internal timer ticking a second time or
## disagreeing between two separate reads in the same frame.
##
## For Walk/Sprint/Idle, PlayerMovement has already written `_player.
## velocity` for this frame (ground accel/friction/drift) BEFORE calling
## this — classification reads that result, same as before this change. For
## HOP, PlayerMovement has NOT written velocity yet — that happens below,
## inside `_states[StateName.HOP].physics_update()`, after transitioning.
func physics_update(delta: float, hop_velocity: Variant = null) -> void:
	var next := _classify(hop_velocity)
	if next != current:
		_states[current].exit()
		current = next
		_states[current].enter()
	if current == StateName.HOP:
		(_states[current] as PlayerHopState).hop_velocity = hop_velocity
	_states[current].physics_update(delta)

func _classify(hop_velocity: Variant) -> StateName:
	if hop_velocity != null:
		return StateName.HOP
	if _player.velocity.length() < MOVE_THRESHOLD:
		return StateName.IDLE
	return StateName.SPRINT if _player.is_sprinting else StateName.WALK
