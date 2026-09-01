class_name AmbientVehicle
extends PathFollow2D
## rpg.md section 6 backlog ("Ruch uliczny / ambient AI") — a car looping
## along its parent Path2D's curve. Must be a direct child of a Path2D in
## the scene tree (PathFollow2D's normal usage) — `loop` is handled here via
## `fmod` against the curve's baked length rather than relying on
## Curve2D.closed, so an open (non-closed) curve still loops the car back
## to the start instead of stopping dead at the end.

@export var speed: float = 60.0 # px/sec along the path
@export var icon: String = "🚗"

func _ready() -> void:
	var label: Label = $IconLabel
	label.text = icon

func _physics_process(delta: float) -> void:
	var path := get_parent() as Path2D
	if path == null or path.curve == null:
		return
	var length := path.curve.get_baked_length()
	if length <= 0.0:
		return
	progress = fmod(progress + speed * delta, length)
