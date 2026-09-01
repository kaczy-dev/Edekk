class_name TouchJoystick
extends Control
## rpg.md section 8 (2026-08-31) — on-screen joystick driving the SAME
## move_left/right/up/down InputMap actions the keyboard/gamepad already
## use, via Input.action_press(action, strength)/action_release(action).
## Zero new movement logic: PlayerMovement.gd's
## Input.get_vector("move_left", "move_right", "move_up", "move_down") call
## combines whichever input source is currently pressed, keyboard/pad/touch
## alike — this node never touches PlayerMovement.gd.
##
## Handles both real touch (InputEventScreenTouch/Drag) and mouse
## (InputEventMouseButton/MouseMotion) — mouse support isn't for players,
## it's so this can be manually verified in the editor without touch
## hardware or enabling Project Settings' "Emulate Touch From Mouse".

@export var radius: float = 64.0 # matches joystick_circle_pad_a.png's 128px diameter

@onready var _pad: TextureRect = $Pad
@onready var _nub: TextureRect = $Pad/Nub

## -1 = inactive, -2 = mouse (pseudo touch id), >=0 = real InputEventScreenTouch.index
var _active_pointer: int = -1
var _nub_center: Vector2

func _ready() -> void:
	_nub_center = _nub.position

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_pointer == -1 and _pad.get_global_rect().has_point(event.position):
				_active_pointer = event.index
				_update(event.position)
		elif event.index == _active_pointer:
			_active_pointer = -1
			_reset()
	elif event is InputEventScreenDrag:
		if event.index == _active_pointer:
			_update(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _active_pointer == -1 and _pad.get_global_rect().has_point(event.position):
				_active_pointer = -2
				_update(event.position)
		elif _active_pointer == -2:
			_active_pointer = -1
			_reset()
	elif event is InputEventMouseMotion and _active_pointer == -2:
		_update(event.position)

func _update(global_pos: Vector2) -> void:
	var center := _pad.get_global_rect().get_center()
	var offset := (global_pos - center).limit_length(radius)
	_nub.global_position = center + offset - _nub.size / 2.0
	_apply_input(offset / radius)

func _reset() -> void:
	_nub.position = _nub_center
	_apply_input(Vector2.ZERO)

func _apply_input(v: Vector2) -> void:
	_set_axis("move_left", "move_right", v.x)
	_set_axis("move_up", "move_down", v.y)

func _set_axis(negative_action: StringName, positive_action: StringName, value: float) -> void:
	if value < -0.01:
		Input.action_release(positive_action)
		Input.action_press(negative_action, clampf(-value, 0.0, 1.0))
	elif value > 0.01:
		Input.action_release(negative_action)
		Input.action_press(positive_action, clampf(value, 0.0, 1.0))
	else:
		Input.action_release(negative_action)
		Input.action_release(positive_action)
