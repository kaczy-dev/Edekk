class_name DayNightOverlay
extends CanvasLayer
## rpg.md section 6 backlog — smooth day/night tint driven by TimeManager,
## kept deliberately SEPARATE from AtmosphereFX.gd's per-level `mood`
## WorldEnvironment.adjustment_* system rather than merged into it.
## AtmosphereFX.gd's own header already flags "the spec's CanvasModulate
## global night tint" as something it chose NOT to add, for a level (L1)
## with an already-tuned, user-confirmed mood — touching that tested system
## to splice in a second, independent time source risked regressing it for
## no clear win. This is instead a thin additive overlay (a ColorRect, not
## a CanvasModulate — CanvasModulate is scene-tree-global and only one can
## be "active"; a second one would fight AtmosphereFX's, an alpha-blended
## rect on its own layer just draws on top, composing safely with anything
## already there) that only visibly does anything during TimeManager's
## dusk/dawn/night hours.

const NIGHT_COLOR := Color(0.05, 0.07, 0.22, 0.55)
const DAY_COLOR := Color(0.05, 0.07, 0.22, 0.0)

const DUSK_START := 19.0
const NIGHT_START := 21.0
const NIGHT_END := 5.0
const DAWN_END := 7.0

@onready var _rect: ColorRect = $ColorRect

func _process(_delta: float) -> void:
	_rect.color = DAY_COLOR.lerp(NIGHT_COLOR, night_factor())

## 0.0 = full day, 1.0 = full night, smoothly interpolated through dusk
## (19:00-21:00) and dawn (05:00-07:00) — public/static-shaped (reads
## TimeManager directly) so this is independently testable without
## instancing the whole overlay scene.
func night_factor() -> float:
	var hour_frac := TimeManager.current_hour + TimeManager.current_minute / 60.0
	if hour_frac >= NIGHT_START or hour_frac < NIGHT_END:
		return 1.0
	if hour_frac >= DUSK_START and hour_frac < NIGHT_START:
		return (hour_frac - DUSK_START) / (NIGHT_START - DUSK_START)
	if hour_frac >= NIGHT_END and hour_frac < DAWN_END:
		return 1.0 - (hour_frac - NIGHT_END) / (DAWN_END - NIGHT_END)
	return 0.0
