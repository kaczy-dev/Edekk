extends Node
## Autoload — global event bus decoupling interactable emitters
## (ItemPickup/NpcActor/GoalArea) from their listener (LevelRuntime.gd). See
## plan31-08.md, "Część 9". Fourth autoload; still "used sparingly" per
## god/godot2.md — this replaces what were direct per-node signal
## connections (LevelBuilder.build() returning a list, LevelRuntime
## connecting to each node), not a new capability.
##
## Payload shapes deliberately do NOT match the "Część 9" spec verbatim
## (`item_collected(item_data: ItemData)`, no obj_id). This project's data
## model keys everything downstream — QuestUtils' "already collected" checks,
## ProgressStore.record_item_collected(), Inventory.gift_obj_id() — by
## obj_id (the specific placed object instance), not item_id/npc_id (the
## shared species/kind id). A signal without obj_id would be unusable for
## LevelRuntime's actual bookkeeping, so obj_id is always the first payload
## argument here.
##
## Deliberately NOT added (unlike the spec's suggestion): `player_damaged`,
## `level_completed`. Nothing in this codebase emits damage yet (no `trigger`
## objects on any ported level — MIGRATION_MATRIX.md) and level-completed is
## a LevelRuntime-computed outcome (after checking `requires`), not a raw
## node emission — a bus signal with exactly one emitter and one listener,
## both LevelRuntime itself, would be pure indirection with no decoupling
## benefit. Add them when a second, genuinely independent listener exists.

## GDScript's static analyzer flags these as "declared but never explicitly
## used in the class" — a false positive: they're emitted from
## ItemPickup.gd/NpcActor.gd/GoalArea.gd and connected from LevelRuntime.gd,
## just never referenced from inside EventBus.gd itself (which is correct —
## a bus has no business calling its own signals).
@warning_ignore("unused_signal")
signal item_collected(obj_id: String, item_id: StringName)
@warning_ignore("unused_signal")
signal npc_talked(obj_id: String, npc_id: String)
@warning_ignore("unused_signal")
signal goal_reached(obj_id: String)
