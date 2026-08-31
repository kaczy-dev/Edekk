class_name LevelSelectMenu
extends Control
## Level-select screen — first slice of "Build/routing/menu (React)" in
## MIGRATION_MATRIX.md (Godot replacing the whole game runtime, not just
## gameplay). Ported subset of src/routes/menu.tsx: level list with
## title/subtitle, sequential unlock gating, best-time display, pick-to-play.
## Loads the level scene directly via change_scene_to_file(), no
## transition/loading screen yet.
##
## project.godot's run/main_scene stays Level1.tscn for now (that's the
## scene the current testing workflow expects) — this menu is available to
## run standalone (F6) until the team decides to make it the actual entry
## point.

const LEVELS := [
	{"id": "1", "title": "Wały Chrobrego", "subtitle": "Wieczorny spacer nad Odrą", "scene": "res://scenes/levels/Level1.tscn"},
	{"id": "2", "title": "Park Kasprowicza", "subtitle": "Pomnik Czynu Polaków", "scene": "res://scenes/levels/Level2.tscn"},
	{"id": "3", "title": "Aleja Kasztanowa", "subtitle": "Złota jesień w Parku Kasprowicza", "scene": "res://scenes/levels/Level3.tscn"},
	{"id": "4", "title": "Strych o zmroku", "subtitle": "Zakurzone tajemnice pod dachem", "scene": "res://scenes/levels/Level4.tscn"},
	{"id": "5", "title": "Ogród za blokiem", "subtitle": "Zielony zakątek w Szczecinie", "scene": "res://scenes/levels/Level5.tscn"},
	{"id": "6", "title": "Łucznicza 43", "subtitle": "Nowe podwórko w Szczecinie", "scene": "res://scenes/levels/Level6.tscn"},
	{"id": "7", "title": "Salon", "subtitle": "Pierwszy poranek na Łuczniczej", "scene": "res://scenes/levels/Level7.tscn"},
]

@onready var _list: VBoxContainer = $Panel/Content/List
@onready var _settings_button: Button = $Panel/Content/SettingsButton

func _ready() -> void:
	_settings_button.pressed.connect(_on_settings_pressed)
	for entry in LEVELS:
		var unlocked := ProgressStore.is_unlocked(entry.id)
		var row := HBoxContainer.new()

		var label := Label.new()
		var suffix := ""
		if ProgressStore.is_completed(entry.id):
			suffix = " ✓"
			var best = ProgressStore.best_level_times.get(entry.id)
			if best != null:
				suffix += "  (%s)" % _format_ms(best)
		label.text = "%s — %s%s" % [entry.title, entry.subtitle, suffix]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not unlocked:
			label.modulate = Color(1, 1, 1, 0.4)
		row.add_child(label)

		var button := Button.new()
		button.text = tr("Graj") if unlocked else tr("Zablokowane")
		button.disabled = not unlocked
		button.pressed.connect(_on_play_pressed.bind(entry.scene))
		row.add_child(button)

		_list.add_child(row)

func _on_play_pressed(scene_path: String) -> void:
	SceneRouter.change_scene_to_file(scene_path)

func _on_settings_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/SettingsMenu.tscn")

func _format_ms(ms: int) -> String:
	@warning_ignore("integer_division")
	var total_sec := ms / 1000
	@warning_ignore("integer_division")
	return "%d:%02d" % [total_sec / 60, total_sec % 60]
