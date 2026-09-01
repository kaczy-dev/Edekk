class_name KeybindMenu
extends Control
## rpg.md backlog ("Rebindowanie klawiszy") — one row per
## SettingsStore.REBINDABLE_ACTIONS: a label, a button showing the current
## key (click to rebind), and a per-row reset button. Rows are built in
## code from the data-driven action list instead of hand-placed in the
## .tscn — adding/removing a rebindable action later means editing one
## Dictionary in SettingsStore.gd, not this scene.

## Polish display names for each action — kept here (UI-only concern)
## rather than in SettingsStore.gd, which has no reason to know about
## presentation strings (same separation as the rest of this menu layer).
const _ACTION_LABELS := {
	"move_up": "Ruch: góra",
	"move_down": "Ruch: dół",
	"move_left": "Ruch: lewo",
	"move_right": "Ruch: prawo",
	"interact": "Interakcja",
	"inventory": "Ekwipunek",
	"pause": "Pauza",
	"sprint": "Sprint",
	"hop": "Skok",
	"attack": "Atak",
	"quick_save": "Szybki zapis",
	"favorite": "Ulubione (zaznacz)",
}

const _MODIFIER_KEYCODES := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

@onready var _rows_container: VBoxContainer = $Panel/VBox/ScrollContainer/Rows
@onready var _reset_all_button: Button = $Panel/VBox/ResetAllButton
@onready var _back_button: Button = $Panel/VBox/BackButton
@onready var _hint_label: Label = $Panel/VBox/HintLabel

## action currently waiting for the next keypress, "" when idle.
var _listening_for: String = ""
var _key_buttons: Dictionary = { }


func _ready() -> void:
	for action: String in SettingsStore.REBINDABLE_ACTIONS:
		_add_row(action)
	_reset_all_button.pressed.connect(_on_reset_all_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func _add_row(action: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = _ACTION_LABELS.get(action, action)
	name_label.custom_minimum_size = Vector2(160, 0)
	row.add_child(name_label)

	var key_button := Button.new()
	key_button.custom_minimum_size = Vector2(90, 0)
	key_button.text = SettingsStore.get_key_label(action)
	key_button.pressed.connect(_on_rebind_pressed.bind(action, key_button))
	row.add_child(key_button)
	_key_buttons[action] = key_button

	var reset_button := Button.new()
	reset_button.text = "Domyślny"
	reset_button.pressed.connect(_on_reset_pressed.bind(action))
	row.add_child(reset_button)

	_rows_container.add_child(row)


func _on_rebind_pressed(action: String, key_button: Button) -> void:
	if _listening_for != "":
		return
	_listening_for = action
	key_button.text = "..."
	_hint_label.text = "Naciśnij nowy klawisz (Esc anuluje)"


func _on_reset_pressed(action: String) -> void:
	SettingsStore.reset_keybind(action)
	_refresh_all_labels()


func _on_reset_all_pressed() -> void:
	SettingsStore.reset_all_keybinds()
	_refresh_all_labels()


func _refresh_all_labels() -> void:
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = SettingsStore.get_key_label(action)


func _unhandled_key_input(event: InputEvent) -> void:
	if _listening_for == "" or not event is InputEventKey or not event.pressed:
		return
	var key_event := event as InputEventKey
	if _MODIFIER_KEYCODES.has(key_event.physical_keycode):
		return # a bare modifier isn't a usable single-key binding

	var action := _listening_for
	_listening_for = ""
	_hint_label.text = ""

	if key_event.physical_keycode == KEY_ESCAPE:
		(_key_buttons[action] as Button).text = SettingsStore.get_key_label(action)
		get_viewport().set_input_as_handled()
		return

	SettingsStore.set_keybind(action, key_event.physical_keycode)
	_refresh_all_labels() # other rows may have lost their key (conflict clear)
	get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/SettingsMenu.tscn")
