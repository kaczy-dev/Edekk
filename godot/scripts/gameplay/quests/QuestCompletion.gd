class_name QuestCompletion
extends RefCounted
## Typed replacement for QuestUtils.quest_completion()'s old
## `{"done": int, "total": int}` Dictionary return.

var done: int
var total: int

func _init(p_done: int = 0, p_total: int = 0) -> void:
	done = p_done
	total = p_total
