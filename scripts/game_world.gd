class_name GameWorld
extends Node3D
## The 3D scene and the simulation: sea, land, sky, the gull, the camera, spawning, collisions and
## pickups. Repeated objects (props, simit, fish, kites, flock birds) are MultiMeshes, so each kind
## costs one draw call. Water and land are vertex-shader surfaces with no per-frame CPU mesh updates.

signal popup(text: String, pos: Vector3)

const GX := 1.0
const GY := 0.55
const GZ := 1.3
const WATER_LEN := 560.0
const WATER_BACK := 60.0
## Day cycle keys, by run progress p (0 = morning, 0.7 = sunset, 1.0 = night).
## Each row: p, sun elevation (degrees), sun colour, zenith, horizon, ambient colour, ambient energy,
## sun energy, star amount. The sky, sun, fog and ambient light are blended between rows.
const SKY_KEYS := [
	[0.0, 52.0, "#FFF3D6", "#2D6DB5", "#BCE0F2", "#DDEBF5", 0.55, 1.0, 0.0],
	[0.4, 30.0, "#FFF1CC", "#2A64AE", "#B5DCEF", "#E9E6D8", 0.5, 1.0, 0.0],
	[0.6, 12.0, "#FFC985", "#3A62A8", "#F4C48F", "#F2D2B0", 0.42, 0.85, 0.0],
	[0.7, 0.0, "#FF9A55", "#5A5CB0", "#FF8A4C", "#E9A987", 0.36, 0.55, 0.0],
	[0.77, -5.0, "#FF6A4A", "#3B3778", "#E65F5C", "#9C7090", 0.36, 0.0, 0.25],
	[0.85, -11.0, "#7E8CFF", "#161C48", "#2E3366", "#4A5C9E", 0.5, 0.0, 0.7],
	[1.0, -15.0, "#9AA8FF", "#060A1F", "#151B42", "#4B5FA8", 0.55, 0.0, 1.0],
]
const MM_CAPACITY := {
	"house": 340, "roof": 340, "tree": 260, "dome": 40, "minaret": 80, "balloon": 24, "cloud": 60,
	"simit": 200, "fish": 60, "kite": 24, "kite_string": 24, "flock": 120,
}
const PROP_KINDS := ["house", "roof", "tree", "dome", "minaret", "balloon", "cloud"]
## Puffs (x, y, z, radius) of the cloud shapes. Props are scaled by their size; storms use the full size.
const CLOUD_PUFFS := [[0.0, 0.0, 0.0, 0.3], [-0.25, -0.05, 0.05, 0.22], [0.24, 0.02, -0.04, 0.24], [0.02, 0.14, 0.02, 0.2]]
const STORM_PUFFS := [[0.0, 0.0, 0.0, 5.0], [-5.5, -1.0, 1.0, 3.6], [5.2, -0.8, -0.8, 3.9], [-1.8, 3.0, 0.6, 3.4],
	[2.6, -2.6, 1.6, 3.0], [-8.2, -2.0, -0.6, 2.4], [8.6, -1.8, 0.9, 2.2], [0.5, -0.4, -3.8, 2.8]]
