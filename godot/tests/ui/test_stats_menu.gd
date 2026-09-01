extends GutTest
## rpg.md backlog ("Osiągnięcia/statystyki życiowe") — StatsMenu displays
## ProgressStore's lifetime totals (built section 11e), read-only.

const StatsMenuScene := preload("res://scenes/menu/StatsMenu.tscn")
const TEST_SAVE_PATH := "user://test_stats_menu.json"

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


func test_shows_zero_stats_on_a_fresh_save() -> void:
	var menu: StatsMenu = StatsMenuScene.instantiate()
	add_child_autofree(menu)

	var enemies_label: Label = menu.get_node("Panel/VBox/EnemiesLabel")
	var earned_label: Label = menu.get_node("Panel/VBox/EarnedLabel")
	var days_label: Label = menu.get_node("Panel/VBox/DaysLabel")
	assert_true(enemies_label.text.contains("0"))
	assert_true(earned_label.text.contains("0"))
	assert_true(days_label.text.contains("0"))


func test_shows_the_current_lifetime_totals() -> void:
	ProgressStore.total_enemies_defeated = 7
	ProgressStore.total_money_earned = 250
	ProgressStore.total_days_survived = 3

	var menu: StatsMenu = StatsMenuScene.instantiate()
	add_child_autofree(menu)

	var enemies_label: Label = menu.get_node("Panel/VBox/EnemiesLabel")
	var earned_label: Label = menu.get_node("Panel/VBox/EarnedLabel")
	var days_label: Label = menu.get_node("Panel/VBox/DaysLabel")
	assert_true(enemies_label.text.contains("7"))
	assert_true(earned_label.text.contains("250"))
	assert_true(days_label.text.contains("3"))
