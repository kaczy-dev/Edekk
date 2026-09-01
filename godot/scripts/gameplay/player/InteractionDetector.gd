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

## docs/ROADMAP.md section 12 ("Sterowanie — co konkretnie ulepszyć"),
## implemented rpg.md section 8 (2026-08-31):
## - Sticky target (hysteresis): once something is `_nearest`, a different
##   candidate only takes over once it's at least STICKY_MARGIN closer —
##   otherwise two similarly-distant candidates flicker the prompt/target
##   back and forth every frame as the player so much as breathes.
## - Buffered interact: pressing E up to BUFFER_WINDOW seconds before a
##   target actually becomes `_nearest` still fires — same forgiveness
##   pattern as PlayerHop.gd's jump-buffer, applied to interaction instead
##   of movement.
const STICKY_MARGIN := 0.15
const BUFFER_WINDOW := 0.15

var _candidates: Array[Area2D] = []
var _nearest: Area2D = null
var _buffer_remaining := 0.0


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
func _process(delta: float) -> void:
	_buffer_remaining = maxf(0.0, _buffer_remaining - delta)

	var closest: Area2D = null
	var closest_dist_sq := INF
	for area in _candidates:
		if not is_instance_valid(area):
			continue
		var d := global_position.distance_squared_to(area.global_position)
		if d < closest_dist_sq:
			closest_dist_sq = d
			closest = area

	var next := _apply_stickiness(closest, closest_dist_sq)
	if next != _nearest:
		_nearest = next
		nearest_changed.emit(_nearest)
		if _nearest != null and _buffer_remaining > 0.0:
			_nearest.interact(get_parent())
			_buffer_remaining = 0.0


## `closest`/`closest_dist_sq` is the geometrically nearest candidate this
## frame, computed above with no memory of last frame. This wraps that in
## hysteresis: if the CURRENT `_nearest` is still a valid candidate, it wins
## unless `closest` is closer by more than STICKY_MARGIN (squared, to match
## the squared distances everywhere else in this file — avoids a sqrt()).
func _apply_stickiness(closest: Area2D, closest_dist_sq: float) -> Area2D:
	if _nearest == null or not is_instance_valid(_nearest) or not _candidates.has(_nearest):
		return closest
	if closest == _nearest:
		return _nearest
	var current_dist_sq := global_position.distance_squared_to(_nearest.global_position)
	var margin_sq := current_dist_sq * (1.0 - STICKY_MARGIN) * (1.0 - STICKY_MARGIN)
	return closest if closest_dist_sq < margin_sq else _nearest


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _nearest != null:
			_nearest.interact(get_parent())
			get_viewport().set_input_as_handled()
		else:
			_buffer_remaining = BUFFER_WINDOW
		return
	if event.is_action_pressed("favorite"):
		_try_toggle_favorite()


## rpg.md backlog ("Ulubione miejsca") — duck-typed the same way `interact()`
## is above: a target is favoritable when it exposes `get_favorite_label()`
## AND carries a non-empty `obj_id` (the stable key ProgressStore bookmarks
## by — a target with no obj_id, e.g. a dev-placed VendingMachine that never
## set one, silently can't be favorited rather than erroring). No buffering
## like `interact` gets — favoriting isn't a twitch action worth forgiving a
## slightly-early press for.
func _try_toggle_favorite() -> void:
	if _nearest == null:
		return
	if not _nearest.has_method("get_favorite_label"):
		return
	if not ("obj_id" in _nearest) or _nearest.obj_id == "":
		return
	EventBus.favorite_toggle_requested.emit(_nearest.obj_id, _nearest.get_favorite_label())
	get_viewport().set_input_as_handled()
