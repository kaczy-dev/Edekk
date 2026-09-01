# Jedno źródło prawdy dla headless GUT runnera (rpg.md sekcja "narzędzia") —
# zamiast każda sesja/agent składa komendę Godota od nowa z pamięci.
# Wymaga zmiennej środowiskowej GODOT_BIN (ścieżka do Godot_v4.7.x-stable_win64.exe) —
# nie ma jednego stałego miejsca instalacji na tej maszynie.
#
# Użycie:
#   $env:GODOT_BIN = "C:\path\to\Godot_v4.7.2-stable_win64.exe"; .\scripts\run_godot_tests.ps1
#   .\scripts\run_godot_tests.ps1 res://tests/unit/test_weather_overlay.gd   # pojedynczy plik

param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$TestPaths
)

if (-not $env:GODOT_BIN) {
	Write-Error "GODOT_BIN nie jest ustawione - wskaz sciezke do binarki Godot 4.7 (headless-capable). Przyklad: `$env:GODOT_BIN = 'C:\...\Godot_v4.7.2-stable_win64.exe'"
	exit 1
}

$godotProjectDir = Join-Path $PSScriptRoot "..\godot"
Push-Location $godotProjectDir
try {
	if ($TestPaths.Count -gt 0) {
		$testArgs = $TestPaths | ForEach-Object { "-gtest=$_" }
		& $env:GODOT_BIN --headless --path . -s addons/gut/gut_cmdln.gd @testArgs -gexit
	} else {
		& $env:GODOT_BIN --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
	}
	$exitCode = $LASTEXITCODE
} finally {
	Pop-Location
}
exit $exitCode
