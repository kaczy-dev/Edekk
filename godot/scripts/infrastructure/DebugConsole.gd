extends CanvasLayer
## Autoload — in-game dev console per plan31-08.md "Część 12". Fifth
## autoload; unlike ProgressStore/AudioService/SettingsStore/EventBus this
## one is debug-tooling, not gameplay state, but it's still genuinely
## global/cross-scene (needs to work from any level or menu), so the same
## "autoload, used sparingly" bar applies and is met the same way.
##
## Toggled with `~` (backtick/tilde, KEY_QUOTELEFT) — checked directly via a
## physical keycode in _unhandled_input() rather than a new InputMap action,
## since this is a debug-only binding not meant to be rebindable alongside
## real gameplay actions. Only active in debug builds (`OS.is_debug_build()`
## guards both the toggle and every command) — never available in an
## exported release build.
##
## Commands: /god, /give_item <id> [count], /give_money [amount],
## /load_level <1-6>, /clear_save, /advance_day.

var _panel: PanelContainer
var _output: RichTextLabel
var _input: LineEdit

func _ready() -> void:
	if not OS.is_debug_build():
		return
	layer = 100 # above HUD's default CanvasLayer (layer 1)
	_build_ui()
	_panel.visible = false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.offset_bottom = 220
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	_output = RichTextLabel.new()
	_output.custom_minimum_size = Vector2(0, 180)
	_output.scroll_following = true
	_output.bbcode_enabled = false
	vbox.add_child(_output)

	_input = LineEdit.new()
	_input.placeholder_text = "/god, /give_item <id> [n], /give_money [n], /load_level <1-6>, /clear_save, /advance_day"
	_input.text_submitted.connect(_on_submitted)
	vbox.add_child(_input)

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_QUOTELEFT:
		_panel.visible = not _panel.visible
		if _panel.visible:
			_input.grab_focus()
		get_viewport().set_input_as_handled()

func _log(text: String) -> void:
	_output.append_text(text + "\n")
	print("[DebugConsole] ", text)

func _on_submitted(text: String) -> void:
	_input.clear()
	if text.strip_edges() == "":
		return
	_log("> " + text)
	_run_command(text.strip_edges())

func _current_level_runtime() -> Node:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("debug_give_item"):
		return scene
	return null

func _run_command(text: String) -> void:
	var parts := text.split(" ", false)
	if parts.is_empty():
		return
	match parts[0]:
		"/god":
			var runtime := _current_level_runtime()
			if runtime == null:
				_log("no active level")
				return
			runtime.debug_god_mode = not runtime.debug_god_mode
			_log("god mode: %s" % ("ON" if runtime.debug_god_mode else "OFF"))
		"/give_item":
			if parts.size() < 2:
				_log("usage: /give_item <item_id> [count]")
				return
			var runtime := _current_level_runtime()
			if runtime == null:
				_log("no active level")
				return
			var count := int(parts[2]) if parts.size() > 2 else 1
			runtime.debug_give_item(StringName(parts[1]), count)
			_log("gave %d x %s" % [count, parts[1]])
		"/load_level":
			if parts.size() < 2 or not parts[1].is_valid_int():
				_log("usage: /load_level <1-6>")
				return
			var n := parts[1].to_int()
			if n < 1 or n > 6:
				_log("level must be 1-6")
				return
			var path := "res://scenes/levels/Level%d.tscn" % n
			_log("loading %s" % path)
			SceneRouter.change_scene_to_file(path)
		"/give_money":
			var amount := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 20
			ProgressStore.add_money(amount)
			_log("gave %d zł (wallet: %d)" % [amount, ProgressStore.money])
		"/clear_save":
			ProgressStore.reset_progress()
			_log("progress cleared, reloading current scene")
			SceneRouter.reload_current_scene()
		"/advance_day":
			# QA tool for the day-summary toast (rpg.md section 11d) — a real
			# day takes 24 real minutes (TimeManager.MINUTES_PER_SECOND), far
			# too slow to sit through just to see the summary fire.
			TimeManager.advance_minutes(TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR - TimeManager.current_hour * TimeManager.MINUTES_PER_HOUR - TimeManager.current_minute)
			_log("advanced to day %d" % TimeManager.current_day)
		_:
			_log("unknown command: %s" % parts[0])
