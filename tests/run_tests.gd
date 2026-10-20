extends Node
## Headless unit tests for the core rules. Prints "TESTS PASSED n/n" or "TESTS FAILED k/n" as the
## last line and exits with code 0 or 1. Run with:
##   godot_console --headless --path <REPO_DIR> --scene res://tests/run_tests.tscn

var _passed: int = 0
var _total: int = 0


func _ready() -> void:
	Save.enabled = false
	_test_combo_and_points()
	_test_hits_and_shield()
	_test_steal_and_stamina()
	_test_speed_curve()
	_test_high_scores()
	_test_daily_missions()
	_test_localisation()
	_test_resources()
	_test_spawner_and_bot()
	_test_terrain_and_mesh()
	_test_state_text()
	var failed := _total - _passed
	if failed == 0:
		print("TESTS PASSED %d/%d" % [_passed, _total])
	else:
		print("TESTS FAILED %d/%d" % [failed, _total])
	get_tree().quit(0 if failed == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		_passed += 1
	else:
		print("  FAILED: " + label)


func _test_combo_and_points() -> void:
	GameState.start_run()
	GameState.combo = 0
	_check(GameState.combo_multiplier() == 1, "combo 0 gives x1")
	GameState.combo = 4
	_check(GameState.combo_multiplier() == 2, "combo 4 gives x2")
	GameState.combo = 16
	_check(GameState.combo_multiplier() == 5, "multiplier is capped at x5")
	GameState.combo = 0
	_check(GameState.collect_simit() == 10, "first simit is worth 10 points")
	GameState.combo = 4
	_check(GameState.collect_simit() == 20, "simit at combo 5 is worth 20 points")
	GameState.combo = 0
	GameState.tail_timer = 5.0
	_check(GameState.pickup_points(10) == 15, "tailwind gives x1.5")
	GameState.tail_timer = 0.0


func _test_hits_and_shield() -> void:
	GameState.start_run()
	GameState.shield = true
	_check(GameState.take_hit(), "shield absorbs the first hit")
	_check(GameState.lives == GameState.CONFIG.lives and not GameState.shield, "shield is used up and lives are kept")
	GameState.invuln = 0.0
	GameState.combo = 5
	_check(not GameState.take_hit(), "a hit without shield is not absorbed")
	_check(GameState.lives == GameState.CONFIG.lives - 1 and GameState.combo == 0, "a hit costs a life and resets the combo")
	GameState.invuln = 1.0
	_check(GameState.take_hit(), "invulnerability blocks a hit")
	GameState.invuln = 0.0
	GameState.take_hit()
	GameState.invuln = 0.0
	GameState.take_hit()
	_check(GameState.phase == GameState.Phase.OVER, "the last life ends the run")
	_check(GameState.last_run.get("reason", "") == "crash", "the run ends with reason crash")


func _test_steal_and_stamina() -> void:
	GameState.start_run()
	GameState.stamina = 50.0
	GameState.combo = 3
	GameState.steal_food()
	_check(is_equal_approx(GameState.stamina, 50.0 - GameState.CONFIG.steal_cost), "a steal costs stamina")
	_check(GameState.combo == 0, "a steal resets the combo")
	GameState.stamina = 10.0
	GameState.steal_food()
	_check(GameState.phase == GameState.Phase.OVER and GameState.last_run.get("reason", "") == "energy", "running out of stamina ends the run")


func _test_speed_curve() -> void:
	_check(is_equal_approx(GameState.base_speed(0.0), 27.0), "speed starts at 27")
	_check(GameState.base_speed(1000.0) > 55.0, "speed approaches 58")
	_check(GameState.difficulty() >= 0.0 and GameState.difficulty() <= 1.0, "difficulty stays between 0 and 1")


func _test_high_scores() -> void:
	var list: Array = []
	for s in [50, 300, 120, 80, 999, 10]:
		list = Save.insert_high(list, {"score": s, "dist": 0, "simit": 0}, 5)
	_check(list.size() == 5, "only the top five scores are kept")
	_check(list[0]["score"] == 999, "the highest score comes first")
	_check(list[4]["score"] == 50, "the lowest kept score is 50")


func _test_daily_missions() -> void:
	var ids: Array = Save.daily_ids("2026-10-20")
	_check(ids.size() == 3, "three daily missions")
	_check(ids == Save.daily_ids("2026-10-20"), "the same date gives the same missions")
	_check(Save.mission_def("simit").goal == 60, "simit mission goal is 60")
	Save.missions = {}
	var id: String = Save.daily_ids(Save.today_key())[0]
	var def := Save.mission_def(id)
	Save.mission_track(def.stat, float(def.goal), def.stat == "combo")
	_check(Save.mission_done(id), "reaching the goal completes a daily mission")


func _test_localisation() -> void:
	var saved: String = Save.settings["language"]
	Save.settings["language"] = "tr"
	_check(Loc.t("start") == "Başla", "Turkish start label")
	Save.settings["language"] = "en"
	_check(Loc.t("start") == "Start", "English start label")
	_check(Loc.format_distance(1500.0) == "1.50 km", "long distances are shown in km")
	Save.settings["language"] = saved


func _test_resources() -> void:
	_check(LevelSpawner.BOAT_TYPES.size() == 4, "four boat types load")
	_check(Save.MISSION_RES.size() == 5, "five missions load")
	_check(GameState.CONFIG.lives == 3, "game config loads")
	_check(GameState.CONFIG.corridor > 0.0, "corridor is configured")


func _test_spawner_and_bot() -> void:
	var level := Level.new()
	var spawner := LevelSpawner.new()
	spawner.fill_ahead(level, 0.0, 0.0, 340.0)
	_check(level.props.size() > 0, "shore props are spawned")
	_check(level.pickups.size() > 0, "pickups are spawned")
	var lane := Bot.choose(level, 0.0, Vector2(0.0, 12.0))
	_check(absf(lane.x) <= 20.0, "bot lane is inside the corridor")
	_check(lane.y >= 2.4 and lane.y <= 33.0, "bot lane is inside the height limits")
	_check(level.cull(-1000.0).is_empty(), "nothing is culled far behind the gull")


func _test_terrain_and_mesh() -> void:
	_check(Level.terrain_height(0.0, 100.0) == 0.0, "the sea is flat in the middle")
	_check(Level.terrain_height(100.0, 0.0) > 0.0, "the land rises away from the shore")
	var boat := load("res://data/boats/ferry.tres") as BoatType
	_check(boat.build_mesh().get_surface_count() == 1, "a boat is built as one surface")
	_check(BridgeGeometry.shared_mesh().get_surface_count() == 1, "the bridge is built as one surface")


func _test_state_text() -> void:
	var parsed: Variant = JSON.parse_string(GameState.get_state_text())
	_check(typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("score"), "state text is a JSON object with a score")
