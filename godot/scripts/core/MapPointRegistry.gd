class_name MapPointRegistry
extends RefCounted
## rpg.md section 27 ("mapa miasta", Szczecin). Same pattern as
## ItemRegistry.gd/EnemyRegistry.gd — loads every data/map_points/*.tres
## into a String -> MapPointData Dictionary. Paths listed explicitly (res://
## directory listing needs export-mode workarounds) — add a line here when a
## new POI is added to data/map_points/.

const _PATHS := [
	"res://data/map_points/waly_chrobrego.tres",
	"res://data/map_points/dzwigozaury.tres",
	"res://data/map_points/bulwary_szczecinskie.tres",
	"res://data/map_points/zamek_ksiazat_pomorskich.tres",
	"res://data/map_points/podziemne_trasy.tres",
	"res://data/map_points/park_kasprowicza.tres",
	"res://data/map_points/ogrod_rozany.tres",
]


static func load_all() -> Dictionary:
	var points := { }
	for path in _PATHS:
		var point: MapPointData = load(path)
		points[point.id] = point
	return points
