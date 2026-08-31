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

const CONFIG := {
	"easy": {"label": "Łatwy", "start_energy": 100.0, "sprint_drain_mul": 0.55, "rest_recover_mul": 1.5, "danger_damage": 5.0, "min_sprint_energy": 4.0},
	"medium": {"label": "Średni", "start_energy": 100.0, "sprint_drain_mul": 1.0, "rest_recover_mul": 1.0, "danger_damage": 10.0, "min_sprint_energy": 8.0},
	"hard": {"label": "Trudny", "start_energy": 80.0, "sprint_drain_mul": 1.6, "rest_recover_mul": 0.7, "danger_damage": 18.0, "min_sprint_energy": 16.0},
	# Casual/young-player mode: energy never meaningfully drains (0 drain, 0
	# danger damage) so sprinting/bee-stings never gate progress.
	"explorer": {"label": "Eksploracja", "start_energy": 100.0, "sprint_drain_mul": 0.0, "rest_recover_mul": 1.0, "danger_damage": 0.0, "min_sprint_energy": 0.0},
}

static func get_config(difficulty: String) -> Dictionary:
	return CONFIG.get(difficulty, CONFIG["medium"])
