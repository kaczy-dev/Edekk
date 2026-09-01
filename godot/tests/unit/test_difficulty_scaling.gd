extends GutTest
## rpg.md section 11 backlog ("Panel trudności jako osobne ustawienie
## (obrażenia/ceny/agresywność wrogów)") — Difficulty.scaled_damage()/
## scaled_price(), the multipliers applied at the point of hit/sale rather
## than baked into EnemyData/VendingMachine.cost exports.

func test_medium_is_the_unscaled_baseline() -> void:
	assert_eq(Difficulty.scaled_damage(10, "medium"), 10)
	assert_eq(Difficulty.scaled_price(10, "medium"), 10)

func test_easy_reduces_damage_and_price() -> void:
	assert_eq(Difficulty.scaled_damage(10, "easy"), 7)
	assert_eq(Difficulty.scaled_price(20, "easy"), 17)

func test_hard_increases_damage_and_price() -> void:
	assert_eq(Difficulty.scaled_damage(10, "hard"), 14)
	assert_eq(Difficulty.scaled_price(20, "hard"), 23)

func test_explorer_zeroes_damage_but_keeps_medium_prices() -> void:
	assert_eq(Difficulty.scaled_damage(10, "explorer"), 0)
	assert_eq(Difficulty.scaled_price(20, "explorer"), 20)

func test_unknown_difficulty_falls_back_to_medium() -> void:
	assert_eq(Difficulty.scaled_damage(10, "nonexistent"), 10)
	assert_eq(Difficulty.scaled_price(10, "nonexistent"), 10)

func test_never_returns_negative() -> void:
	assert_eq(Difficulty.scaled_damage(0, "hard"), 0)
	assert_eq(Difficulty.scaled_price(0, "easy"), 0)
