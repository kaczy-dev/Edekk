extends Node2D
## rpg.md section 11b backlog ("Graffiti/ślady gracza w miejscach walk/
## automatów") — ninth autoload, same reasoning as VfxSpawner (seventh):
## catches EventBus.combat_trace_requested regardless of which level is
## active. Unlike VfxSpawner's pool this one does NOT fade — a scorch mark
## is meant to stay, that's the whole point ("to moje miasto", not "this
## flashed for a second"). Session-only (not part of ProgressStore's save) —
## a persistent-across-restarts version would need per-level world-position
## data, real scope, not the "cheap atmosphere accent" this backlog item
## asked for.
##
## Fixed pool + round-robin reuse (same trade-off VfxSpawner documents) is
## still the right call even for a "permanent" mark: without a cap, a very
## long play session grinding one spot would grow this node's children
## without bound. MAX_MARKS (30) is generous for a single sitting; the
## oldest mark quietly getting reused once a session runs long enough to
## saturate it is an acceptable trade for that bound existing at all.

const MAX_MARKS := 30
const MARK_EMOJI := "💢"
const MARK_SCALE := 0.6
const MARK_ALPHA := 0.65

var _pool: Array[Label] = []
var _next_index := 0

func _ready() -> void:
	for i in range(MAX_MARKS):
		var mark := Label.new()
		mark.text = MARK_EMOJI
		mark.visible = false
		mark.modulate = Color(1, 1, 1, MARK_ALPHA)
		mark.scale = Vector2(MARK_SCALE, MARK_SCALE)
		mark.pivot_offset = Vector2(16, 16) # approximate glyph center, matches HUD.CompassArrow's own guess
		add_child(mark)
		_pool.append(mark)
	EventBus.combat_trace_requested.connect(_on_combat_trace_requested)

func _on_combat_trace_requested(world_position: Vector2) -> void:
	var mark := _pool[_next_index]
	_next_index = (_next_index + 1) % MAX_MARKS
	# Rotation set BEFORE global_position: with a non-zero pivot_offset,
	# Control's transform origin shifts with rotation (origin = position +
	# pivot - rotate(pivot)) — assigning global_position last guarantees the
	# mark actually lands exactly at `world_position` regardless of the
	# random tilt.
	mark.rotation = randf_range(-0.3, 0.3) # slight scatter so a cluster of marks doesn't look stamped
	mark.global_position = world_position
	mark.visible = true
