# import_assets.ps1 -- batch asset import helper (plan31-08.md, "principal
# lead" review point 7).
#
# Problem this replaces: every new texture this session (TopDownHouse_*.png,
# x3) needed manual `cp` into godot/assets/... followed by launching the
# full Godot editor through MCP and polling .godot/ until a .import file
# appeared, just to get one file recognized. Fine for one file at a time;
# tedious for a whole folder of assets for a future interior level.
#
# What this does: copies every file from -Source into -Dest (relative to
# godot/assets/), then runs Godot once in `--headless --editor --quit`
# mode -- the documented CI pattern for forcing a one-time import pass
# without keeping a persistent editor session open (this is exactly what
# this session's MCP `launch_editor` + poll-then-close dance was
# accomplishing by hand, just automated and file-folder-scoped instead of
# one MCP round-trip per file).
#
# Usage:
#   .\godot\tools\import_assets.ps1 -Source "C:\path\to\new\assets" -Dest "textures\interior2" [-GodotExe "C:\path\to\Godot.exe"]
#
# -GodotExe defaults to the path this session used
# (C:\Users\catsy\OneDrive\Pulpit\Godot_v4.7.2-stable_win64.exe) -- override
# it if Godot lives somewhere else on a future machine/CI runner.

param(
	[Parameter(Mandatory=$true)]
	[string]$Source,

	[Parameter(Mandatory=$true)]
	[string]$Dest,

	[string]$GodotExe = "C:\Users\catsy\OneDrive\Pulpit\Godot_v4.7.2-stable_win64.exe"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotProjectDir = Split-Path -Parent $scriptDir  # godot/tools/.. = godot/
$destPath = Join-Path (Join-Path $godotProjectDir "assets") $Dest

if (-not (Test-Path $Source)) {
	throw "Source folder not found: $Source"
}
if (-not (Test-Path $GodotExe)) {
	throw "Godot executable not found: $GodotExe (pass -GodotExe to override)"
}

New-Item -ItemType Directory -Force -Path $destPath | Out-Null

$copied = @()
Get-ChildItem -Path (Join-Path $Source "*") -File -Include *.png,*.jpg,*.jpeg,*.svg,*.wav,*.ogg | ForEach-Object {
	Copy-Item -Path $_.FullName -Destination $destPath -Force
	$copied += $_.Name
}

if ($copied.Count -eq 0) {
	Write-Output "No matching asset files (.png/.jpg/.jpeg/.svg/.wav/.ogg) found in $Source -- nothing to import."
	exit 0
}

Write-Output "Copied $($copied.Count) file(s) to $destPath :"
$copied | ForEach-Object { Write-Output "  - $_" }

Write-Output "`nRunning Godot headless import pass (this can take a few seconds)..."
# --import is the dedicated flag for this (per `godot --help`): starts the
# editor, waits for the resource import queue to actually finish, then
# quits. `--editor --quit` (tried first) exits after one iteration
# regardless of whether importing has finished, so it produced no .import
# files at all in testing.
& $GodotExe --headless --import --path $godotProjectDir
Write-Output "Import pass complete."
