class_name MobileControls
extends CanvasLayer
## rpg.md section 8 — visibility gate for the on-screen joystick/buttons.
## Everything underneath (TouchJoystick/TouchButton) still runs even when
## hidden (harmless — they only act on touch/mouse input that won't occur
## on a hidden control anyway), `visible` here is purely presentational.

func _ready() -> void:
	visible = should_show()

static func should_show() -> bool:
	match SettingsStore.mobile_controls:
		"on":
			return true
		"off":
			return false
		_: # "auto"
			return DisplayServer.is_touchscreen_available()
