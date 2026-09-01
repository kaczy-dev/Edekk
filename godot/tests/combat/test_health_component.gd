extends GutTest
## rpg.md, feature/rpg-stats — first test of the combat pion. HealthComponent
## is deliberately dumb (see its header): no defense math, so these tests
## only exercise take_damage()/health_changed/died directly, not a full
## attacker-vs-defender resolution (that's feature/rpg-combat's job).

var _health: HealthComponent

func before_each() -> void:
	_health = HealthComponent.new()
	_health.max_hp = 10
	add_child_autofree(_health)

func test_starts_at_max_hp() -> void:
	assert_eq(_health.current_hp, 10, "current_hp initializes to max_hp in _ready()")
	assert_false(_health.is_dead(), "fresh HealthComponent is not dead")

func test_take_damage_reduces_hp_and_emits_health_changed() -> void:
	watch_signals(_health)
	_health.take_damage(3)
	assert_eq(_health.current_hp, 7, "take_damage(3) reduces current_hp by 3")
	assert_signal_emitted_with_parameters(_health, "health_changed", [7, 10])

func test_take_damage_clamps_at_zero_not_negative() -> void:
	_health.take_damage(999)
	assert_eq(_health.current_hp, 0, "overkill damage clamps to 0, not negative")

func test_take_damage_to_zero_emits_died() -> void:
	watch_signals(_health)
	_health.take_damage(10)
	assert_signal_emitted(_health, "died", "died fires exactly when current_hp reaches 0")
	assert_true(_health.is_dead())

func test_died_not_emitted_while_hp_remains() -> void:
	watch_signals(_health)
	_health.take_damage(1)
	assert_signal_not_emitted(_health, "died", "died must not fire while HP > 0")

func test_take_damage_after_death_is_a_noop() -> void:
	_health.take_damage(10)
	watch_signals(_health)
	_health.take_damage(5)
	assert_signal_not_emitted(_health, "health_changed", "no further health_changed once dead")
	assert_eq(_health.current_hp, 0)

func test_configure_sets_max_and_resets_current() -> void:
	_health.take_damage(4)
	watch_signals(_health)
	_health.configure(20)
	assert_eq(_health.max_hp, 20)
	assert_eq(_health.current_hp, 20, "configure() resets current_hp to the new max, not just max_hp")
	assert_signal_emitted_with_parameters(_health, "health_changed", [20, 20])

func test_zero_or_negative_damage_is_a_noop() -> void:
	watch_signals(_health)
	_health.take_damage(0)
	_health.take_damage(-5)
	assert_eq(_health.current_hp, 10, "non-positive damage does not change HP")
	assert_signal_not_emitted(_health, "health_changed")
