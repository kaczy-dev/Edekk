class_name ItemRegistry
extends RefCounted
## Ported from src/game/items.ts (ITEMS). Loads every data/items/*.tres into
## a StringName -> ItemData Dictionary. Paths are listed explicitly rather
## than scanned at runtime (res:// directory listing needs export-mode
## workarounds in exported builds) — add a line here when a new item is
## added to data/items/.

const _PATHS := [
	"res://data/items/bowl.tres",
	"res://data/items/ball.tres",
	"res://data/items/mouse.tres",
	"res://data/items/treat.tres",
	"res://data/items/key.tres",
	"res://data/items/chest.tres",
	"res://data/items/yarn.tres",
	"res://data/items/star.tres",
	"res://data/items/feather.tres",
	"res://data/items/leaf.tres",
	"res://data/items/photo.tres",
]

static func load_all() -> Dictionary:
	var items := {}
	for path in _PATHS:
		var item: ItemData = load(path)
		items[item.id] = item
	return items
