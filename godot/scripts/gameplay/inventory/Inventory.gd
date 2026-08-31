class_name Inventory
extends RefCounted
## Ported 1:1 from src/game/inventory.ts. Pure logic, no Node/scene
## dependency — matches the TS source's own design (it's engine-agnostic
## there too). Static-only; never instantiate this.

## Items granted by an NPC when talked to, keyed by npc_id. Gifts are
## recorded under a synthetic id (the NPC object's id + GIFT_SUFFIX) because
## they have no pickup object on the map.
const NPC_GIFTS := {
	"squirrel": &"yarn",
	"pigeon": &"feather",
	"kot": &"key",
}

const GIFT_SUFFIX := "-gift"

static func gift_obj_id(npc_obj_id: String) -> String:
	return npc_obj_id + GIFT_SUFFIX

static func _collected_item_id(level: LevelData, obj_id: String) -> StringName:
	if obj_id.ends_with(GIFT_SUFFIX):
		var npc_id := obj_id.substr(0, obj_id.length() - GIFT_SUFFIX.length())
		for obj in level.objects:
			if obj.id == npc_id:
				return NPC_GIFTS.get(obj.npc_id, &"")
		return &""

	for obj in level.objects:
		if obj.id == obj_id:
			return obj.item_id if obj.kind == "item" else &""
	return &""

## Rebuild a level-run inventory from the object ids recorded as collected.
## Returns a Dictionary[StringName, int] (item id -> count).
static func inventory_from_collected(level: LevelData, collected_ids: Array) -> Dictionary:
	var inventory := {}
	for obj_id in collected_ids:
		var item_id := _collected_item_id(level, obj_id)
		if item_id != &"":
			inventory[item_id] = inventory.get(item_id, 0) + 1
	return inventory