const WATER_SHADER := """
shader_type spatial;
uniform float wave_time = 0.0;
uniform vec3 deep_col : source_color = vec3(0.02, 0.17, 0.27);
uniform vec3 shallow_col : source_color = vec3(0.06, 0.3, 0.4);
uniform vec3 sky_col : source_color = vec3(0.7, 0.85, 0.95);
varying float wave_h;

float wave(vec2 p, float t) {
	return 0.45 * sin(p.x * 0.21 + t * 1.1) + 0.35 * sin(p.y * 0.17 - t * 1.6 + p.x * 0.05) + 0.18 * sin(p.x * 0.6 + p.y * 0.45 + t * 2.4);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave_h = wave(wp.xz, wave_time);
	VERTEX.y += wave_h;
	float e = 0.5;
	float dx = wave(wp.xz + vec2(e, 0.0), wave_time) - wave(wp.xz - vec2(e, 0.0), wave_time);
	float dz = wave(wp.xz + vec2(0.0, e), wave_time) - wave(wp.xz - vec2(0.0, e), wave_time);
	NORMAL = normalize(vec3(-dx / (2.0 * e), 1.0, -dz / (2.0 * e)));
}

void fragment() {
	float k = clamp((wave_h + 1.0) / 2.2, 0.0, 1.0);
	// Grazing angles reflect the sky, so the far sea turns pale and the near sea stays deep.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	vec3 base = mix(deep_col, shallow_col, k);
	ALBEDO = mix(base, sky_col * 0.8, fres * 0.7);
	ROUGHNESS = 0.14;
	SPECULAR = 0.5;
}
"""
const LAND_SHADER := """
shader_type spatial;
uniform vec3 sand : source_color = vec3(0.78, 0.66, 0.42);
uniform vec3 grass : source_color = vec3(0.37, 0.54, 0.24);
uniform vec3 hill : source_color = vec3(0.25, 0.42, 0.22);
varying float ground_h;

float terrain(vec2 p) {
	float ax = abs(p.x);
	float edge = max(0.0, ax - 30.0);
	float base = min(edge * 0.22, 16.0);
	float s = sin(p.y * 0.021 + ax * 0.045);
	float bumps = 4.2 * s * s + 2.2 * sin(p.y * 0.067 - ax * 0.13 + 1.3);
	return max(0.0, base + max(0.0, bumps) * min(1.0, edge / 10.0));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_h = terrain(wp.xz);
	VERTEX.y += ground_h;
	float e = 0.6;
	float dx = terrain(wp.xz + vec2(e, 0.0)) - terrain(wp.xz - vec2(e, 0.0));
	float dz = terrain(wp.xz + vec2(0.0, e)) - terrain(wp.xz - vec2(0.0, e));
	NORMAL = normalize(vec3(-dx / (2.0 * e), 1.0, -dz / (2.0 * e)));
}

void fragment() {
	vec3 c = mix(sand, grass, clamp(ground_h / 1.2, 0.0, 1.0));
	ALBEDO = mix(c, hill, clamp((ground_h - 5.0) / 10.0, 0.0, 1.0));
	ROUGHNESS = 0.9;
}
"""
## Sky dome: a vertical gradient from horizon to zenith, a sun disc with glow, a moon and stars.
const SKY_SHADER := """
shader_type sky;
uniform vec3 zenith_col : source_color = vec3(0.2, 0.4, 0.7);
uniform vec3 horizon_col : source_color = vec3(0.7, 0.85, 0.95);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float sun_vis = 1.0;
uniform float star_amount = 0.0;
uniform vec3 moon_dir = vec3(0.0, 1.0, 0.0);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col = mix(horizon_col, zenith_col, pow(clamp(d.y, 0.0, 1.0), 0.55));
	float sd = max(dot(d, sun_dir), 0.0);
	col += sun_col * (pow(sd, 6.0) * 0.16 + pow(sd, 90.0) * 0.3) * sun_vis;
	col = mix(col, sun_col * 1.5, smoothstep(0.99935, 0.9996, dot(d, sun_dir)) * sun_vis);
	col = mix(col, vec3(0.8, 0.85, 0.95), smoothstep(0.9993, 0.9996, dot(d, moon_dir)) * star_amount);
	if (star_amount > 0.0 && d.y > 0.02) {
		float r = hash(floor(d * 300.0));
		col += vec3(step(0.991, r) * star_amount * (0.5 + (r - 0.991) * 60.0));
	}
	COLOR = col;
}
"""

## Set by main: true when the bot drives the gull even during a real run (--auto).
var auto_bot: bool = false
var level := Level.new()
var spawner := LevelSpawner.new()
var bot := Bot.new()
var gull_x: float = 0.0
var gull_y: float = 12.0
var target_x: float = 0.0
var target_y: float = 12.0
var dive_timer: float = 0.0
var camera: Camera3D
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var water: MeshInstance3D
var water_mat: ShaderMaterial
var gull: Gull

var _low: bool = false
var _fx_scale: float = 1.0
var _time: float = 0.0
var _dive_offset: float = 0.0
var _gust := Vector2.ZERO
var _shake: float = 0.0
var _bank: float = 0.0
var _velocity := Vector2.ZERO
var _cull_timer: float = 0.0
var _mm: Dictionary = {}
var _boat_meshes: Dictionary = {}
var _power_nodes_mesh: Dictionary = {}
var _sky_keys: Array = []
var _storm_mesh: ArrayMesh
var _house_mat: StandardMaterial3D
var _land_left: MeshInstance3D
var _land_right: MeshInstance3D


func _ready() -> void:
	_low = Save.is_low_quality()
	_fx_scale = 0.5 if _low else 1.0
	for key in SKY_KEYS:
		_sky_keys.append([key[0], key[1], Color.html(key[2]), Color.html(key[3]), Color.html(key[4]),
			Color.html(key[5]), key[6], key[7], key[8]])
	_build_environment()
	_build_sea()
	_build_sky()
	_build_multimeshes()
	gull = Gull.new()
	gull.scale = Vector3.ONE * 1.0
	add_child(gull)
	gull.flapped.connect(_on_flap)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.5
	camera.far = 950.0
	add_child(camera)
	camera.current = true
	begin_run()
	apply_quality()


