extends CanvasLayer
## Autoload — plan31-08.md's "Scene Router" section. Sixth autoload: a
## fade-to-black/fade-in wrapper around `get_tree().change_scene_to_file()`,
## used by every menu-to-menu/menu-to-level transition (LevelSelectMenu,
## SettingsMenu, DebugConsole's `/load_level`). Purely a presentation-layer
## addition — doesn't touch gameplay/physics code, so this is one of the
## lower-risk items on today's list.

const FADE_DURATION := 0.25

var _fade: ColorRect

func _ready() -> void:
	layer = 99 # below DebugConsole's 100, above everything else
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func change_scene_to_file(path: String) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP # block input during the transition
	var out_tween := create_tween()
	out_tween.tween_property(_fade, "color:a", 1.0, FADE_DURATION)
	await out_tween.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	var in_tween := create_tween()
	in_tween.tween_property(_fade, "color:a", 0.0, FADE_DURATION)
	await in_tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func reload_current_scene() -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out_tween := create_tween()
	out_tween.tween_property(_fade, "color:a", 1.0, FADE_DURATION)
	await out_tween.finished

	get_tree().reload_current_scene()
	await get_tree().process_frame

	var in_tween := create_tween()
	in_tween.tween_property(_fade, "color:a", 0.0, FADE_DURATION)
	await in_tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
