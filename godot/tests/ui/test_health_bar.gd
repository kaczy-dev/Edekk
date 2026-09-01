extends GutTest
## rpg.md, feature/rpg-hud. Unit-level EventBus reactions plus one
## integration check that EnemyActor's own child EnemyHealthBar actually
## receives the right enemy_id in time for the spawn-time full-HP
## announcement — the exact ordering gotcha documented in HealthBar.gd's
## _ready() comment (children ready before their parent) would silently
## make the bar track the PLAYER's HP instead if the fix regressed.

const HealthBarScene := preload("res://scenes/ui/HealthBar.tscn")
const EnemyHealthBarScene := preload("res://scenes/ui/EnemyHealthBar.tscn")
const EnemyActorScene := preload("res://scenes/enemies/EnemyActor.tscn")

func test_player_bar_tracks_player_damaged() -> void:
	var bar: HealthBar = HealthBarScene.instantiate()
	add_child_autofree(bar)
	EventBus.player_damaged.emit(15, 20)
	assert_eq(bar.value, 15.0)
	assert_eq(bar.max_value, 20.0)

func test_enemy_bar_only_reacts_to_matching_id() -> void:
	var bar: HealthBar = EnemyHealthBarScene.instantiate()
	bar.enemy_id = "Foo"
	add_child_autofree(bar)

	EventBus.enemy_damaged.emit("Bar", 1, 10) # different enemy — ignored
	assert_eq(bar.value, 1.0, "unrelated enemy_damaged for a different id is ignored")

	EventBus.enemy_damaged.emit("Foo", 5, 10)
	assert_eq(bar.value, 5.0)
	assert_eq(bar.max_value, 10.0)

func test_enemy_bar_hides_on_matching_death() -> void:
	var bar: HealthBar = EnemyHealthBarScene.instantiate()
	bar.enemy_id = "Foo"
	add_child_autofree(bar)

	EventBus.enemy_died.emit("Bar") # different enemy — ignored
	assert_true(bar.visible)

	EventBus.enemy_died.emit("Foo")
	assert_false(bar.visible)

func test_enemy_actor_own_health_bar_gets_correct_id_and_starting_hp() -> void:
	# Regression check for the child-ready-before-parent ordering gotcha:
	# EnemyHealthBar's _ready() runs before EnemyActor's, so if enemy_id
	# filtering happened at connect-time instead of call-time, this bar
	# would still be listening for player_damaged and never update.
	var enemy: EnemyActor = EnemyActorScene.instantiate()
	add_child_autofree(enemy)
	var bar: HealthBar = enemy.get_node("EnemyHealthBar")
	assert_eq(bar.enemy_id, enemy.name, "EnemyActor._ready() sets the bar's enemy_id to its own node name")
	assert_eq(bar.max_value, 12.0, "thug.tres max_hp (12) reached the bar via the spawn-time announcement")
	assert_eq(bar.value, 12.0, "starts full, not zero, before any hit lands")
