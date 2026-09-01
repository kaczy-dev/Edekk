class_name StatsMenu
extends Control
## rpg.md backlog ("Osiągnięcia/statystyki życiowe — wrogowie pokonani,
## zarobek, dni przeżyte") — read-only display of ProgressStore's lifetime
## totals (total_enemies_defeated/total_money_earned/total_days_survived,
## built section 11e, never reset by day/level transitions unlike
## day_earned etc.). Same "data was already there, this is only the screen"
## situation as TransactionJournalMenu.gd/FavoritePlacesMenu.gd — no new
## tracking added here, just a place to read what's already tracked.

@onready var _enemies_label: Label = $Panel/VBox/EnemiesLabel
@onready var _earned_label: Label = $Panel/VBox/EarnedLabel
@onready var _days_label: Label = $Panel/VBox/DaysLabel
@onready var _back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_refresh()


func _refresh() -> void:
	_enemies_label.text = "Pokonani wrogowie: %d" % ProgressStore.total_enemies_defeated
	_earned_label.text = "Łączny zarobek: %d zł" % ProgressStore.total_money_earned
	_days_label.text = "Przeżyte dni: %d" % ProgressStore.total_days_survived


func _on_back_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/SettingsMenu.tscn")
