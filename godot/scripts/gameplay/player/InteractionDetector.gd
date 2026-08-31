class_name InteractionDetector
extends Area2D
## Proximity-based interaction — the "press E" alternative to walking
## directly into an item/NPC's overlap area (see docs/migration/
## MIGRATION_MATRIX.md, "Naciśnij E" / plan31-08.md "Część 4"). Attached to
## Player.tscn's `InteractionArea` node (a 100px-radius CircleShape2D,
## present since the first player-movement slice but inert until now).
##
## Tracks every Area2D in range that implements `interact(player)` (duck-
## typed via `has_method`, not an interface — ItemPickup/NpcActor both grew
## `interact()` alongside this; GoalArea deliberately did not, see below),
## picks the nearest each frame, and emits `nearest_changed` so LevelRuntime
## can show/hide a HUD prompt. Overlap-triggered collection/talk (the
## original, tested interaction path) is untouched — this is additive, not
## a replacement.
##
## GoalArea is NOT interactable via this detector on purpose: "press E from
## 100px away to complete a reach quest" would let a player skip actually
## walking into the goal area, changing the puzzle from "get here" to "get
## within 100px", which the Phaser source never allowed. Only ItemPickup and
## NpcActor implement interact().

signal nearest_changed(target: Node2D)

var _candidates: Array[Area2D] = []
var _nearest: Area2D = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("interact"):
		_candidates.append(area)

func _on_area_exited(area: Area2D) -> void:
	_candidates.erase(area)

## Recomputed every frame rather than only on enter/exit — cheap (at most a
## couple of candidates in range on any ported level) and correctly handles
## a patrolling NPC changing distance, or two candidates both in range at
## once, without extra state tracking.
func _process(_delta: float) -> void:
	var closest: Area2D = null
	var best_dist_sq := INF
	for area in _candidates:
		if not is_instance_valid(area):
			continue
		var d := global_position.distance_squared_to(area.global_position)
		if d < best_dist_sq:
			best_dist_sq = d
			closest = area
	if closest != _nearest:
		_nearest = closest
		nearest_changed.emit(_nearest)

func _unhandled_input(event: InputEvent) -> void:
	if _nearest == null:
		return
	if event.is_action_pressed("interact"):
		_nearest.interact(get_parent())
		get_viewport().set_input_as_handled()