## Called by main at the start of every run, and when the menu restores the title scene.
func begin_run() -> void:
	_free_nodes(level.clear())
	gull_x = 0.0
	gull_y = 12.0
	target_x = 0.0
	target_y = 12.0
	_dive_offset = 0.0
	_gust = Vector2.ZERO
	spawner.fill_ahead(level, GameState.distance, GameState.run_time, GameState.CONFIG.look_ahead)


## Applies the quality tier: low = 1024 hard shadows, no glow, fewer particles.
func apply_quality() -> void:
	_low = Save.is_low_quality()
	_fx_scale = 0.5 if _low else 1.0
	env.glow_enabled = not _low
	gull.set_trail(not _low)
	for mmi in _mm.values():
		(mmi as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for kind in PROP_KINDS:
		_mm[kind].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Steering from the mouse or a finger: the gull follows the pointer across the strait.
func set_pointer_target(screen_pos: Vector2) -> void:
	var size := get_viewport().get_visible_rect().size
	var cfg := GameState.CONFIG
	target_x = clampf(screen_pos.x / size.x * 2.0 - 1.0, -1.0, 1.0) * cfg.corridor
	target_y = lerpf(cfg.max_height, 3.0, clampf(screen_pos.y / size.y, 0.0, 1.0))


func dive_tap() -> void:
	dive_timer = 0.8


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time += dt
	water_mat.set_shader_parameter("wave_time", _time)
	if GameState.phase == GameState.Phase.PAUSED:
		return
	var sim_dt := dt * (0.4 if GameState.phase == GameState.Phase.OVER else 1.0)
	_simulate(sim_dt)
	_render(sim_dt)


# ---------- simulation ----------

func _simulate(dt: float) -> void:
	var playing := GameState.phase == GameState.Phase.PLAYING
	var cfg := GameState.CONFIG
	dive_timer = maxf(0.0, dive_timer - dt)
	GameState.tick(dt)

	if playing and not auto_bot:
		_keyboard_steer(dt)
	else:
		var lane := bot.think(dt, level, GameState.distance, Vector2(gull_x, gull_y))
		target_x = lane.x
		target_y = lane.y

	var diving := playing and not auto_bot and (Input.is_action_pressed("dive") or dive_timer > 0.0)
	_dive_offset += ((-9.0 if diving else 0.0) - _dive_offset) * minf(1.0, dt * 5.0)
	target_y = clampf(target_y, cfg.min_height, cfg.max_height)
	var ty := clampf(target_y + _dive_offset, cfg.min_height - 1.0, cfg.max_height)
	_gust *= exp(-dt * 1.5)
	var px := gull_x
	var py := gull_y
	gull_x = clampf(gull_x + (target_x - gull_x) * minf(1.0, dt * 6.5) + _gust.x * dt, -cfg.corridor, cfg.corridor)
	gull_y = clampf(gull_y + (ty - gull_y) * minf(1.0, dt * 6.0) + _gust.y * dt, cfg.min_height - 1.0, cfg.max_height)
	if dt > 0.0:
		_velocity = Vector2((gull_x - px) / dt, (gull_y - py) / dt)

	spawner.fill_ahead(level, GameState.distance, GameState.run_time, cfg.look_ahead)
	_move_entities(dt)

	if playing:
		_check_hits()
	if GameState.phase == GameState.Phase.PLAYING:
		_check_flock_steals()
	if GameState.phase == GameState.Phase.PLAYING:
		_check_pickups()
	if GameState.phase == GameState.Phase.PLAYING:
		GameState.drain_stamina(dt, diving)
		if diving and gull_y < 2.6 and randf() < dt * 6.0:
			Fx.burst(self, Vector3(gull_x, 0.4, GameState.distance), Color.html("#E0F2FE"), _amount(3), 5.0, 0.6, 9.0)
		if randf() < dt * 0.1:
			Sound.play("call")

	_cull_timer -= dt
	if _cull_timer <= 0.0:
		_cull_timer = 0.25
		_free_nodes(level.cull(GameState.distance - cfg.keep_behind))
	_shake = maxf(0.0, _shake - dt * 2.4)


func _keyboard_steer(dt: float) -> void:
	var cfg := GameState.CONFIG
	var axis := Input.get_vector("steer_left", "steer_right", "steer_down", "steer_up")
	target_x = clampf(target_x + axis.x * dt * 18.0, -cfg.corridor, cfg.corridor)
	target_y = clampf(target_y + axis.y * dt * 16.0, cfg.min_height, cfg.max_height)


func _move_entities(dt: float) -> void:
	for p in level.pickups:
		if p.follow:
			p.z = p.follow.z + p.follow_offset
	for o in level.obstacles:
		match o.kind:
			"boat":
				o.z += o.speed * dt
			"flock":
				o.z += o.speed * dt
				o.x += sin(_time * 0.6 + o.phase) * dt * 2.0
			"kite":
				o.sway = o.x + sin(_time * 0.8 + o.phase) * 1.5
			"storm":
				o.sway = o.x + sin(_time * 0.3 + o.phase) * 5.0 * o.speed


func _check_hits() -> void:
	var d := GameState.distance
	for b in Bot.hazard_boxes(level):
		if b.kind == "flock":
			continue
		var hit := false
		if b.kind == "cable":
			hit = absf(gull_x) <= BridgeGeometry.TOWER_X and absf(d - b.z) < 3.1 + GZ \
				and absf(gull_y - BridgeGeometry.cable_y(gull_x)) < 1.5 + GY
		else:
			hit = absf(gull_x - b.x) < b.hw + GX and gull_y + GY > b.y0 and gull_y - GY < b.y1 \
				and absf(d - b.z) < b.hd + GZ
		if hit:
			_on_hit()
			return
	for o in level.obstacles:
		if o.kind == "storm" and absf(d - o.z) < 16.0 and absf(gull_x - o.sway) < 13.0 and absf(gull_y - o.y) < 8.0:
			_gust = Vector2(sin(_time * 2.2 + o.phase) * 9.0, cos(_time * 1.7 + o.phase) * 4.0)
			if randf() < 0.08 * _fx_scale:
				Fx.burst(self, Vector3(gull_x + randf_range(-6.0, 6.0), gull_y + randf_range(2.0, 8.0), d), Color.html("#93C5FD"), 3, 4.0, 0.5, 4.0)


func _on_hit() -> void:
	if GameState.take_hit():
		Fx.burst(self, Vector3(gull_x, gull_y, GameState.distance), Color.html("#E0F2FE"), _amount(16), 7.0, 0.9, 6.0)
		Sound.play("hit", 0.7)
		return
	_shake = 0.9
	target_x = clampf(target_x + (-5.0 if gull_x > 0.0 else 5.0), -GameState.CONFIG.corridor, GameState.CONFIG.corridor)
	Fx.burst(self, Vector3(gull_x, gull_y, GameState.distance), Color.WHITE, _amount(22), 9.0, 1.1, 9.0)
	Sound.play("hit")


func _check_flock_steals() -> void:
	var d := GameState.distance
	for o in level.obstacles:
		if o.kind != "flock" or not o.hostile:
			continue
		for i in range(o.members.size() - 1, -1, -1):
			var m := o.members[i]
			var mx := o.x + m.x
			var my := o.y + m.y
			var mz := o.z + m.z
			if absf(mz - d) < 2.4 and absf(mx - gull_x) < 2.4 and absf(my - gull_y) < 2.4:
				o.members.remove_at(i)
				Fx.burst(self, Vector3(mx, my, mz), Color.html("#F59E0B"), _amount(12), 6.0, 0.7, 6.0)
				GameState.steal_food()
				Sound.play("steal")
				if GameState.phase != GameState.Phase.PLAYING:
					return


func _check_pickups() -> void:
	var d := GameState.distance
	for p in level.pickups:
		if p.dead:
			continue
		match p.kind:
			"simit":
				if absf(p.z - d) < 2.4 and absf(p.x - gull_x) < 2.4 and absf(p.y - gull_y) < 2.4:
					p.dead = true
					var pts := GameState.collect_simit()
					Sound.play("chime", pow(2.0, float(GameState.combo % 12) / 12.0))
					Fx.burst(self, Vector3(p.x, p.y, p.z), Color.html("#FDE68A"), _amount(10), 6.0, 0.6, 7.0)
					popup.emit("+%d" % pts, Vector3(p.x, p.y + 1.0, p.z))
			"fish":
				var u := (d - p.fish_start) / p.fish_length
				if u < 0.0 or u > 1.5:
					continue
				var fy := _fish_y(p, u)
				if absf(p.z - d) < 3.2 and absf(p.x - gull_x) < 2.7 and absf(fy - gull_y) < 2.7:
					p.dead = true
					var pts := GameState.collect_fish()
					Sound.play("chime", pow(2.0, float(GameState.combo % 12) / 12.0))
					Fx.burst(self, Vector3(p.x, fy, p.z), Color.html("#BAE6FD"), _amount(14), 8.0, 0.7, 9.0)
					popup.emit("+%d" % pts, Vector3(p.x, fy + 1.0, p.z))
			_:
				if absf(p.z - d) < 2.8 and absf(p.x - gull_x) < 2.8 and absf(p.y - gull_y) < 2.8:
					p.dead = true
					GameState.collect_power(p.kind)
					var color := Color.html("#6EE7B7")
					if p.kind == "shield":
						color = Color.html("#E0F2FE")
					elif p.kind == "gold":
						color = Color.html("#FBBF24")
					Fx.burst(self, Vector3(p.x, p.y, p.z), color, _amount(26), 10.0, 0.9, 4.0)
					Sound.play("whoosh")
					popup.emit("+%d" % GameState.CONFIG.power_points, Vector3(p.x, p.y + 1.5, p.z))
					_free_node(p.node)
					p.node = null


func _fish_y(p: Level.Pickup, u: float) -> float:
	var c := clampf(u, 0.0, 2.0)
	if c <= 1.0:
		return p.fish_peak * sin(c * PI / 2.0)
	return p.fish_peak * cos((c - 1.0) * PI / 2.0)


func _amount(n: int) -> int:
	return maxi(1, roundi(n * _fx_scale))


func _on_flap() -> void:
	if GameState.phase == GameState.Phase.PLAYING:
		Sound.play("flap")


# ---------- rendering ----------

func _render(dt: float) -> void:
	var d := GameState.distance
	var playing := GameState.phase == GameState.Phase.PLAYING
	var p := clampf(GameState.run_time / 170.0, 0.0, 1.0)
	var night := _smooth(0.6, 0.78, p)
	var diving := playing and not auto_bot and (Input.is_action_pressed("dive") or dive_timer > 0.0)

	water.position.z = d + WATER_LEN * 0.5 - WATER_BACK
	for land in [_land_left, _land_right]:
		land.position.z = water.position.z

	_render_props(night)
	_render_boats_and_storms()
	_render_pickups()
	_render_kites_and_flock()

	var pitch := 0.5 if diving else clampf(-_velocity.y * 0.03, -0.35, 0.35)
	_bank += (clampf(_velocity.x * 0.05, -0.7, 0.7) - _bank) * minf(1.0, dt * 8.0)
	gull.position = Vector3(gull_x, gull_y, d)
	gull.visible = not (GameState.invuln > 0.0 and int(_time * 12.0) % 2 == 0 and playing)
	gull.animate(dt, diving, GameState.speed / 40.0, _bank, pitch)
	if playing and not auto_bot and diving and gull_y < 3.0 and randf() < dt * 8.0:
		Fx.burst(self, Vector3(gull_x, 0.3, d), Color.html("#E0F2FE"), _amount(6), 4.0, 0.5, 9.0)

	_update_camera(dt)
	_update_sky(p, night, d)

	if playing and p > 0.7 and night > 0.2 and randf() < dt * 0.9:
		_fireworks(d)


func _update_camera(dt: float) -> void:
	var shake := _shake * _shake * 1.1
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	# In portrait the camera stays on the gull, so the wings never leave the narrow screen.
	var follow := 1.0 if aspect < 0.9 else 0.85
	var tgt_x := gull_x * follow + randf_range(-shake, shake)
	var tgt_y := 7.5 + gull_y * 0.5 + randf_range(-shake, shake) * 0.6
	var tgt_z := GameState.distance - 19.0
	camera.position.x += (tgt_x - camera.position.x) * minf(1.0, dt * 6.0)
	camera.position.y += (tgt_y - camera.position.y) * minf(1.0, dt * 6.0)
	camera.position.z = tgt_z
	camera.look_at(Vector3(gull_x * follow, gull_y * 0.8 + 1.2, GameState.distance + 14.0), Vector3.UP)
	var fov_want := 58.0 + maxf(0.0, 0.9 - aspect) * 45.0 + maxf(0.0, GameState.speed - 30.0) * 0.25 + (6.0 if GameState.tail_timer > 0.0 else 0.0)
	if absf(camera.fov - fov_want) > 0.05:
		camera.fov += (fov_want - camera.fov) * minf(1.0, dt * 3.0)


## Blends the day cycle keys at run progress p: sky, sun angle and colour, fog, ambient light.
func _update_sky(p: float, night: float, d: float) -> void:
	var k := _sky_at(p)
	var elev: float = k["elev"]
	var sun_dir := (Vector3(0.3, 0.0, 1.0).normalized() * cos(deg_to_rad(elev)) + Vector3.UP * sin(deg_to_rad(elev))).normalized()
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP)
	sun.light_color = k["sun"]
	sun.light_energy = k["sun_energy"]
	env.ambient_light_color = k["ambient"]
	env.ambient_light_energy = k["ambient_energy"]
	env.fog_light_color = k["horizon"]
	sky_mat.set_shader_parameter("zenith_col", k["zenith"])
	sky_mat.set_shader_parameter("horizon_col", k["horizon"])
	sky_mat.set_shader_parameter("sun_col", k["sun"])
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("sun_vis", clampf((elev + 3.0) / 6.0, 0.0, 1.0))
	sky_mat.set_shader_parameter("star_amount", k["stars"])
	sky_mat.set_shader_parameter("moon_dir", Vector3(-0.35, 0.55, 0.75).normalized())
	water_mat.set_shader_parameter("sky_col", k["horizon"])
	_house_mat.emission_enabled = night > 0.01
	_house_mat.emission = Color(0.3, 0.17, 0.05) * night


