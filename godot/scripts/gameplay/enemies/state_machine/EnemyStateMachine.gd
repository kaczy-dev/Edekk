class_name EnemyStateMachine
extends Node
## rpg.md section 3.4 / 4 (feature/rpg-enemy + feature/rpg-combat) —
## Idle/Chase/Attack classified purely by distance to the player each
## physics frame, plus HURT/DEAD as forced transitions from EnemyActor's
## HealthComponent signals (force_hurt()/force_death()) — those two never
## come out of _classify(), since HP has no distance to measure.

enum StateName { IDLE, CHASE, ATTACK, HURT, DEAD }

const HURT_DURATION := 0.3

var current: StateName = StateName.IDLE

var _enemy: CharacterBody2D
var _data: EnemyData
var _states: Dictionary[StateName, EnemyState] = {}
var _hurt_remaining := 0.0

func setup(enemy: CharacterBody2D, data: EnemyData) -> void:
	_enemy = enemy
	_data = data
	_states = {
		StateName.IDLE: EnemyIdleState.new(),
		StateName.CHASE: EnemyChaseState.new(),
		StateName.ATTACK: EnemyAttackState.new(),
		StateName.HURT: EnemyHurtState.new(),
		StateName.DEAD: EnemyDeathState.new(),
	}
	for state in _states.values():
		state.enemy = enemy
		state.data = data
		add_child(state)
	_states[current].enter()

func physics_update(delta: float, player: Node2D) -> void:
	if current == StateName.DEAD:
		_states[current].physics_update(delta, player)
		return

	if current == StateName.HURT:
		_hurt_remaining -= delta
		_states[current].physics_update(delta, player)
		if _hurt_remaining <= 0.0:
			_states[current].exit()
			current = _classify(player)
			_states[current].enter()
		return

	var next := _classify(player)
	if next != current:
		_states[current].exit()
		current = next
		_states[current].enter()
	_states[current].physics_update(delta, player)

## Called by EnemyActor on HealthComponent.health_changed (while still
## alive) — interrupts whatever's running for a brief stun, then falls back
## to normal distance-based classification.
func force_hurt() -> void:
	if current == StateName.DEAD:
		return
	_states[current].exit()
	current = StateName.HURT
	_hurt_remaining = HURT_DURATION
	_states[current].enter()

## Called by EnemyActor on HealthComponent.died. Terminal — see
## EnemyDeathState.gd.
func force_death() -> void:
	if current == StateName.DEAD:
		return
	_states[current].exit()
	current = StateName.DEAD
	_states[current].enter()

func _classify(player: Node2D) -> StateName:
	if player == null:
		return StateName.IDLE
	var dist := _enemy.global_position.distance_to(player.global_position)
	if dist <= _data.attack_range:
		return StateName.ATTACK
	if dist <= _data.detect_radius:
		return StateName.CHASE
	return StateName.IDLE
