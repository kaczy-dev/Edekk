class_name QuestStepData
extends Resource
## Ported from src/game/types.ts (QuestStep discriminated union).
##
## TS uses a discriminated union (kind: "collect"|"talk"|"reach"); GDScript
## Resources have no union type. Chose one flat class with a `kind` field and
## kind-specific fields left unused per instance, over three subclasses —
## there are only 3 kinds, they don't share behaviour (just data), and a
## flat Resource is simpler to author as .tres by hand. Revisit only if a
## 4th kind actually needs different fields at scale (see DATA_MODEL.md).

@export var id: String
@export var kind: String # "collect" | "talk" | "reach"
@export var label: String

## "collect" only
@export var item_id: StringName = &""
@export var count: int = 0

## "talk" and "reach" only
@export var obj_id: String = ""
