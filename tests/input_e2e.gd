extends Node
## End-to-end steering check with real input events (keys, mouse, touch) through the main scene:
## the gull must end up on the side of the screen the player pressed. Prints "INPUT E2E PASSED n/n"
## or "INPUT E2E FAILED k/n" and exits 0 or 1. Run with:
##   godot_console --headless --path <REPO_DIR> --scene res://tests/input_e2e.tscn

var _passed: int = 0
var _total: int = 0
var _main: Node


func _ready() -> void:
	Save.enabled = false
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(10)
	_key(KEY_ENTER, true)
	await _frames(2)
	_key(KEY_ENTER, false)
	await _seconds(0.5)
	_check(GameState.phase == GameState.Phase.PLAYING, "Enter starts a run")
	var centre := get_viewport().get_visible_rect().size.x * 0.5

	_key(KEY_RIGHT, true)
	await _seconds(1.5)
	_key(KEY_RIGHT, false)
	_check(_gull_screen_x() > centre + 20.0, "holding Right puts the gull right of centre (x %.0f)" % _gull_screen_x())
	_key(KEY_A, true)
	await _seconds(2.5)
	_key(KEY_A, false)
	_check(_gull_screen_x() < centre - 20.0, "holding A puts the gull left of centre (x %.0f)" % _gull_screen_x())

	var size := get_viewport().get_visible_rect().size
	_mouse(Vector2(size.x * 0.88, size.y * 0.5))
	await _seconds(1.5)
	_check(_gull_screen_x() > centre + 20.0, "the mouse on the right puts the gull right of centre (x %.0f, target %.1f)" % [_gull_screen_x(), _main.world.target_x])
	_mouse(Vector2(size.x * 0.12, size.y * 0.5))
	await _seconds(1.5)
	_check(_gull_screen_x() < centre - 20.0, "the mouse on the left puts the gull left of centre (x %.0f, target %.1f)" % [_gull_screen_x(), _main.world.target_x])

	var start := Vector2(size.x * 0.5, size.y * 0.6)
	# Touch steering is relative to where the finger went down, so drag far enough to cross the centre.
	_touch(start, true)
	for i in 20:
		_drag(start + Vector2(i * 30.0, 0.0))
		await _frames(1)
	await _seconds(1.5)
	_check(_gull_screen_x() > centre + 20.0, "dragging a finger right puts the gull right of centre (x %.0f)" % _gull_screen_x())
	_touch(start + Vector2(570.0, 0.0), false)
	_touch(start, true)
	for i in 20:
		_drag(start - Vector2(i * 30.0, 0.0))
		await _frames(1)
	await _seconds(1.5)
	_check(_gull_screen_x() < centre - 20.0, "dragging a finger left puts the gull left of centre (x %.0f)" % _gull_screen_x())
	_touch(start - Vector2(570.0, 0.0), false)

	var failed := _total - _passed
	print(("INPUT E2E PASSED %d/%d" % [_passed, _total]) if failed == 0 else ("INPUT E2E FAILED %d/%d" % [failed, _total]))
	get_tree().quit(0 if failed == 0 else 1)


func _gull_screen_x() -> float:
	var world: GameWorld = _main.world
	return world.camera.unproject_position(world.gull.global_position).x


func _check(ok: bool, label: String) -> void:
	_total += 1
	if ok:
		_passed += 1
	print(("  ok: " if ok else "  FAILED: ") + label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _mouse(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	_push(ev)


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = pressed
	_push(ev)


func _drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.position = pos
	_push(ev)


## Pointer events go to the viewport in its own coordinates: the headless window has no real size, so
## Input.parse_input_event would map window positions through a meaningless stretch transform.
func _push(ev: InputEvent) -> void:
	get_viewport().push_input(ev, true)
