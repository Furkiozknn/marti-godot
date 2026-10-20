extends Node
## Entry point. Builds the world and the UI, maps the input actions, and runs the app flow:
## title -> run -> pause -> game over. Command-line options (after "--") are read here:
##   --auto          the bot flies (title demo, and the real run too)
##   --auto-quit     with --auto: print the final run as JSON and quit (bot test)
##   --no-save       never write user://marti_save.json
##   --lang=en|tr    override the language for this session
##   --t0=<seconds>  start the sky at a run time (120 is sunset, 175 is night)
##   --screen=name   open title, settings, pause, hud or over first (screenshots)
##   --run           start a run straight away
##   --end-after=<s> end the run after this much run time (screenshots of game over)
##   --trace         print the game state (JSON) once per second
##   --d0=<metres>   start the run this far along the strait (shows the bridge sooner)
##   --hold=<action> hold an input action for the whole session (e.g. steer_right: checks the steering)
##   --no-assets     keep the procedural models instead of the generated ones (res://assets/models)

var world: GameWorld
var ui: GameUI
var _auto_mode: bool = false
var _auto_quit: bool = false
var _end_after: float = -1.0
var _auto_timer: float = 0.0
var _over_timer: float = 0.0
var _touch_started_ms: int = 0
var _touch_start := Vector2.ZERO
var _trace: bool = false
var _t0: float = 0.0
var _d0: float = 0.0
var _trace_timer: float = 0.0


func _ready() -> void:
	_setup_input_map()
	var lang := Cli.value_of("--lang", "")
	if lang == "en" or lang == "tr":
		Save.settings["language"] = lang
	_auto_mode = Cli.has_flag("--auto")
	_auto_quit = Cli.has_flag("--auto-quit")
	_trace = Cli.has_flag("--trace")
	_t0 = float(Cli.value_of("--t0", "0"))
	_d0 = float(Cli.value_of("--d0", "0"))
	_end_after = float(Cli.value_of("--end-after", "-1"))
	Save.apply_all()
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if Save.is_low_quality() else Viewport.MSAA_2X

	world = GameWorld.new()
	world.auto_bot = _auto_mode
	world.title_clock_cap = maxf(60.0, _t0)
	add_child(world)
	ui = GameUI.new()
	add_child(ui)
	ui.set_world(world)
	ui.start_pressed.connect(start_run)
	ui.retry_pressed.connect(start_run)
	ui.restart_pressed.connect(restart_run)
	ui.resume_pressed.connect(resume_run)
	ui.menu_pressed.connect(go_menu)
	ui.pause_pressed.connect(toggle_pause)
	ui.music_pressed.connect(toggle_music)
	ui.sfx_pressed.connect(toggle_sfx)
	ui.lang_pressed.connect(toggle_language)
	ui.settings_changed.connect(_on_settings_changed)
	ui.set_music_on(Save.settings["music_on"])
	ui.set_sfx_on(Save.settings["sfx_on"])

	GameState.message.connect(_on_message)
	GameState.stat_changed.connect(Save.mission_track)
	GameState.run_ended.connect(_on_run_ended)
	Save.mission_completed.connect(_on_mission_completed)

	go_menu()
	GameState.run_time = _t0
	var screen := Cli.value_of("--screen", "title")
	match screen:
		"settings":
			ui.show_screen("settings", false)
		"hud":
			start_run()
		"pause":
			start_run()
			toggle_pause()
		"over":
			start_run()
			_end_after = maxf(_end_after, 0.5)
	if Cli.has_flag("--run"):
		start_run()
	var hold := Cli.value_of("--hold", "")
	if InputMap.has_action(hold):
		Input.action_press(hold)


