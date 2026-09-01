class_name EnemyRegistry
extends RefCounted
## Same pattern as ItemRegistry.gd — loads every data/enemies/*.tres into a
## StringName -> EnemyData Dictionary. Paths listed explicitly (res://
## directory listing needs export-mode workarounds) — add a line here when
## a new enemy archetype is added to data/enemies/.

const _PATHS := [
	"res://data/enemies/thug.tres",
	"res://data/enemies/bandit.tres",
	"res://data/enemies/demon_a.tres",
	"res://data/enemies/blood_monster_a.tres",
]

static func load_all() -> Dictionary:
	var enemies := {}
	for path in _PATHS:
		var enemy: EnemyData = load(path)
		enemies[enemy.id] = enemy
	return enemies