## Interpolates SKY_KEYS at progress p. Returns a Dictionary of colours and numbers.
func _sky_at(p: float) -> Dictionary:
	var a: Array = _sky_keys[_sky_keys.size() - 1]
	var b: Array = a
	var t := 0.0
	if p <= _sky_keys[0][0]:
		a = _sky_keys[0]
		b = a
	else:
		for i in range(1, _sky_keys.size()):
			if p <= _sky_keys[i][0]:
				a = _sky_keys[i - 1]
				b = _sky_keys[i]
				t = (p - a[0]) / (b[0] - a[0])
				break
	return {
		"elev": lerpf(a[1], b[1], t),
		"sun": (a[2] as Color).lerp(b[2], t),
		"zenith": (a[3] as Color).lerp(b[3], t),
		"horizon": (a[4] as Color).lerp(b[4], t),
		"ambient": (a[5] as Color).lerp(b[5], t),
		"ambient_energy": lerpf(a[6], b[6], t),
		"sun_energy": lerpf(a[7], b[7], t),
		"stars": lerpf(a[8], b[8], t),
	}


func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _render_props(night: float) -> void:
	if level.props_dirty:
		var counts := {}
		for pr in level.props:
			var mmi: MultiMeshInstance3D = _mm[pr.kind]
			var idx: int = counts.get(pr.kind, 0)
			if idx >= mmi.multimesh.instance_count:
				continue
			counts[pr.kind] = idx + 1
			mmi.multimesh.set_instance_transform(idx, Transform3D(Basis.from_scale(pr.size), pr.pos))
			mmi.multimesh.set_instance_color(idx, pr.color)
		for kind in PROP_KINDS:
			_mm[kind].multimesh.visible_instance_count = counts.get(kind, 0)
		level.props_dirty = false
	var balloon := 0
	var mm_balloon: MultiMesh = _mm["balloon"].multimesh
	for pr in level.props:
		if pr.kind != "balloon" or balloon >= mm_balloon.instance_count:
			continue
		var y := pr.pos.y + sin(_time * 0.7 + pr.phase) * 0.6
		mm_balloon.set_instance_transform(balloon, Transform3D(Basis.from_scale(pr.size), Vector3(pr.pos.x, y, pr.pos.z)))
		balloon += 1


