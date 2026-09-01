class_name SettingsMenu
extends Control
## Minimal Settings screen — ported subset of src/routes/ustawienia.tsx:
## difficulty selector, volume slider, mute checkbox. Backed by
## SettingsStore.gd (autoload), which persists to user://settings.json.
##
## NOT ported: `sprintMode` toggle control (no keyboard consumer exists —
## see PlayerMovement.gd's header comment for why), and the rest of
## `ControlSettings` (touch/joystick/colorblind/goalIndicators/legend/
## renderQuality) — no consumer for any of them yet in Godot.

const _DIFFICULTY_ORDER := ["easy", "medium", "hard", "explorer"]

@onready var _difficulty_option: OptionButton = $Panel/VBox/DifficultyOption
@onready var _volume_slider: HSlider = $Panel/VBox/VolumeSlider
@onready var _mute_check: CheckBox = $Panel/VBox/MuteCheck
@onready var _keybind_button: Button = $Panel/VBox/KeybindButton
@onready var _journal_button: Button = $Panel/VBox/JournalButton
@onready var _favorites_button: Button = $Panel/VBox/FavoritesButton
@onready var _back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	for d in _DIFFICULTY_ORDER:
		var config := Difficulty.get_config(d)
		_difficulty_option.add_item(config.label)
	_difficulty_option.selected = _DIFFICULTY_ORDER.find(SettingsStore.difficulty)
	_difficulty_option.item_selected.connect(_on_difficulty_selected)

	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = SettingsStore.volume
	_volume_slider.value_changed.connect(SettingsStore.set_volume)

	_mute_check.button_pressed = SettingsStore.muted
	_mute_check.toggled.connect(SettingsStore.set_muted)

	_keybind_button.pressed.connect(_on_keybind_pressed)
	_journal_button.pressed.connect(_on_journal_pressed)
	_favorites_button.pressed.connect(_on_favorites_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func _on_difficulty_selected(index: int) -> void:
	SettingsStore.set_difficulty(_DIFFICULTY_ORDER[index])


func _on_keybind_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/KeybindMenu.tscn")


func _on_journal_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/TransactionJournal.tscn")


func _on_favorites_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/FavoritePlaces.tscn")


func _on_back_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/LevelSelect.tscn")
