extends Node
## rpg.md section 6 backlog ("Cykl dobowy i Kalendarz") — eighth autoload,
## alongside ProgressStore/AudioService/SettingsStore/EventBus/DebugConsole/
## SceneRouter/VfxSpawner. Game time runs faster than real time (one real
## second = MINUTES_PER_SECOND game-minutes) and wraps through a 7-day week.
## No smartphone UI wraps this per the user's explicit "bez systemu
## smartfona" — CanvasModulate below is the only presentation layer; a
## day/night-gated shop or quest reads `current_hour`/`is_night()` directly,
## same access pattern as SettingsStore.difficulty.

signal hour_changed(current_hour: int)
signal day_changed(current_day: int) # 0=Monday .. 6=Sunday

const MINUTES_PER_SECOND := 1.0 # 1 real second == 1 game minute
const MINUTES_PER_HOUR := 60
const HOURS_PER_DAY := 24
const NIGHT_START_HOUR := 21
const NIGHT_END_HOUR := 6

var current_minute: int = 0
var current_hour: int = 8 # start mid-morning, not midnight
var current_day: int = 0

var _minute_accum: float = 0.0

func _process(delta: float) -> void:
	_minute_accum += delta * MINUTES_PER_SECOND
	while _minute_accum >= 1.0:
		_minute_accum -= 1.0
		_advance_minute()

func _advance_minute() -> void:
	current_minute += 1
	if current_minute >= MINUTES_PER_HOUR:
		current_minute = 0
		_advance_hour()

func _advance_hour() -> void:
	current_hour = (current_hour + 1) % HOURS_PER_DAY
	hour_changed.emit(current_hour)
	if current_hour == 0:
		current_day = (current_day + 1) % 7
		day_changed.emit(current_day)

## Used by shop/quest gating — a kiosk closed at night, a quest that only
## triggers "o 15:00". Night wraps past midnight (21:00-06:00), hence the
## OR rather than a simple range check.
func is_night() -> bool:
	return current_hour >= NIGHT_START_HOUR or current_hour < NIGHT_END_HOUR

## TransitStation.gd (fast travel) calls this to advance the clock by a
## travel cost — deliberately public and separate from the per-frame
## _advance_minute() above, since jumping 30 minutes at once must not fire
## 30 individual hour_changed signals for hours it just skipped over, only
## the ones actually crossed.
func advance_minutes(amount: int) -> void:
	for _i in range(amount):
		_advance_minute()

## HH:MM, zero-padded — for HUD/UI display.
func time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]
