class_name QuestUtils
extends RefCounted
## Ported 1:1 from src/game/questUtils.ts. Pure logic, no Node/scene
## dependency — engine-agnostic in the TS source too. Static-only.
##
## compute_quests() returns Array[QuestStatus] (typed RefCounted, see
## QuestStatus.gd/MissingHint.gd) rather than plain Dictionaries — refactored
## after MCP-assisted dev work flagged Dictionary literals as a typo/autocomplete
## risk (see docs/migration/MIGRATION_MATRIX.md, Sprint 1). Still transient,
## computed-only values, never saved/authored by hand — that reasoning didn't
## change, only the "Dictionary vs typed class" tradeoff did.

## Items that don't spawn on the map — where to acquire them.
const ITEM_SOURCE_FALLBACK := {
	&"yarn": "Prezent od wiewiórki w Parku Kasprowicza (porozmawiaj z nią).",
	&"feather": "Prezent od gołębia na podwórku (porozmawiaj z nim).",
	&"treat": "Nagroda za wypełnienie zadań pobocznych.",
}

static func _location_of(obj: LevelObjectData, level: LevelData) -> String:
	var cx := obj.rect.position.x + obj.rect.size.x / 2.0
	var cy := obj.rect.position.y + obj.rect.size.y / 2.0
	var fx := cx / level.width
	var fy := cy / level.height
	var h := "po lewej" if fx < 0.34 else ("po prawej" if fx > 0.66 else "na środku")
	var v := "u góry" if fy < 0.34 else ("na dole" if fy > 0.66 else "w środkowym pasie")
	return "%s mapy, %s" % [v, h]

static func _missing_items(item_id: StringName, need: int, have: int, level: LevelData, collected: Array, items: Dictionary) -> Array[MissingHint]:
	var item_data: ItemData = items[item_id]
	var remaining := maxi(0, need - have)
	var hints: Array[MissingHint] = []
	if remaining <= 0:
		return hints

	var sources: Array[LevelObjectData] = []
	for obj in level.objects:
		if obj.kind == "item" and obj.item_id == item_id and not collected.has(obj.id):
			sources.append(obj)

	if sources.size() > 0:
		var slice_count := mini(remaining, sources.size())
		for i in range(slice_count):
			var src := sources[i]
			var label := "%s (%d/%d brakująca)" % [item_data.item_name, i + 1, remaining] if remaining > 1 else "%s — brakuje 1 szt." % item_data.item_name
			hints.append(MissingHint.new(item_data.emoji, label, _location_of(src, level)))
		if sources.size() < remaining:
			hints.append(MissingHint.new(
				"❓",
				"%s — %d poza tą planszą" % [item_data.item_name, remaining - sources.size()],
				ITEM_SOURCE_FALLBACK.get(item_id, "Sprawdź poprzednie plansze — mogłeś coś pominąć.")
			))
	else:
		hints.append(MissingHint.new(
			item_data.emoji,
			"%s — brakuje %d" % [item_data.item_name, remaining],
			ITEM_SOURCE_FALLBACK.get(item_id, "Brak na tej planszy — wróć do wcześniejszych poziomów.")
		))
	return hints

## `snapshot` shape: { inventory: Dictionary[StringName, int], talked: Array[String],
## level_completed: bool, collected: Array[String] }. `items` is the ItemData
## registry (StringName -> ItemData), see data/items/.
static func compute_quests(level: LevelData, snapshot: Dictionary, items: Dictionary) -> Array[QuestStatus]:
	var statuses: Array[QuestStatus] = []
	for quest in level.quests:
		if quest.kind == "collect":
			var have: int = mini(quest.count, snapshot.inventory.get(quest.item_id, 0))
			var done := have >= quest.count
			var status := QuestStatus.new(quest)
			status.done = done
			status.current = have
			status.total = quest.count
			status.missing = ([] as Array[MissingHint]) if done else _missing_items(quest.item_id, quest.count, have, level, snapshot.collected, items)
			statuses.append(status)
			continue

		if quest.kind == "talk":
			var done_talk: bool = snapshot.talked.has(quest.obj_id)
			var npc: LevelObjectData = null
			for obj in level.objects:
				if obj.id == quest.obj_id:
					npc = obj
					break
			var missing_talk: Array[MissingHint] = []
			if not done_talk and npc != null:
				missing_talk.append(MissingHint.new("💬", "Podejdź i naciśnij E, aby porozmawiać.", _location_of(npc, level)))
			var talk_status := QuestStatus.new(quest)
			talk_status.done = done_talk
			talk_status.current = 1 if done_talk else 0
			talk_status.total = 1
			talk_status.missing = missing_talk
			statuses.append(talk_status)
			continue

		# reach
		var goal: LevelObjectData = null
		for obj in level.objects:
			if obj.id == quest.obj_id:
				goal = obj
				break
		var missing_reach: Array[MissingHint] = []
		var ready := true
		if goal != null:
			for item_id in goal.requires:
				var need: int = goal.requires[item_id]
				var have_req: int = snapshot.inventory.get(item_id, 0)
				if have_req < need:
					ready = false
					missing_reach.append_array(_missing_items(item_id, need, have_req, level, snapshot.collected, items))
		var done_reach: bool = snapshot.level_completed
		if not done_reach and ready and goal != null:
			missing_reach.append(MissingHint.new("🚩", "Warunki spełnione — dotrzyj do celu.", _location_of(goal, level)))
		var reach_status := QuestStatus.new(quest)
		reach_status.done = done_reach
		reach_status.current = 1 if done_reach else 0
		reach_status.total = 1
		reach_status.ready = not done_reach and ready
		reach_status.missing = ([] as Array[MissingHint]) if done_reach else missing_reach
		statuses.append(reach_status)
	return statuses

static func quest_completion(statuses: Array[QuestStatus]) -> QuestCompletion:
	var done := 0
	for status in statuses:
		if status.done:
			done += 1
	return QuestCompletion.new(done, statuses.size())
