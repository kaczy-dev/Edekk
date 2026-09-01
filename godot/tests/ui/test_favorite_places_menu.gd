extends GutTest
## rpg.md backlog ("Ulubione miejsca") — FavoritePlacesMenu lists
## ProgressStore.favorite_places (read-only reference list, no fast-travel).

const FavoritePlacesMenuScene := preload("res://scenes/menu/FavoritePlaces.tscn")
const TEST_SAVE_PATH := "user://test_favorite_places_menu.json"

var _real_save_path: String

func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH

func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

func before_each() -> void:
	ProgressStore.reset_progress()

func _rows_container(menu: FavoritePlacesMenu) -> VBoxContainer:
	return menu.get_node("Panel/VBox/ScrollContainer/Rows")

func test_empty_favorites_shows_empty_label() -> void:
	var menu: FavoritePlacesMenu = FavoritePlacesMenuScene.instantiate()
	add_child_autofree(menu)

	var empty_label: Label = menu.get_node("Panel/VBox/EmptyLabel")
	assert_true(empty_label.visible)
	assert_eq(_rows_container(menu).get_child_count(), 0)

func test_lists_favorited_places() -> void:
	ProgressStore.toggle_favorite("1", "npc_1", "Ala")
	ProgressStore.toggle_favorite("2", "vending_a", "Automat")

	var menu: FavoritePlacesMenu = FavoritePlacesMenuScene.instantiate()
	add_child_autofree(menu)

	var empty_label: Label = menu.get_node("Panel/VBox/EmptyLabel")
	assert_false(empty_label.visible)

	var rows := _rows_container(menu)
	assert_eq(rows.get_child_count(), 2)
	assert_true((rows.get_child(0) as Label).text.contains("Ala"))
	assert_true((rows.get_child(1) as Label).text.contains("Automat"))
