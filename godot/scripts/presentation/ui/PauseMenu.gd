class_name PauseMenu
extends CanvasLayer
## QoL request ("pauza i informacje jak było w projekcie w Phaser") — Godot
## port of PauseMenu.tsx (Wróć do gry/Zacznij od nowa/Wyjdź do menu) +
## ControlsModal.tsx (read-only keybind reference), merged into one scene
## since both were "press a button while paused" overlays for the TS app
## too, just reached via separate routes there. No confirmation sub-dialog
## for restart/exit (TS had AlertDialog for both) — left out for this pass;
## ProgressStore already autosaves incrementally, so the only thing "at
## risk" from an accidental restart/exit is the current level's
## session-local state, not persisted progress.
##
## `process_mode = ALWAYS` so this keeps receiving input/rendering while
## `get_tree().paused` is true. Everything else in a level (LevelRuntime,
## Player, enemies, Timers) is left at the default PAUSABLE mode, so
## pausing the tree is exactly "freeze gameplay" with zero extra flags
## needed anywhere else in the scene.

@onready var _panel: PanelContainer = $Panel
@onready var _resume_button: Button = $Panel/VBox/ResumeButton
@onready var _controls_button: Button = $Panel/VBox/ControlsButton
@onready var _restart_button: Button = $Panel/VBox/RestartButton
@onready var _exit_button: Button = $Panel/VBox/ExitButton

@onready var _controls_panel: PanelContainer = $ControlsPanel
@onready var _controls_rows: VBoxContainer = $ControlsPanel/VBox/Rows
@onready var _controls_close_button: Button = $ControlsPanel/VBox/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_controls_panel.visible = false

	_resume_button.pressed.connect(_on_resume_pressed)
	_controls_button.pressed.connect(_on_controls_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_controls_close_button.pressed.connect(_on_controls_close_pressed)

	_build_controls_rows()


## Reuses KeybindMenu's own action->label map instead of duplicating it —
## this panel is read-only (no rebind buttons, matching ControlsModal.tsx),
## KeybindMenu.gd still owns the actual rebind flow (reachable from
## Settings). Rows show whatever the player has currently bound, not just
## the defaults, so a rebind stays reflected here automatically.
func _build_controls_rows() -> void:
	for row in _controls_rows.get_children():
		row.free()
	for action: String in SettingsStore.REBINDABLE_ACTIONS:
		var action_label: String = KeybindMenu._ACTION_LABELS.get(action, action)
		var row := Label.new()
		row.text = "%s — %s" % [action_label, SettingsStore.get_key_label(action)]
		_controls_rows.add_child(row)


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("pause"):
		_on_resume_pressed()


func open() -> void:
	_build_controls_rows() # picks up any rebind made since this menu was built
	visible = true
	get_tree().paused = true


func _on_resume_pressed() -> void:
	_controls_panel.visible = false
	visible = false
	get_tree().paused = false


func _on_controls_pressed() -> void:
	_controls_panel.visible = true


func _on_controls_close_pressed() -> void:
	_controls_panel.visible = false


func _on_restart_pressed() -> void:
	get_tree().paused = false
	visible = false
	SceneRouter.reload_current_scene()


func _on_exit_pressed() -> void:
	get_tree().paused = false
	visible = false
	SceneRouter.change_scene_to_file("res://scenes/menu/MainMenu.tscn")
