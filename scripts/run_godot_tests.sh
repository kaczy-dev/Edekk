#!/usr/bin/env bash
# Jedno źródło prawdy dla headless GUT runnera (rpg.md sekcja "narzędzia") —
# zamiast każda sesja/agent składa komendę Godota od nowa z pamięci.
# Wymaga zmiennej GODOT_BIN (ścieżka do Godot_v4.7.x-stable_win64.exe / godot4
# binarki) — nie ma jednego stałego miejsca instalacji na tej maszynie.
#
# Użycie:
#   GODOT_BIN=/path/to/Godot.exe ./scripts/run_godot_tests.sh
#   ./scripts/run_godot_tests.sh res://tests/unit/test_weather_overlay.gd   # pojedynczy plik
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_PROJECT_DIR="$(cd "$SCRIPT_DIR/../godot" && pwd)"

if [ -z "${GODOT_BIN:-}" ]; then
	echo "GODOT_BIN nie jest ustawione — wskaż ścieżkę do binarki Godot 4.7 (headless-capable)." >&2
	echo "Przykład: GODOT_BIN=\"/c/Users/you/Godot_v4.7.2-stable_win64.exe\" $0" >&2
	exit 1
fi

cd "$GODOT_PROJECT_DIR"

if [ "$#" -gt 0 ]; then
	TEST_ARGS=()
	for f in "$@"; do
		TEST_ARGS+=("-gtest=$f")
	done
	"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd "${TEST_ARGS[@]}" -gexit
else
	"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
fi
