extends GutTest
## rpg.md section 6, point 3 ("faktyczne osadzenie wroga na poziomie") —
## LevelBuilder's new "enemy" kind, and Level2's real thug1 placement.
## Level2 chosen (not L1) per docs/ROADMAP.md's hybrid decision: additive
## content on an already-tested level's data, not a background/tileset
## rebuild.

const Level2Scene := preload("res://scenes/levels/Level2.tscn")

func test_level_builder_spawns_enemy_kind_objects() -> void:
	var level := LevelData.new()
	var obj := LevelObjectData.new()
	obj.id = "test-thug"
	obj.kind = "enemy"
	obj.rect = Rect2(100, 100, 40, 40)
	obj.enemy_id = &"thug"
	level.objects = [obj]

	var parent := Node2D.new()
	add_child_autofree(parent)
	LevelBuilder.build(parent, level, [], false, {}, EnemyRegistry.load_all())

	var enemy := parent.get_node_or_null("Enemy_test-thug")
	assert_not_null(enemy, "LevelBuilder builds an EnemyActor for an 'enemy'-kind object")
	assert_true(enemy is EnemyActor)
	assert_eq((enemy as EnemyActor).enemy_data.id, &"thug")
	assert_eq(enemy.position, Vector2(120, 120), "positioned at the rect's center, same convention as items/NPCs")

func test_level_builder_warns_on_unknown_enemy_id() -> void:
	var level := LevelData.new()
	var obj := LevelObjectData.new()
	obj.id = "test-ghost"
	obj.kind = "enemy"
	obj.rect = Rect2(0, 0, 40, 40)
	obj.enemy_id = &"nonexistent"
	level.objects = [obj]

	var parent := Node2D.new()
	add_child_autofree(parent)
	LevelBuilder.build(parent, level, [], false, {}, EnemyRegistry.load_all())

	assert_null(parent.get_node_or_null("Enemy_test-ghost"), "an unresolvable enemy_id spawns nothing, not a broken node")

func test_level2_actually_spawns_its_placed_thug() -> void:
	var level := Level2Scene.instantiate()
	add_child_autofree(level)
	await wait_physics_frames(2)
	var thug := level.get_node_or_null("Enemy_thug1")
	assert_not_null(thug, "level_2.tres's thug1 object is actually built into the running level")
	if thug != null:
		assert_true(thug.is_in_group("enemy"))
