extends GutTest
## rpg.md, feature/rpg-vfx. VfxSpawner is an autoload (project-wide, like
## AudioService) — these tests exercise the real singleton instance rather
## than a fresh one, since autoloads can't be instantiated standalone.
## Central claim under test: NO new node is ever created per hit (the whole
## point of pooling, per docs/ROADMAP.md's rule-7 audit finding about
## PlayerVisuals._spawn_ghost() allocating per-frame during sprints).

func test_hit_landed_activates_a_pooled_sprite_at_the_right_position() -> void:
	EventBus.hit_landed.emit(Vector2(100, 50))
	var found := false
	for child in VfxSpawner.get_children():
		if child is AnimatedSprite2D and child.visible and child.global_position == Vector2(100, 50):
			found = true
	assert_true(found, "one pooled sprite becomes visible at the hit position")

func test_pool_does_not_grow_across_many_hits() -> void:
	var initial_count := VfxSpawner.get_child_count()
	for i in range(20): # far more than POOL_SIZE (8)
		EventBus.hit_landed.emit(Vector2(i, 0))
	assert_eq(VfxSpawner.get_child_count(), initial_count, "no new node is ever created per hit — the pool just cycles")

func test_pooled_sprite_hides_itself_once_its_animation_finishes() -> void:
	EventBus.hit_landed.emit(Vector2(500, 500)) # distinct position to identify this sprite
	await wait_seconds(0.5) # 8 frames @ 24fps ≈ 0.33s, plus margin
	var still_visible := false
	for child in VfxSpawner.get_children():
		if child is AnimatedSprite2D and child.global_position == Vector2(500, 500) and child.visible:
			still_visible = true
	assert_false(still_visible, "a one-shot hit effect hides itself instead of freezing on its last frame")
