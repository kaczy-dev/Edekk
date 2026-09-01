class_name EnemyActor
extends CharacterBody2D
## rpg.md section 3.2/3.4, feature/rpg-enemy. Reads EnemyData the same way
## ItemPickup reads ItemData — @export'ed resource, no other wiring needed
## to spawn a new enemy type once its .tres exists (data/enemies/*.tres).

@export var enemy_data: EnemyData

@onready var _sprite: AnimatedSprite2D = $Sprite2D
@onready var _health: HealthComponent = $HealthComponent
@onready var _state_machine: EnemyStateMachine = $StateMachine

func _ready() -> void:
	if enemy_data == null:
		push_warning("EnemyActor: no enemy_data assigned, staying inert")
		return
	_sprite.sprite_frames = enemy_data.sprite_frames
	_sprite.scale = enemy_data.sprite_scale
	var hitbox: EnemyHitbox = $Hitbox
	hitbox.attack_damage = enemy_data.stats.attack
	(get_node("EnemyHealthBar") as HealthBar).enemy_id = name

	# Connected BEFORE configure() so its emit reaches both relays below —
	# announces the starting HP (a health bar should show full, not empty,
	# at spawn) via the same path a real hit takes.
	_health.health_changed.connect(_on_health_changed)
	_health.health_changed.connect(func(current: int, max_hp: int) -> void: EventBus.enemy_damaged.emit(name, current, max_hp))
	_health.died.connect(_state_machine.force_death)
	_health.died.connect(func() -> void: EventBus.enemy_died.emit(name))
	# rpg.md section 11b backlog ("Graffiti/ślady gracza") — captured here,
	# not from inside GraffitiSpawner reading the (about to be freed)
	# EnemyActor later, since the death animation still plays for a moment
	# after this signal (see EnemyDeathState) before queue_free() actually
	# removes the node.
	_health.died.connect(func() -> void: EventBus.combat_trace_requested.emit(global_position))
	_health.configure(enemy_data.stats.max_hp)

	_state_machine.setup(self, enemy_data)

## Only stuns on damage taken, not on the initial full-HP announcement that
## configure() itself fires (current == max — see _ready(), that emit exists
## purely so EventBus.enemy_damaged relays a full bar at spawn, not real
## damage) and not on a hypothetical future heal (this component has no heal
## path today — HealthComponent.take_damage() only decreases current_hp).
## The current == 0 case is handled by `died` above instead (force_death(),
## not force_hurt() — DEAD wins if both signals fire this same
## take_damage() call, since force_hurt() bails out when current is already
## DEAD... but died fires AFTER health_changed in HealthComponent, so the
## guard here matters: without it, a killing blow would enter HURT for one
## frame before force_death() immediately overrides it).
func _on_health_changed(current: int, max_hp: int) -> void:
	if current > 0 and current < max_hp:
		_state_machine.force_hurt()

func _physics_process(delta: float) -> void:
	if enemy_data == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_state_machine.physics_update(delta, player)
