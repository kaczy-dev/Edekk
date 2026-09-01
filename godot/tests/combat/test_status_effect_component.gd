extends GutTest
## rpg.md backlog "jednorazowe znajdźki combat" — first direct test of
## StatusEffectComponent (previously untested; only consumed indirectly
## through PlayerMovement). Uses gut's time_ params on apply_effect() to
## avoid a real awaited SceneTreeTimer where possible; expiry itself is
## exercised via _on_expired() called directly, same approach as other
## timer-driven components in this repo (StreetEventSpawner tests).

var _status: StatusEffectComponent


func before_each() -> void:
	_status = StatusEffectComponent.new()
	add_child_autofree(_status)


func test_starts_with_no_active_effect() -> void:
	assert_eq(_status.speed_multiplier, 1.0)
	assert_false(_status.paralyzed)
	assert_eq(_status.attack_damage_multiplier, 1.0)


func test_attack_boost_doubles_attack_damage_multiplier() -> void:
	_status.apply_effect(StatusEffectComponent.EffectType.ATTACK_BOOST, 5.0)
	assert_eq(_status.attack_damage_multiplier, StatusEffectComponent.ATTACK_BOOST_MULTIPLIER)
	assert_eq(_status.speed_multiplier, 1.0, "ATTACK_BOOST does not touch speed")


func test_attack_boost_expiry_resets_multiplier() -> void:
	_status.apply_effect(StatusEffectComponent.EffectType.ATTACK_BOOST, 5.0)
	_status._on_expired()
	assert_eq(_status.attack_damage_multiplier, 1.0)


func test_applying_a_new_effect_replaces_the_previous_one() -> void:
	_status.apply_effect(StatusEffectComponent.EffectType.ATTACK_BOOST, 5.0)
	_status.apply_effect(StatusEffectComponent.EffectType.SPEED_BOOST, 5.0)
	assert_eq(
		_status.attack_damage_multiplier,
		1.0,
		"applying SPEED_BOOST clears the earlier ATTACK_BOOST",
	)
	assert_eq(_status.speed_multiplier, StatusEffectComponent.SPEED_BOOST_MULTIPLIER)
