extends GutTest
## rpg.md backlog ("Tryb nocny/patrol") — NightPatrolChallenge.gd. Redirects
## ProgressStore.save_path like test_street_ambush_spawner.gd since
## complete_night_patrol()/add_money()/add_reputation() all autosave.

const TEST_SAVE_PATH := "user://test_progress_night_patrol.json"

var _real_save_path: String
var _real_hour: int
var _challenge: NightPatrolChallenge


func before_all() -> void:
	_real_save_path = ProgressStore.save_path
	ProgressStore.save_path = TEST_SAVE_PATH


func after_all() -> void:
	ProgressStore.save_path = _real_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func before_each() -> void:
	ProgressStore.reset_progress()
	_real_hour = TimeManager.current_hour
	TimeManager.current_hour = 23 # night, per TimeManager.is_night()
	_challenge = NightPatrolChallenge.new()
	_challenge.patrol_id = "patrol_1"
	_challenge.reward_money = 100
	_challenge.reputation_zone_id = "downtown"
	_challenge.reward_reputation = 10
	add_child_autofree(_challenge)


func after_each() -> void:
	TimeManager.current_hour = _real_hour


func test_does_not_complete_while_still_night() -> void:
	TimeManager.current_hour = 2
	_challenge._on_hour_changed(2)
	assert_false(ProgressStore.is_night_patrol_completed("patrol_1"))


func test_completes_when_night_ends() -> void:
	TimeManager.current_hour = 7
	_challenge._on_hour_changed(7)
	assert_true(ProgressStore.is_night_patrol_completed("patrol_1"))


func test_pays_out_the_reward_on_completion() -> void:
	TimeManager.current_hour = 7
	_challenge._on_hour_changed(7)
	assert_eq(ProgressStore.money, 100)
	assert_eq(ProgressStore.get_reputation("downtown"), 10)


func test_does_not_pay_out_twice_across_two_nights() -> void:
	TimeManager.current_hour = 7
	_challenge._on_hour_changed(7)
	TimeManager.current_hour = 23
	_challenge._on_hour_changed(23)
	TimeManager.current_hour = 7
	_challenge._on_hour_changed(7)
	assert_eq(ProgressStore.money, 100, "the reward is granted only once, ever")


func test_never_started_at_night_does_not_complete_on_a_daytime_hour_change() -> void:
	TimeManager.current_hour = 12
	var day_challenge := NightPatrolChallenge.new()
	day_challenge.patrol_id = "patrol_2"
	add_child_autofree(day_challenge)
	day_challenge._on_hour_changed(13)
	assert_false(ProgressStore.is_night_patrol_completed("patrol_2"))
