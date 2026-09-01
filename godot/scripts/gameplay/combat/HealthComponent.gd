class_name HealthComponent
extends Node
## Combat HP component per rpg.md section 3.3 — attached as a child to both
## Player.tscn and EnemyActor.tscn (feature/rpg-enemy), same component used
## twice rather than a shared Player/Enemy base class (composition over
## inheritance, matching StatusEffectComponent.gd already on Player.tscn).
##
## Deliberately dumb: no defense/armor math here (attack vs. defense
## resolution belongs to whatever calls take_damage() — feature/rpg-combat's
## hitbox handler — since only the caller knows both combatants' StatsData).
## This component only tracks HP and reports changes.

@export var max_hp: int = 10

var current_hp: int

signal health_changed(current: int, max: int)
signal died

func _ready() -> void:
	current_hp = max_hp

## Sets max_hp AND resets current_hp to it — needed instead of assigning
## `.max_hp` directly whenever the caller runs after this node's own
## _ready() (children ready before their parent in Godot, so e.g.
## EnemyActor._ready() setting `.max_hp` from EnemyData runs too late for
## this node's own _ready() to have picked it up — current_hp would stay at
## the exported default). Found the hard way: a HealthComponent configured
## this way in EnemyActor.gd silently started enemies at the *script
## default* max_hp (10) instead of their EnemyData value.
##
## Emits health_changed like take_damage() does — feature/rpg-hud relies on
## this to announce a full bar at spawn (EnemyActor connects its EventBus
## relay before calling configure(), see EnemyActor.gd).
func configure(new_max_hp: int) -> void:
	max_hp = new_max_hp
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)

func take_damage(amount: int) -> void:
	if current_hp <= 0 or amount <= 0:
		return
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		died.emit()

func is_dead() -> bool:
	return current_hp <= 0
