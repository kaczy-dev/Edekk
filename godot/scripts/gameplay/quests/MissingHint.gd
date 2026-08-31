class_name MissingHint
extends RefCounted
## Typed replacement for the old `{"emoji": ..., "label": ..., "where": ...}`
## Dictionary literal QuestUtils._missing_items() used to build. Transient,
## computed-only value (never saved/authored by hand) — the same reasoning
## that kept these as Dictionaries still applies to *why no Resource*, but a
## plain RefCounted with typed fields costs nothing and gets IDE/MCP
## autocomplete + typo-proof field access instead of string-keyed lookups.
## See docs/migration/MIGRATION_MATRIX.md, Sprint 1 refactor note.

var emoji: String
var label: String
var where: String

func _init(p_emoji: String = "", p_label: String = "", p_where: String = "") -> void:
	emoji = p_emoji
	label = p_label
	where = p_where
