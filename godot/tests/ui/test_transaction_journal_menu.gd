extends GutTest
## rpg.md backlog ("Filtr dziennika transakcji") — TransactionJournalMenu
## reads ProgressStore.transaction_history and filters by type (all/earn/
## spend), the only two transaction types this save format records.

const TransactionJournalMenuScene := preload("res://scenes/menu/TransactionJournal.tscn")
const TEST_SAVE_PATH := "user://test_transaction_journal_menu.json"

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

func _rows_container(menu: TransactionJournalMenu) -> VBoxContainer:
	return menu.get_node("Panel/VBox/ScrollContainer/Rows")

func test_shows_all_transactions_by_default() -> void:
	ProgressStore.add_money(10)
	ProgressStore.spend_money(3)

	var menu: TransactionJournalMenu = TransactionJournalMenuScene.instantiate()
	add_child_autofree(menu)

	assert_eq(_rows_container(menu).get_child_count(), 2)

func test_filter_earn_hides_spend_rows() -> void:
	ProgressStore.add_money(10)
	ProgressStore.spend_money(3)

	var menu: TransactionJournalMenu = TransactionJournalMenuScene.instantiate()
	add_child_autofree(menu)
	menu._refresh(1) # _FILTER_EARN

	var rows := _rows_container(menu)
	assert_eq(rows.get_child_count(), 1)
	assert_true((rows.get_child(0) as Label).text.contains("+10"))

func test_filter_spend_hides_earn_rows() -> void:
	ProgressStore.add_money(10)
	ProgressStore.spend_money(3)

	var menu: TransactionJournalMenu = TransactionJournalMenuScene.instantiate()
	add_child_autofree(menu)
	menu._refresh(2) # _FILTER_SPEND

	var rows := _rows_container(menu)
	assert_eq(rows.get_child_count(), 1)
	assert_true((rows.get_child(0) as Label).text.contains("-3"))

func test_empty_history_shows_empty_label() -> void:
	var menu: TransactionJournalMenu = TransactionJournalMenuScene.instantiate()
	add_child_autofree(menu)

	var empty_label: Label = menu.get_node("Panel/VBox/EmptyLabel")
	assert_true(empty_label.visible)

func test_rows_are_newest_first() -> void:
	ProgressStore.add_money(1)
	ProgressStore.add_money(2)

	var menu: TransactionJournalMenu = TransactionJournalMenuScene.instantiate()
	add_child_autofree(menu)

	var rows := _rows_container(menu)
	assert_true((rows.get_child(0) as Label).text.contains("+2"), "the most recent transaction should render first")
