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

## Combat signals — rpg.md section 3.5. Added ahead of their first emitter
## (feature/rpg-combat) because HUD (feature/rpg-hud) needs something to
## connect to when it's built; unlike item_collected/npc_talked/goal_reached
## above, these are declared with the actual consumer already planned, not
## speculative.
@warning_ignore("unused_signal")
signal player_damaged(current_hp: int, max_hp: int)
@warning_ignore("unused_signal")
signal enemy_damaged(obj_id: String, current_hp: int, max_hp: int)
@warning_ignore("unused_signal")
signal enemy_died(obj_id: String)

## feature/rpg-vfx (rpg.md): NOT the same information as enemy_damaged/
## player_damaged above — those carry obj_id/HP for the HUD, this carries a
## world position for VfxSpawner. Deliberately a separate, narrower signal
## rather than adding a `position` parameter to the existing two: those are
## already consumed by HealthBar.gd and asserted on by exact parameter
## lists in tests/ui/test_health_bar.gd and tests/combat/test_combat.gd —
## widening their signature would be a breaking change for a need only one
## new listener has.
@warning_ignore("unused_signal")
signal hit_landed(position: Vector2)

## rpg.md section 6 backlog ("Ekonomia miejska") — a decoupled way for
## gameplay (VendingMachine.gd, etc.) to ask the HUD to show a toast without
## reaching into it (rule 6: UI via signals, never get_node()). Also the
## first step toward docs/ROADMAP.md section 28's planned "Toasty zamiast
## jednego MessageLabel" — ToastManager.gd is the generic mechanism that
## work will build on, not a one-off for the vending machine alone.
@warning_ignore("unused_signal")
signal toast_requested(text: String)

## Fired when a purchase actually succeeds (VendingMachine.gd, after
## ProgressStore.spend_money() returns true) — separate from toast_requested
## because a toast is presentation-only, this is a fact something else
## (a quest, a reputation system down the line) might want to react to.
@warning_ignore("unused_signal")
signal item_purchased(item_id: StringName, cost: int)

## LevelRuntime._energy is private/per-level — VendingMachine.gd has no
## reference to it and shouldn't (same get_node() rule). Requesting a
## restore through EventBus keeps the vending machine ignorant of which
## LevelRuntime (if any) is even listening.
@warning_ignore("unused_signal")
signal energy_restore_requested(amount: float)

## rpg.md section 6 backlog ("Reputacja w dzielnicach") — emitted by
## ProgressStore.add_reputation(). No listener yet (HUD/dialogue reactions
## are a follow-up once actual zone-gated content exists), same "add ahead
## of a planned but not-yet-built consumer" reasoning as player_damaged/
## enemy_damaged had in Część 9.
@warning_ignore("unused_signal")
signal reputation_changed(zone_id: String, new_value: int)

## rpg.md section 11 backlog ("Powiadomienia o niskiej energii/pieniądzach") —
## emitted by ProgressStore.add_money()/spend_money() on every change, so a
## low-balance toast (or a future wallet HUD widget) doesn't need to poll.
@warning_ignore("unused_signal")
signal money_changed(new_amount: int)

## rpg.md section 11b backlog ("Graffiti/ślady gracza w miejscach walk") —
## a world position where a lasting cosmetic mark should appear, separate
## from `hit_landed` (fires on every individual hit, feeds VfxSpawner's
## short-lived burst) — this fires once per fight, on the kill, so the
## ground remembers a battle happened there long after the burst fades.
@warning_ignore("unused_signal")
signal combat_trace_requested(position: Vector2)

## rpg.md backlog ("Ulubione miejsca") — emitted by InteractionDetector.gd
## when the player presses the "favorite" action while a favoritable
## interactable (one exposing `get_favorite_label()`, e.g. NpcActor/
## VendingMachine) is the nearest target. LevelRuntime listens (it's the
## only place that knows the current `level.id`, same reason
## record_item_collected()/record_talked() calls go through it rather than
## ProgressStore being called directly from the interactable itself).
@warning_ignore("unused_signal")
signal favorite_toggle_requested(obj_id: String, label: String)
