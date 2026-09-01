extends GutTest
## rpg.md section 11 backlog ("Mapa/wskaźnik celu questa") — HUD._update_compass()
## picks the nearest active track and rotates $CompassArrow to face it;
## hidden once the nearest track reaches the "at" tier or carries no
## direction (e.g. player standing exactly on the target).

const HUDScene := preload("res://scenes/ui/HUD.tscn")

var _hud: HUD

func before_each() -> void:
	_hud = HUDScene.instantiate()
	add_child_autofree(_hud)
	await wait_process_frames(1)

func test_compass_hidden_with_no_tracks() -> void:
	_hud.update_proximity({})
	await wait_process_frames(1)
	assert_false(_hud._compass.visible)

func test_compass_visible_and_points_toward_nearest_track() -> void:
	var far_track := ProximityTrack.new("far", 500.0, Vector2.UP)
	var near_track := ProximityTrack.new("near", 50.0, Vector2.RIGHT)
	_hud.update_proximity({"quest_far": far_track, "quest_near": near_track})
	await wait_process_frames(1)
	assert_true(_hud._compass.visible)
	assert_almost_eq(_hud._compass.rotation, Vector2.RIGHT.angle(), 0.01)

func test_compass_hidden_when_nearest_track_is_at_tier() -> void:
	var at_track := ProximityTrack.new("at", 5.0, Vector2.RIGHT)
	_hud.update_proximity({"quest_at": at_track})
	await wait_process_frames(1)
	assert_false(_hud._compass.visible)
