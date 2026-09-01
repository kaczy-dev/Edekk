extends GutTest
## rpg.md section 6 backlog ("Ruch uliczny / ambient AI").

const AmbientVehiclePathScene := preload("res://scenes/ambient/AmbientVehiclePath.tscn")

var _path: Path2D
var _vehicle: AmbientVehicle

func before_each() -> void:
	_path = AmbientVehiclePathScene.instantiate()
	add_child_autofree(_path)
	_vehicle = _path.get_node("AmbientVehicle")

func test_progress_advances_along_the_path() -> void:
	_vehicle.progress = 0.0
	_vehicle.speed = 60.0
	_vehicle._physics_process(0.1)
	assert_almost_eq(_vehicle.progress, 6.0, 0.01)

func test_progress_wraps_past_the_curve_length_instead_of_stopping() -> void:
	var length := _path.curve.get_baked_length()
	_vehicle.progress = length - 1.0
	_vehicle.speed = 60.0
	_vehicle._physics_process(0.1) # advances 6px, past the end
	assert_true(_vehicle.progress < length, "progress wraps back down instead of clamping at the curve's end")
	assert_almost_eq(_vehicle.progress, 5.0, 0.01)

func test_does_nothing_gracefully_without_a_parent_path() -> void:
	var orphan := AmbientVehicle.new()
	orphan.progress = 3.0
	orphan._physics_process(0.1) # get_parent() is null before add_child — must not crash
	assert_eq(orphan.progress, 3.0)
	orphan.free()