func _render_boats_and_storms() -> void:
	for o in level.obstacles:
		match o.kind:
			"boat":
				if o.node == null:
					o.node = _make_boat(o.boat)
					add_child(o.node)
				var h := _wave_h(o.x, o.z, _time)
				o.node.position = Vector3(o.x, h * 0.8 - 0.2, o.z)
				o.node.rotation = Vector3(sin(_time * 1.3 + o.phase) * 0.04, 0.0, sin(_time * 0.9 + o.phase) * 0.05)
			"bridge":
				if o.node == null:
					var mi := MeshInstance3D.new()
					mi.mesh = BridgeGeometry.shared_mesh()
					o.node = mi
					add_child(mi)
				o.node.position = Vector3(0.0, 0.0, o.z)
			"storm":
				if o.node == null:
					o.node = _make_storm()
					add_child(o.node)
				o.node.position = Vector3(o.sway, o.y, o.z)
				o.node.scale = Vector3.ONE * (1.05 + sin(_time + o.phase) * 0.03)


func _render_pickups() -> void:
	var simit_mm: MultiMesh = _mm["simit"].multimesh
	var fish_mm: MultiMesh = _mm["fish"].multimesh
	var n_simit := 0
	var n_fish := 0
	var d := GameState.distance
	for p in level.pickups:
		if p.dead:
			continue
		match p.kind:
			"simit":
				if n_simit < simit_mm.instance_count:
					var pos := Vector3(p.x, p.y + sin(_time * 3.0 + p.phase) * 0.3, p.z)
					simit_mm.set_instance_transform(n_simit, Transform3D(Basis(Vector3.UP, _time * 1.6 + p.phase).scaled(Vector3.ONE * 0.8), pos))
					n_simit += 1
			"fish":
				var u := (d - p.fish_start) / p.fish_length
				if u < -0.02 or u > 1.6 or n_fish >= fish_mm.instance_count:
					continue
				var pos_f := Vector3(p.x, _fish_y(p, u), p.z)
				fish_mm.set_instance_transform(n_fish, Transform3D(Basis.from_scale(Vector3.ONE), pos_f))
				n_fish += 1
			_:
				if p.node == null:
					p.node = _make_power(p.kind)
					add_child(p.node)
				p.node.position = Vector3(p.x, p.y + sin(_time * 2.2 + p.phase) * 0.4, p.z)
				p.node.rotation = Vector3(0.0, _time * 2.0 + p.phase, 0.0)
	simit_mm.visible_instance_count = n_simit
	fish_mm.visible_instance_count = n_fish


