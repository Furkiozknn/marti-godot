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
	_test_collision_boxes()
	_test_flock_and_landmarks()
	_test_models()
	_test_music_loop()
	var world := GameWorld.new()
	add_child(world)
	_test_steering(world)
	_test_hit_spam(world)
	_test_hidden_pickups(world)
	_test_title_clock(world)
	world.queue_free()
	GameState.reset_run()
	GameState.phase = GameState.Phase.TITLE
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


## True when a point (boat space) is inside one of the boat's collision boxes.
func _solid(bt: BoatType, p: Vector3) -> bool:
	for b in bt.collision_boxes():
		if b.has_point(p):
			return true
	return false


func _test_collision_boxes() -> void:
	var ferry := load("res://data/boats/ferry.tres") as BoatType
	var top := 0.0
	for b in ferry.collision_boxes():
		top = maxf(top, b.end.y)
	_check(_solid(ferry, Vector3(2.0, 3.5, -1.5)), "the ferry cabin is solid")
	_check(top <= 4.5 and 5.3 - GameWorld.GY > top, "the deck simit at y 5.3 stays above the ferry cabin")
	var tanker := load("res://data/boats/tanker.tres") as BoatType
	_check(_solid(tanker, Vector3(1.9, 6.0, -13.0)), "the tanker bridge block is solid")
	var fishing := load("res://data/boats/fishing.tres") as BoatType
	_check(_solid(fishing, Vector3(0.0, 2.9, -2.2)) and _solid(fishing, Vector3(0.0, 4.5, 0.3)) and not _solid(fishing, Vector3(0.0, 2.5, 1.5)), "the fishing cabin and mast are solid where the model has them")
	var sail := load("res://data/boats/sail.tres") as BoatType
	_check(_solid(sail, Vector3(0.0, 10.0, -0.8)) and _solid(sail, Vector3(0.0, 20.0, 0.5)), "the sail and the mast are solid")


func _test_flock_and_landmarks() -> void:
	var level := Level.new()
	var spawner := LevelSpawner.new()
	for i in 6:
		spawner._flock_pattern(level, 100.0 + i)
	var ok := true
	for o in level.obstacles:
		for m in o.members:
			if m.z * o.speed > 0.0:
				ok = false
	_check(ok, "flock followers trail behind the leader (the V points where it flies)")
	for side: float in [-1.0, 1.0]:
		var front := Basis(Vector3.UP, LevelSpawner.landmark_turn(side)) * Vector3.BACK
		_check(front.dot(Vector3(-side, 0.0, 0.0)) > 0.99, "a landmark on side %d faces the water" % int(side))
	_check(GameWorld.fish_pitch(0.0) < 0.0 and GameWorld.fish_pitch(2.0) > 0.0, "fish point nose up when rising and down when falling")


func _test_models() -> void:
	var simit := Models.mesh("simit")
	_check(simit != null and simit.get_surface_count() == 1, "the simit model loads as one surface")
	if simit:
		var box := simit.get_aabb()
		_check(absf(box.size.x - 2.34) < 0.05 and box.size.z < 1.0, "the simit model stands upright (ring in the xy plane)")
		_check((simit.surface_get_material(0) as StandardMaterial3D).albedo_texture != null, "the simit model keeps its texture")
	var ferry := Models.mesh("ferry")
	_check(ferry != null and ferry.get_aabb().end.y <= 4.8, "the ferry model loads and stays under the deck simit")
	for m in ["fish", "feather", "fishing", "sail", "mosque", "galata", "maiden", "yali"]:
		_check(Models.mesh(m) != null, "model %s loads" % m)
	var rival := Gull.rival_mesh().get_aabb()
	_check(rival.size.x > 7.0 and rival.size.x < 7.4, "the rival gull spans about 7.2 units")


func _test_music_loop() -> void:
	var bars_seconds := Sound.MUSIC_BARS * 16 * Sound.STEP
	_check(absf(Sound.loop_frames() / float(Sound.RATE) - bars_seconds) < 0.001, "the music loop is exactly four bars long (no gap)")


## The chase camera looks along +z, so its right is world -x. Steering right must move the gull to the
## right of the screen, with the keys, the mouse and a finger drag.
func _test_steering(world: GameWorld) -> void:
	GameState.start_run()
	world.begin_run()
	world.target_x = 0.0
	world.steer_by(Vector2(1.0, 0.0), 0.5)
	var key_delta := world.target_x
	for i in 30:
		world._update_camera(0.05)
	var right := world.camera.global_transform.basis.x
	_check(right.dot(Vector3(key_delta, 0.0, 0.0)) > 0.0, "steer right moves the target to the camera's right")
	var size := world.get_viewport().get_visible_rect().size
	world.set_pointer_target(Vector2(size.x * 0.9, size.y * 0.5))
	_check(right.dot(Vector3(world.target_x, 0.0, 0.0)) > 0.0, "the pointer on the right half steers to the camera's right")
	var centre := world.camera.unproject_position(Vector3(0.0, world.gull_y, GameState.distance))
	var at_target := world.camera.unproject_position(Vector3(world.target_x, world.gull_y, GameState.distance))
	_check(at_target.x > centre.x, "the steering target projects right of the screen centre")
	world.target_x = 0.0
	world.touch_begin(Vector2(size.x * 0.5, size.y * 0.5))
	_check(world.target_x == 0.0, "a finger going down does not move the gull")
	world.touch_drag(Vector2(size.x * 0.6, size.y * 0.5))
	_check(right.dot(Vector3(world.target_x, 0.0, 0.0)) > 0.0, "dragging a finger right steers to the camera's right")


func _test_hit_spam(world: GameWorld) -> void:
	GameState.start_run()
	GameState.invuln = 1.0
	var lives := GameState.lives
	var sprites := world._sparks._next
	world._on_hit()
	_check(GameState.lives == lives and world._sparks._next == sprites, "a hit while blinking is ignored (no burst, no sound)")
	GameState.invuln = 0.0


func _test_hidden_pickups(world: GameWorld) -> void:
	GameState.start_run()
	GameState.distance = 500.0
	world.level.pickups.clear()
	for z: float in [490.0, 498.0, 510.0]:
		var p := Level.Pickup.new()
		p.kind = "simit"
		p.z = z
		world.level.pickups.append(p)
	world._render_pickups()
	_check(world._mm["simit"].multimesh.visible_instance_count == 2, "simit more than 3 units behind the gull are hidden")
	world._sparks.clear()
	world._sparks.burst(Vector3(0.0, 10.0, 500.0), Color.WHITE, 5, 6.0, 0.6, 7.0)
	world._sparks._process(0.016)
	_check(world._sparks.multimesh.visible_instance_count == 5, "a burst draws its sprites from the shared pool")
	for i in 20:
		world._sparks._process(0.05)
	_check(world._sparks.multimesh.visible_instance_count == 0, "burst sprites fade out and are gone")


func _test_title_clock(world: GameWorld) -> void:
	GameState.reset_run()
	GameState.phase = GameState.Phase.TITLE
	GameState.run_time = 200.0
	world._simulate(0.02)
	_check(GameState.run_time <= 60.0, "the title demo stays in the afternoon")
	_check(not Save.daily_ids("2026-10-21").is_empty() and Save.daily_ids("2026-10-21") == Save.daily_ids("2026-10-21"), "daily missions are cached per date")