func _process(delta: float) -> void:
	if _trace:
		_trace_timer += delta
		if _trace_timer >= 1.0:
			_trace_timer = 0.0
			print(GameState.get_state_text())
	if GameState.phase == GameState.Phase.PLAYING or GameState.phase == GameState.Phase.PAUSED:
		ui.update_hud()
	if GameState.phase == GameState.Phase.OVER:
		_over_timer += delta
	if GameState.phase == GameState.Phase.PLAYING and _end_after > 0.0 and GameState.run_time >= _end_after:
		GameState.end_run("crash")
	if _auto_quit and GameState.phase == GameState.Phase.PLAYING and GameState.run_time > 900.0:
		GameState.end_run("timeout")
	if _auto_mode:
		_auto_timer += delta
		if GameState.phase == GameState.Phase.TITLE and _auto_timer > 0.5:
			start_run()
		elif GameState.phase == GameState.Phase.OVER and _over_timer > 2.5 and not _auto_quit:
			start_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_music"):
		toggle_music()
	elif event.is_action_pressed("toggle_sfx"):
		toggle_sfx()
	elif event.is_action_pressed("toggle_language"):
		toggle_language()
	elif event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("dive"):
		_on_press_to_play()

	var playing := GameState.phase == GameState.Phase.PLAYING and not _auto_mode
	# Touch: a finger going down never moves the gull; dragging steers relative to where it went down,
	# and a short tap without a drag dives.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_started_ms = Time.get_ticks_msec()
			_touch_start = event.position
			world.touch_begin(event.position)
		elif Time.get_ticks_msec() - _touch_started_ms < 300 and event.position.distance_to(_touch_start) < 24.0 and playing:
			world.dive_tap()
	elif event is InputEventScreenDrag and playing:
		world.touch_drag(event.position)
	# A real mouse steers by its position and dives while the left button is held. Mouse events that
	# Godot emulates from touch are skipped, so a finger on the screen never dives or jumps the gull.
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and playing:
		world.set_pointer_target(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		world.mouse_dive = event.pressed and playing


func _on_press_to_play() -> void:
	match GameState.phase:
		GameState.Phase.TITLE:
			start_run()
		GameState.Phase.OVER:
			if _over_timer > 0.6:
				start_run()
		GameState.Phase.PLAYING:
			pass


# ---------- app flow ----------

func start_run() -> void:
	if GameState.phase == GameState.Phase.PLAYING:
		return
	GameState.start_run()
	GameState.run_time = _t0
	GameState.distance = _d0
	world.begin_run()
	world.dive_timer = 0.0
	world.mouse_dive = false
	_auto_timer = 0.0
	_over_timer = 0.0
	ui.show_screen("hud")
	Sound.set_paused(false)
	Sound.play("start")
	ui.toast(Loc.t("fly"), "info")


## Pause menu: throw the current run away and start a new one.
func restart_run() -> void:
	GameState.phase = GameState.Phase.TITLE
	start_run()


func go_menu() -> void:
	GameState.reset_run()
	GameState.phase = GameState.Phase.TITLE
	world.begin_run()
	ui.show_screen("title")
	_auto_timer = 0.0
	Sound.set_paused(false)
	Sound.start_music()


func toggle_pause() -> void:
	if GameState.phase == GameState.Phase.PLAYING:
		GameState.pause()
		world.mouse_dive = false
		Sound.set_paused(true)
		ui.show_screen("pause")
	elif GameState.phase == GameState.Phase.PAUSED:
		resume_run()


func resume_run() -> void:
	GameState.resume()
	Sound.set_paused(false)
	Save.save_all()
	ui.show_screen("hud")


## Losing the window focus (another app, a hidden browser tab) pauses a run. The bot and Movie Maker keep going.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameState.phase == GameState.Phase.PLAYING and not _auto_mode \
			and Engine.get_write_movie_path() == "":
		toggle_pause()


func _on_run_ended(run: Dictionary) -> void:
	if _auto_quit:
		print("BOT RUN " + JSON.stringify(run))
		get_tree().quit(0)
		return
	var is_new: bool = run["score"] > Save.best_score() and run["score"] > 0
	Save.record_run(run)
	Sound.play_game_over()
	ui.show_over(run, is_new)
	_over_timer = 0.0


func _on_message(key: String, tone: String) -> void:
	ui.toast(Loc.t(key), tone)


func _on_mission_completed(id: String) -> void:
	if GameState.phase == GameState.Phase.PLAYING:
		GameState.score += GameState.CONFIG.mission_bonus
	ui.toast("%s: %s" % [Loc.t("mission_done"), Save.mission_def(id).text(Loc.lang())], "good")
	Sound.play("chime", 1.0)


# ---------- settings and toggles ----------

func toggle_music() -> void:
	Save.settings["music_on"] = not Save.settings["music_on"]
	Save.save_all()
	Sound.apply_volumes()
	ui.set_music_on(Save.settings["music_on"])


func toggle_sfx() -> void:
	Save.settings["sfx_on"] = not Save.settings["sfx_on"]
	Save.save_all()
	Sound.apply_volumes()
	ui.set_sfx_on(Save.settings["sfx_on"])


func toggle_language() -> void:
	Save.settings["language"] = "en" if Loc.lang() == "tr" else "tr"
	Save.save_all()
	ui.apply_texts()


func toggle_fullscreen() -> void:
	Save.settings["fullscreen"] = not Save.settings["fullscreen"]
	_on_settings_changed()
	ui.apply_texts()


func _on_settings_changed() -> void:
	Save.save_all()
	Save.apply_display()
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if Save.is_low_quality() else Viewport.MSAA_2X
	world.apply_quality()



# ---------- input map ----------

func _setup_input_map() -> void:
	_add_action("steer_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("steer_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("steer_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("steer_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	# The mouse button is not part of the dive action: _unhandled_input handles a real mouse, so the button
	# Godot emulates from touch never dives (touch dives with a tap).
	_add_action("dive", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_add_action("pause", [_key(KEY_P), _key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_add_action("confirm", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _button(JOY_BUTTON_A)])
	_add_action("toggle_music", [_key(KEY_M)])
	_add_action("toggle_sfx", [_key(KEY_X)])
	_add_action("toggle_language", [_key(KEY_L)])
	_add_action("toggle_fullscreen", [_key(KEY_F)])


func _add_action(action_name: String, events: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.3)
	for ev in events:
		InputMap.action_add_event(action_name, ev)


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


func _button(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev
