class_name EnemyState
extends Node
## Base class for enemy states — rpg.md section 3.4. Mirrors PlayerState.gd's
## shape (see scripts/gameplay/player/state_machine/PlayerState.gd) but is a
## deliberately separate class, not a shared base with PlayerState: an enemy
## isn't a player, and forcing them under one hierarchy for a handful of
## shared method names would be inheritance for its own sake (rpg.md section
## 0, rule 2 — composition/small files, "understand the responsibility,
## don't 1:1 translate a template").
##
## Unlike PlayerState (an observability layer for Idle/Walk/Sprint, real
## authority only for Hop), every EnemyState here DOES own movement/velocity
## directly — there's no separate EnemyMovement.gd this needs to stay
## consistent with, since this is new code, not a mid-refactor split.

## Set by EnemyStateMachine right after instancing each state.
var enemy: CharacterBody2D
var data: EnemyData

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float, _player: Node2D) -> void:
	pass
