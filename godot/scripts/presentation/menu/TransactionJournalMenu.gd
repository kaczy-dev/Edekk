class_name TransactionJournalMenu
extends Control
## rpg.md backlog ("Filtr dziennika transakcji") — reads
## ProgressStore.transaction_history (built section 11e: `{"type":
## "earn"|"spend", "amount", "day", "hour", "minute"}`, newest entry last,
## capped at MAX_TRANSACTION_HISTORY) and renders it newest-first with a
## type filter. "earn"/"spend" are the only two transaction types this save
## format actually records (VendingMachine spends, add_money() earns) — no
## further subtype (purchase vs. energy-restore vs. quest reward) exists in
## the data today, so the filter offers exactly what's real: all/earn/spend.

const _FILTER_ALL := 0
const _FILTER_EARN := 1
const _FILTER_SPEND := 2

@onready var _filter_option: OptionButton = $Panel/VBox/FilterOption
@onready var _rows_container: VBoxContainer = $Panel/VBox/ScrollContainer/Rows
@onready var _empty_label: Label = $Panel/VBox/EmptyLabel
@onready var _back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	_filter_option.clear()
	_filter_option.add_item("Wszystkie", _FILTER_ALL)
	_filter_option.add_item("Przychody", _FILTER_EARN)
	_filter_option.add_item("Wydatki", _FILTER_SPEND)
	_filter_option.selected = _FILTER_ALL
	_filter_option.item_selected.connect(_on_filter_selected)

	_back_button.pressed.connect(_on_back_pressed)

	_refresh(_FILTER_ALL)


func _on_filter_selected(_index: int) -> void:
	_refresh(_filter_option.get_selected_id())


## Rebuilds the row list from scratch — the history is capped at
## MAX_TRANSACTION_HISTORY (100) entries, small enough that a full rebuild
## on every filter change is simpler than diffing, same tradeoff other
## small list UIs in this codebase (KeybindMenu's rows) already make.
func _refresh(filter: int) -> void:
	# `free()`, not `queue_free()` — this can be called synchronously twice
	# in one frame (e.g. GutTest instantiating the menu then immediately
	# calling _refresh() with a different filter) and a still-pending
	# queue_free() child would double-count in get_child_count() until the
	# next frame flushes it.
	for child in _rows_container.get_children():
		child.free()

	var entries := ProgressStore.transaction_history
	var shown := 0
	# Newest last in storage (see ProgressStore.gd header) — walk backwards
	# so the journal reads newest-first, matching every other "history" list
	# in this codebase's UI conventions (toasts, quest log).
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		var type: String = entry.get("type", "")
		if filter == _FILTER_EARN and type != "earn":
			continue
		if filter == _FILTER_SPEND and type != "spend":
			continue
		_rows_container.add_child(_make_row(entry))
		shown += 1

	_empty_label.visible = shown == 0


func _make_row(entry: Dictionary) -> Label:
	var type: String = entry.get("type", "")
	var amount: int = int(entry.get("amount", 0))
	var day: int = int(entry.get("day", 0))
	var hour: int = int(entry.get("hour", 0))
	var minute: int = int(entry.get("minute", 0))
	var sign_str := "+" if type == "earn" else "-"
	var label := Label.new()
	label.text = "Dzień %d, %02d:%02d — %s%d zł" % [day + 1, hour, minute, sign_str, amount]
	return label


func _on_back_pressed() -> void:
	SceneRouter.change_scene_to_file("res://scenes/menu/SettingsMenu.tscn")
