class_name PlayerState
extends Node
## Base class for player states — plan31-08.md's State Machine section. See
## PlayerStateMachine.gd for why this classifies already-computed movement
## (an observability layer) rather than driving physics itself.

## Set by PlayerStateMachine right after instancing each state, before any
## enter()/exit()/physics_update() call.
var player: CharacterBody2D

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

## Currently a no-op in every concrete state (PlayerMovement.gd stays the
## physics authority — see PlayerStateMachine.gd). Reserved for a future
## pass that actually moves movement math into states, or per-state
## animation/sound/VFX triggers, without changing this base class's shape.
func physics_update(_delta: float) -> void:
	pass