func _render_kites_and_flock() -> void:
	var kite_mm: MultiMesh = _mm["kite"].multimesh
	var string_mm: MultiMesh = _mm["kite_string"].multimesh
	var flock_mm: MultiMesh = _mm["flock"].multimesh
	var n_kite := 0
	var n_flock := 0
	for o in level.obstacles:
		if o.kind == "kite" and n_kite < kite_mm.instance_count:
			kite_mm.set_instance_transform(n_kite, Transform3D(Basis.from_scale(Vector3(1.5, 1.5, 0.15)), Vector3(o.sway, o.y, o.z)))
			kite_mm.set_instance_color(n_kite, o.color)
			string_mm.set_instance_transform(n_kite, Transform3D(Basis.from_scale(Vector3(0.12, o.y, 0.12)), Vector3(o.sway, o.y * 0.5, o.z)))
			n_kite += 1
		elif o.kind == "flock":
			var facing := Basis(Vector3.UP, PI) if o.speed < 0.0 else Basis()
			for m in o.members:
				if n_flock >= flock_mm.instance_count:
					break
				var pos := Vector3(o.x + m.x, o.y + m.y + sin(_time * 4.0 + o.phase) * 0.2, o.z + m.z)
				flock_mm.set_instance_transform(n_flock, Transform3D(facing, pos))
				flock_mm.set_instance_color(n_flock, Color(0.17, 0.18, 0.21) if o.hostile else Color.WHITE)
				n_flock += 1
	kite_mm.visible_instance_count = n_kite
	string_mm.visible_instance_count = n_kite
	flock_mm.visible_instance_count = n_flock


