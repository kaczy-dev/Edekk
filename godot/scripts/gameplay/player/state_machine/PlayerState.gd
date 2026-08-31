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

## No-op in Idle/Walk/Sprint — PlayerMovement.gd still owns their
## accel/friction/drift (see PlayerStateMachine.gd's file header). Overridden
## by PlayerHopState, which DOES write `player.velocity` here (branch
## migration/player-physics). Reserved on the other three for a future pass
## that moves their movement math into states too.
func physics_update(_delta: float) -> void:
	pass
