class_name MainMenu
extends Control
## rpg.md section 11a — new entry point (replaces `Level1.tscn` as
## `run/main_scene`, closing docs/ROADMAP.md's audit item #7 "gra startuje w
## środku poziomu 1, nie ma menu głównego" along the way — not the primary
## goal of this pass, but a direct consequence of building this at all).
##
## "Kontynuuj" is the first real consumer of ProgressStore's persisted state
## at the START of a session (existing code only ever READS it once already
## inside a level) — visible only when a save file actually exists, with a
## one-line summary (day + money) so the player recognizes their save
## without opening it. `_has_saved_progress()` checks the FILE, not
## specific field values (money == 0 is a legitimate fresh-but-saved state,
## not "no save").
##
## Background life reuses AmbientPedestrian.gd/AmbientVehicle.gd verbatim
## (rpg.md section 10b) — same scripts as in-level ambient AI, just
## instanced here too; DayNightOverlay (section 10a) is synced to the real
## TimeManager clock so the menu's mood matches whatever time it actually is.

@onready var _continue_button: Button = $Panel/VBox/ContinueButton
@onready var _new_game_button: Button = $Panel/VBox/NewGameButton
@onready var _levels_button: Button = $Panel/VBox/LevelsButton
@onready var _settings_button: Button = $Panel/VBox/SettingsButton
@onready var _quit_button: Button = $Panel/VBox/QuitButton
@onready var _panel: PanelContainer = $Panel

const POP_SCALE_FROM := 0.9
const POP_DURATION := 0.3

func _ready() -> void:
	_continue_button.visible = _has_saved_progress()
	if _continue_button.visible:
		_continue_button.text = "Kontynuuj (Dzień %d · %d zł)" % [TimeManager.current_day + 1, ProgressStore.money]

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_levels_button.pressed.connect(_on_levels_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_animate_in()
	(_continue_button if _continue_button.visible else _new_game_button).grab_focus()

func _has_saved_progress() -> bool:
	return FileAccess.file_exists(ProgressStore.save_path)

## Same pop-in shape as ToastManager/TransitMenu (rpg.md's UI-polish pass) —
## scale+fade with TRANS_BACK, centered pivot resolved after first layout.
func _animate_in() -> void:
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(POP_SCALE_FROM, POP_SCALE_FROM)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size / 2.0, CONNECT_ONE_SHOT)
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, POP_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_panel, "scale", Vector2.ONE, POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_continue_pressed() -> void:
	# rpg.md section 11 backlog ("Szybki zapis / mid-level resume") —
	# a checkpoint (mid-level position/HP) takes priority over the last
	# unlocked level, since it points at a level actually in progress;
	# unlocked_levels.back() only ever pointed at a level's authored spawn.
	var level_id: String
	if ProgressStore.resume_level_id != "":
		level_id = ProgressStore.resume_level_id
	elif not ProgressStore.unlocked_levels.is_empty():
		level_id = ProgressStore.unlocked_levels.back()
	else:
		level_id = "1"
	SceneRouter.change_scene_to_file("res://scenes/levels/Level%s.tscn" % level_id)

func _on_new_game_pressed() -> void:
	ProgressStore.reset_progress()
	SceneRouter.change_scene_to_file("res://scenes/levels/Level1.tscn")

func _on_levels_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/LevelSelect.tscn")

func _on_settings_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/SettingsMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