func _wave_h(x: float, z: float, t: float) -> float:
	return 0.45 * sin(x * 0.21 + t * 1.1) + 0.35 * sin(z * 0.17 - t * 1.6 + x * 0.05) + 0.18 * sin(x * 0.6 + z * 0.45 + t * 2.4)


func _free_nodes(nodes: Array[Node3D]) -> void:
	for n in nodes:
		_free_node(n)


func _free_node(n: Node3D) -> void:
	if n and is_instance_valid(n):
		n.queue_free()


func _fireworks(d: float) -> void:
	var colors := ["#FDE68A", "#F87171", "#60A5FA", "#34D399", "#F472B6", "#FFFFFF"]
	var c := Color.html(colors[randi() % colors.size()])
	Fx.burst(self, Vector3(randf_range(-50.0, 50.0), randf_range(40.0, 70.0), d + randf_range(140.0, 240.0)), c, _amount(30), 14.0, 1.6, 9.0)
	Sound.play("boom")


# ---------- node factories ----------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 110.0
	env.fog_depth_end = 320.0
	# Fog must not wash out the sky itself: the gradient stays deep at the top.
	env.fog_sky_affect = 0.0
	# Filmic tonemapping with a high white point keeps the sun and the sky from clipping to white.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 3.0
	env.glow_enabled = not _low
	env.glow_hdr_threshold = 1.2
	env.glow_intensity = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_sea() -> void:
	water_mat = _shader_material(WATER_SHADER)
	var plane := PlaneMesh.new()
	plane.size = Vector2(340.0, WATER_LEN)
	plane.subdivide_width = 68
	plane.subdivide_depth = 112
	water = MeshInstance3D.new()
	water.mesh = plane
	water.material_override = water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	var land_mat := _shader_material(LAND_SHADER)
	var land_mesh := PlaneMesh.new()
	land_mesh.size = Vector2(170.0, WATER_LEN)
	land_mesh.subdivide_width = 34
	land_mesh.subdivide_depth = 112
	_land_left = MeshInstance3D.new()
	_land_left.mesh = land_mesh
	_land_left.material_override = land_mat
	_land_left.position.x = -115.0
	add_child(_land_left)
	_land_right = MeshInstance3D.new()
	_land_right.mesh = land_mesh
	_land_right.material_override = land_mat
	_land_right.position.x = 115.0
	add_child(_land_right)


## The sky is one shader on the environment: no meshes, so the sun, moon and stars cost no draw calls.
func _build_sky() -> void:
	var shader := Shader.new()
	shader.code = SKY_SHADER
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = shader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky


