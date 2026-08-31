class_name DailyChallenge
extends RefCounted
## Ported 1:1 from src/game/daily.ts. Pure logic, no Node/scene dependency —
## engine-agnostic in the TS source too. Static-only.
##
## NOT wired up to anything yet — no UI consumes it (the TS "Daily
## Challenge" feature lives behind routes/menu screens not yet migrated,
## see MIGRATION_MATRIX.md "Build/routing/menu"). Ported now because it's
## small, self-contained, and has zero risk of drifting from unmigrated
## systems (unlike Settings/Difficulty, which are pointless to port before
## the Energy system that consumes them exists).

## Deterministic day key in the player's local timezone (YYYY-MM-DD).
## `date` defaults to today — Godot requires default parameter values to be
## constant expressions, so "today" (a function call) is resolved inside
## the body instead of in the signature.
static func daily_date_key(date: Dictionary = {}) -> String:
	var d: Dictionary = date if not date.is_empty() else Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

## Simple string hash (djb2-ish), pure and stable across sessions/devices
## for the same date key. `hash & 0xFFFFFFFF` mirrors JS's `>>> 0` (unsigned
## 32-bit wrap) since GDScript ints are 64-bit signed.
static func _hash_key(key: String) -> int:
	var hash_val := 5381
	for i in key.length():
		hash_val = (hash_val * 33 + key.unicode_at(i)) & 0xFFFFFFFF
	return hash_val

## Picks today's featured item deterministically from an array, based on
## the local date (defaults to today, see daily_date_key()). Returns null
## if `items` is empty.
static func pick_daily(items: Array, date: Dictionary = {}):
	if items.is_empty():
		return null
	return items[_hash_key(daily_date_key(date)) % items.size()]

## Yesterday's day key, for streak continuity checks.
static func previous_day_key(date_key: String) -> String:
	var parts := date_key.split("-")
	var y := parts[0].to_int()
	var m := parts[1].to_int()
	var d := parts[2].to_int()
	# Godot's Time API has no generic "add days" helper for arbitrary y/m/d
	# structs, so go through Unix time like the TS source does implicitly
	# via `new Date(y, m-1, d-1)` rolling over month/year boundaries.
	var unix_time := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12, "minute": 0, "second": 0})
	var prev_unix := unix_time - 86400
	var prev_date := Time.get_date_dict_from_unix_time(prev_unix)
	return daily_date_key(prev_date)
