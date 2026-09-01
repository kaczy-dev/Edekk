class_name Difficulty
extends RefCounted
## Ported 1:1 from src/store/gameStore.ts (DIFFICULTIES). Pure data,
## static-only — no Node/scene dependency, matching the source's plain
## exported const. Only the numbers needed to drive Energy are ported;
## `label` kept too since it's free and useful once a difficulty-select UI
## exists (Settings system, still ANALYZED — see MIGRATION_MATRIX.md).
##
## NOT wired to a selector yet — no Settings UI exists in Godot, so
## LevelRuntime hardcodes "medium" for now (see its `_difficulty` constant).

const MAX_ENERGY := 100.0

## rpg.md section 11 backlog ("Panel trudności jako osobne ustawienie
## (obrażenia/ceny/agresywność wrogów)") — `enemy_damage_mul`/`shop_price_mul`
## added alongside the pre-existing energy fields rather than as a separate
## resource, since the difficulty picker (SettingsMenu.gd/SettingsStore.gd)
## already exists and already keys off this same CONFIG dictionary; a second
## parallel "combat difficulty" struct would just be two sources of truth
## for the same five-word list of difficulty names.
const CONFIG := {
	"easy": {"label": "Łatwy", "start_energy": 100.0, "sprint_drain_mul": 0.55, "rest_recover_mul": 1.5, "danger_damage": 5.0, "min_sprint_energy": 4.0, "enemy_damage_mul": 0.7, "shop_price_mul": 0.85},
	"medium": {"label": "Średni", "start_energy": 100.0, "sprint_drain_mul": 1.0, "rest_recover_mul": 1.0, "danger_damage": 10.0, "min_sprint_energy": 8.0, "enemy_damage_mul": 1.0, "shop_price_mul": 1.0},
	"hard": {"label": "Trudny", "start_energy": 80.0, "sprint_drain_mul": 1.6, "rest_recover_mul": 0.7, "danger_damage": 18.0, "min_sprint_energy": 16.0, "enemy_damage_mul": 1.4, "shop_price_mul": 1.15},
	# Casual/young-player mode: energy never meaningfully drains (0 drain, 0
	# danger damage) so sprinting/bee-stings never gate progress. Combat
	# damage is zeroed the same way for the same reason; prices stay at the
	# medium rate — "no danger" shouldn't also mean "free shopping".
	"explorer": {"label": "Eksploracja", "start_energy": 100.0, "sprint_drain_mul": 0.0, "rest_recover_mul": 1.0, "danger_damage": 0.0, "min_sprint_energy": 0.0, "enemy_damage_mul": 0.0, "shop_price_mul": 1.0},
}

static func get_config(difficulty: String) -> Dictionary:
	return CONFIG.get(difficulty, CONFIG["medium"])

## Applied at the point of damage (EnemyHitbox.apply_hit()) rather than
## baked into EnemyData/StatsData — the same `thug.tres` should hit harder
## on Trudny without needing a difficulty-specific copy of every enemy
## Resource. `maxi(0, ...)` guards Eksploracja's 0.0 multiplier from ever
## going negative on a signed `attack_damage` export.
static func scaled_damage(base_damage: int, difficulty: String) -> int:
	return maxi(0, roundi(base_damage * get_config(difficulty).enemy_damage_mul as float))

## Same reasoning as scaled_damage() — applied at the point of sale
## (VendingMachine.interact(), TransitMenu) rather than baked into
## VendingMachine.cost/TransitDestination.cost exports, so one placed price
## already reflects every difficulty. `maxi(0, ...)` guards against a
## pathological multiplier making something free.
static func scaled_price(base_cost: int, difficulty: String) -> int:
	return maxi(0, roundi(base_cost * get_config(difficulty).shop_price_mul as float))