func _build_multimeshes() -> void:
	var house := BoxMesh.new()
	_house_mat = MeshKit.vertex_material()
	house.material = _house_mat
	_add_mm("house", house, true)
	var roof := BoxMesh.new()
	roof.material = MeshKit.vertex_material()
	_add_mm("roof", roof, true)
	var tree := CylinderMesh.new()
	tree.top_radius = 0.0
	tree.bottom_radius = 0.5
	tree.height = 1.0
	tree.material = MeshKit.vertex_material()
	_add_mm("tree", tree, true)
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 1.0
	dome.material = MeshKit.vertex_material()
	_add_mm("dome", dome, true)
	var minaret := CylinderMesh.new()
	minaret.top_radius = 0.25
	minaret.bottom_radius = 0.35
	minaret.height = 1.0
	minaret.material = MeshKit.vertex_material()
	_add_mm("minaret", minaret, true)
	var balloon := SphereMesh.new()
	balloon.radius = 0.5
	balloon.height = 1.0
	balloon.material = MeshKit.vertex_material()
	_add_mm("balloon", balloon, true)
	_add_mm("cloud", _puff_mesh(CLOUD_PUFFS, MeshKit.vertex_material()), true)
	var simit := TorusMesh.new()
	simit.inner_radius = 0.5
	simit.outer_radius = 1.2
	simit.material = _shader_free_material(Color.html("#C98A3E"))
	_add_mm("simit", simit, false)
	_add_mm("fish", _fish_mesh(), false)
	var kite := SphereMesh.new()
	kite.radius = 1.0
	kite.height = 2.0
	kite.radial_segments = 4
	kite.rings = 2
	kite.material = MeshKit.vertex_material()
	_add_mm("kite", kite, true)
	var string_box := BoxMesh.new()
	string_box.material = _shader_free_material(Color(0.9, 0.9, 0.9))
	_add_mm("kite_string", string_box, false)
	_add_mm("flock", _bird_mesh(), true)


func _add_mm(kind: String, mesh: Mesh, use_colors: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = use_colors
	mm.mesh = mesh
	mm.instance_count = MM_CAPACITY[kind]
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = kind
	node.multimesh = mm
	add_child(node)
	_mm[kind] = node


## A flat rival or friendly gull: a body and two wings, drawn with boxes.
func _bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color.WHITE
	MeshKit.add_box(st, Transform3D(Basis(), Vector3.ZERO), Vector3(0.8, 0.6, 1.6), white)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(1.45, 0.0, -0.1)), Vector3(2.9, 0.16, 1.2), white)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-1.45, 0.0, -0.1)), Vector3(2.9, 0.16, 1.2), white)
	st.set_material(MeshKit.vertex_material())
	return st.commit()


func _make_boat(bt: BoatType) -> MeshInstance3D:
	if not _boat_meshes.has(bt.id):
		_boat_meshes[bt.id] = bt.build_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _boat_meshes[bt.id]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _low else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## A dark storm cloud: one opaque, merged mesh of puffs, built once and shared by every storm.
func _make_storm() -> MeshInstance3D:
	if _storm_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(_shader_free_material(Color(0.1, 0.11, 0.13)))
		_append_puffs(st, STORM_PUFFS)
		_storm_mesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _storm_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A small fish: a silver-blue body with a forked-looking tail, so a leaping fish reads as a fish.
func _fish_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_shader_free_material(Color.html("#7FC4E4")))
	var body := SphereMesh.new()
	body.radius = 1.0
	body.height = 2.0
	body.radial_segments = 10
	body.rings = 6
	st.append_from(body, 0, Transform3D(Basis.from_scale(Vector3(0.5, 0.45, 1.1)), Vector3.ZERO))
	# Tail fin, written twice with opposite winding so it shows from both sides.
	var fin := [Vector3(0.0, 0.0, -0.9), Vector3(0.0, 0.65, -1.7), Vector3(0.0, -0.65, -1.7)]
	for v in fin:
		st.add_vertex(v)
	for v in [fin[0], fin[2], fin[1]]:
		st.add_vertex(v)
	return st.commit()


## Several spheres merged into one mesh, so a cloud shape costs one draw call.
func _puff_mesh(puffs: Array, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	_append_puffs(st, puffs)
	return st.commit()


func _append_puffs(st: SurfaceTool, puffs: Array) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 18
	sphere.rings = 10
	for p in puffs:
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * p[3]), Vector3(p[0], p[1], p[2]))
		st.append_from(sphere, 0, xf)


func _make_power(kind: String) -> MeshInstance3D:
	if not _power_nodes_mesh.has(kind):
		var m: PrimitiveMesh
		if kind == "shield":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.45
			cone.height = 2.2
			m = cone
		else:
			var torus := TorusMesh.new()
			torus.inner_radius = 0.4 if kind == "gold" else 0.9
			torus.outer_radius = 0.8 if kind == "gold" else 1.2
			m = torus
		var colors := {"tail": "#34D399", "gold": "#F59E0B", "shield": "#E0F2FE"}
		m.material = _shader_free_material(Color.html(colors[kind]))
		_power_nodes_mesh[kind] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _power_nodes_mesh[kind]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _shader_free_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat
