extends GutTest
## rpg.md section 27 ("mapa miasta", Szczecin) — MapPointRegistry.gd. Pure
## Resource loading, no ProgressStore/save_path involved, same shape as
## ItemRegistry/EnemyRegistry (untested at the registry level elsewhere in
## this repo, but MapPointRegistry's real-world POI content is worth
## covering directly, unlike the placeholder item/enemy sets).

const _EXPECTED_IDS := [
	"waly_chrobrego",
	"dzwigozaury",
	"bulwary_szczecinskie",
	"zamek_ksiazat_pomorskich",
	"podziemne_trasy",
	"park_kasprowicza",
	"ogrod_rozany",
]

const _VALID_CATEGORIES := ["waterfront", "history"]


func test_loads_every_expected_poi() -> void:
	var points := MapPointRegistry.load_all()
	assert_eq(points.size(), _EXPECTED_IDS.size())
	for id in _EXPECTED_IDS:
		assert_true(points.has(id), "missing POI: %s" % id)


func test_every_poi_has_complete_data() -> void:
	var points := MapPointRegistry.load_all()
	for id in points:
		var point: MapPointData = points[id]
		assert_false(point.point_name.is_empty(), "%s has no point_name" % id)
		assert_false(point.description.is_empty(), "%s has no description" % id)
		assert_false(point.icon.is_empty(), "%s has no icon" % id)
		assert_true(
			_VALID_CATEGORIES.has(point.category),
			"%s has unknown category '%s'" % [id, point.category],
		)


func test_waterfront_and_history_categories_are_both_represented() -> void:
	var points := MapPointRegistry.load_all()
	var waterfront_count := 0
	var history_count := 0
	for id in points:
		var point: MapPointData = points[id]
		if point.category == "waterfront":
			waterfront_count += 1
		elif point.category == "history":
			history_count += 1
	assert_eq(waterfront_count, 3)
	assert_eq(history_count, 4)
