class_name FavoritePlacesMenu
extends Control
## rpg.md backlog ("Ulubione miejsca") — read-only list of
## ProgressStore.favorite_places, the bookmarks the player set in-world by
## pressing the "favorite" action (see InteractionDetector.gd) on a
## favoritable interactable (NpcActor/VendingMachine — anything exposing
## `get_favorite_label()`). No in-scene fast-travel exists yet (only
## TransitStation's authored destinations move the player between levels),
## so this is deliberately the smaller, well-scoped version: a reference
## list ("what did I bookmark, and on which level"), not a teleport menu.

@onready var _rows_container: VBoxContainer = $Panel/VBox/ScrollContainer/Rows
@onready var _empty_label: Label = $Panel/VBox/EmptyLabel
@onready var _back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_refresh()


func _refresh() -> void:
	# See TransactionJournalMenu.gd's _refresh() comment — free() rather
	# than queue_free() so a synchronous double-refresh (as GUT tests do)
	# never double-counts a still-pending child.
	for child in _rows_container.get_children():
		child.free()

	var favorites := ProgressStore.get_favorites()
	for entry in favorites:
		_rows_container.add_child(_make_row(entry))

	_empty_label.visible = favorites.is_empty()


func _make_row(entry: Dictionary) -> Label:
	var level_id: String = entry.get("level_id", "")
	var label: String = entry.get("label", "")
	var row := Label.new()
	row.text = "⭐ %s — Poziom %s" % [label, level_id]
	return row


func _on_back_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/SettingsMenu.tscn")
