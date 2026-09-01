class_name TouchButton
extends TextureButton
## rpg.md section 8 — drives one InputMap action via Input.action_press()/
## action_release() on button_down/button_up. TextureButton already
## receives touch input converted to gui_input by Godot's Control layer
## (unlike TouchJoystick, which needs raw touch/drag tracking since it
## isn't a fixed hit-test button) — no custom touch handling needed here.
##
## action_press() satisfies BOTH Input.is_action_pressed() (sprint, held)
## AND Input.is_action_just_pressed() (hop/attack, edge-triggered) the same
## way a real key event would — PlayerHop.gd/PlayerAttack.gd never know the
## difference between this and a keyboard press.

@export var action: StringName

## Visual feedback on top of texture_pressed (set per-instance in
## MobileControls.tscn to the Kenney "depth_gloss" variant, which already
## reads as "pushed in") — a small scale-down tween so the press registers
## even at a glance, same idea as the vending machine's interact pulse.
const PRESS_SCALE := 0.88
const PRESS_ANIM_DURATION := 0.08

func _ready() -> void:
	pivot_offset = size / 2.0
	button_down.connect(func() -> void:
		Input.action_press(action)
		_animate_press(PRESS_SCALE))
	button_up.connect(func() -> void:
		Input.action_release(action)
		_animate_press(1.0))

func _animate_press(target_scale: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), PRESS_ANIM_DURATION)
