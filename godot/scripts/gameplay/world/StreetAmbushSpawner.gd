class_name StreetAmbushSpawner
extends Node
## rpg.md backlog ("Rozbudowa combat/eksploracji... Losowe potyczki uliczne
## (zależne od pory dnia/reputacji), nie tylko zaplanowane na poziomie") —
## a standalone Node (not an autoload, "used sparingly" rule from
## god/godot2.md), same shape as StreetEventSpawner.gd (random timer,
## droppable into any level) but spawns a real EnemyActor instead of a
## flavor toast. Gated the same way PoliceReactionSystem.gd reads
## reputation — `zone_id` export, `ProgressStore.get_reputation(zone_id)` —
## plus `TimeManager.is_night()`, matching the backlog wording exactly
## ("zależne od pory dnia/reputacji").
##
## Deliberately one ambush at a time: a second roll while `_active_enemy`
## is still alive is skipped rather than queued/stacked — this is meant to
## occasionally punish wandering a bad zone at night, not flood the screen
## with enemies. `_active_enemy` is cleared via `tree_exited` (fires once
## the enemy's death animation finishes and queue_free() actually runs, not
## on the `died` HealthComponent signal, which still has the animation left
## to play — see EnemyActor.gd's own comment on that ordering).

const EnemyActorScene := preload("res://scenes/enemies/EnemyActor.tscn")

const MIN_INTERVAL_SECONDS := 90.0
const MAX_INTERVAL_SECONDS := 240.0
## Same first-crossed threshold PoliceReactionSystem.gd uses for its
## mildest "policja obserwuje" warning — reused here as "dangerous enough
## for street ambushes", not a new balancing number invented from scratch.
const REPUTATION_THRESHOLD := -15
const SPAWN_DISTANCE := 220.0

@export var zone_id: String = ""
@export var enemy_ids: Array[StringName] = [&"thug", &"bandit"]

var _timer: float = 0.0
var _active_enemy: EnemyActor = null
var _enemy_data: Dictionary = { }


func _ready() -> void:
	_enemy_data = EnemyRegistry.load_all()
	_roll_next_interval()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_roll_next_interval()
		if _can_ambush():
			_spawn_ambush()


func _roll_next_interval() -> void:
	_timer = randf_range(MIN_INTERVAL_SECONDS, MAX_INTERVAL_SECONDS)


func _can_ambush() -> bool:
	if is_instance_valid(_active_enemy):
		return false
	if not TimeManager.is_night():
		return false
	return ProgressStore.get_reputation(zone_id) <= REPUTATION_THRESHOLD


func _spawn_ambush() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or enemy_ids.is_empty():
		return
	var enemy_id: StringName = enemy_ids[randi() % enemy_ids.size()]
	var data: EnemyData = _enemy_data.get(enemy_id)
	if data == null:
		push_warning("StreetAmbushSpawner: enemy '%s' not found in EnemyRegistry" % enemy_id)
		return

	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * SPAWN_DISTANCE
	var enemy := EnemyActorScene.instantiate() as EnemyActor
	enemy.name = "StreetAmbush_%d" % Time.get_ticks_msec()
	enemy.global_position = player.global_position + offset
	enemy.enemy_data = data
	get_parent().add_child(enemy)
	enemy.tree_exited.connect(_on_active_enemy_gone)
	_active_enemy = enemy

	EventBus.toast_requested.emit("Ktoś rusza w twoją stronę z cienia!")


func _on_active_enemy_gone() -> void:
	_active_enemy = null
