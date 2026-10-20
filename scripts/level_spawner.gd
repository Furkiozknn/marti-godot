class_name LevelSpawner
extends RefCounted
## Decides what appears ahead of the gull, pattern by pattern. The odds and spacing follow the round-1 game.

const BOAT_TYPES := [
	preload("res://data/boats/ferry.tres"),
	preload("res://data/boats/fishing.tres"),
	preload("res://data/boats/tanker.tres"),
	preload("res://data/boats/sail.tres"),
]
const HOUSE_HEX := ["#F4A261", "#E76F51", "#2A9D8F", "#E9C46A", "#F5F5DC", "#E63946", "#8ECAE6", "#F1FAEE", "#FFB4A2", "#B5E48C"]
const ROOF_HEX := ["#7C2D12", "#991B1B", "#9A3412"]
const TREE_HEX := ["#2F6B3F", "#3A7D44", "#25573A"]
const KITE_HEX := ["#EF4444", "#F59E0B", "#22C55E", "#3B82F6", "#EC4899", "#A855F7"]
const BALLOON_HEX := ["#F87171", "#FBBF24", "#60A5FA", "#34D399", "#F472B6"]


## Makes sure the level reaches look_ahead units in front of the gull.
func fill_ahead(level: Level, distance: float, run_time: float, look_ahead: float) -> void:
	var horizon := distance + look_ahead
	while level.next_band_z < horizon:
		_shore_band(level, level.next_band_z)
		level.next_band_z += 40.0
	while level.next_pattern_z < horizon:
		_pattern(level, level.next_pattern_z, run_time)
		level.next_pattern_z += _spacing(run_time)
	while level.next_bridge_z < horizon:
		_bridge(level, level.next_bridge_z)
		level.next_bridge_z += randf_range(520.0, 780.0)


func _spacing(run_time: float) -> float:
	var difficulty := clampf((run_time - 30.0) / 150.0, 0.0, 1.0)
	return lerpf(52.0, 24.0, difficulty) * randf_range(0.8, 1.25)


func _pick(list: Array) -> String:
	return list[randi() % list.size()]


func _add_prop(level: Level, kind: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var pr := Level.Prop.new()
	pr.kind = kind
	pr.pos = pos
	pr.size = size
	pr.color = color
	pr.phase = randf_range(0.0, TAU)
	level.props.append(pr)
	level.props_dirty = true


func _add_pickup(level: Level, kind: String, x: float, y: float, z: float) -> Level.Pickup:
	var p := Level.Pickup.new()
	p.kind = kind
	p.x = x
	p.y = y
	p.z = z
	p.phase = randf_range(0.0, TAU)
	level.pickups.append(p)
	return p


func _add_obstacle(level: Level, kind: String, x: float, y: float, z: float) -> Level.Obstacle:
	var o := Level.Obstacle.new()
	o.kind = kind
	o.x = x
	o.y = y
	o.z = z
	o.phase = randf_range(0.0, TAU)
	level.obstacles.append(o)
	return o


# ---------- scenery on both shores ----------

func _shore_band(level: Level, z0: float) -> void:
	for side: float in [-1.0, 1.0]:
		for _house in 4 + randi() % 5:
			var x := side * randf_range(34.0, 74.0)
			var z := z0 + randf_range(0.0, 40.0)
			var y := Level.terrain_height(x, z)
			var w := randf_range(2.4, 3.6)
			var h := randf_range(2.5, 6.0)
			var d := randf_range(2.6, 3.4)
			_add_prop(level, "house", Vector3(x, y + h * 0.5, z), Vector3(w, h, d), Color.html(_pick(HOUSE_HEX)))
			if randf() < 0.6:
				# Pyramid roof: its base sits on the top of the house.
				_add_prop(level, "roof", Vector3(x, y + h, z), Vector3(w * 1.2, randf_range(0.75, 1.2), d * 1.2), Color.html(_pick(ROOF_HEX)))
		for _tree in 3:
			var tx := side * randf_range(34.0, 62.0)
			var tz := z0 + randf_range(0.0, 40.0)
			var ty := Level.terrain_height(tx, tz)
			var th := randf_range(3.2, 5.4)
			_add_prop(level, "tree", Vector3(tx, ty + th * 0.5, tz), Vector3(1.8, th, 1.8), Color.html(_pick(TREE_HEX)))
		if randf() < 0.22:
			# The mosque faces the water (its +z turned towards x = 0) and sinks 0.3 into the slope.
			var dx := side * randf_range(46.0, 54.0)
			var dz := z0 + randf_range(5.0, 35.0)
			_add_landmark(level, "mosque", dx, Level.terrain_height(dx, dz) - 0.3, dz, side)
		if randf() < 0.12:
			var bx := side * randf_range(40.0, 70.0)
			var bz := z0 + randf_range(0.0, 30.0)
			_add_prop(level, "balloon", Vector3(bx, randf_range(26.0, 40.0), bz), Vector3(2.6, 3.1, 2.6), Color.html(_pick(BALLOON_HEX)))
		if randf() < 0.5:
			var cs := randf_range(4.8, 8.8)
			_add_prop(level, "cloud", Vector3(randf_range(-150.0, 150.0), randf_range(44.0, 66.0), z0 + randf_range(0.0, 40.0)), Vector3(cs, cs * 0.55, cs * 0.55), Color.WHITE)
		# Rare landmarks: a yalı on the shore, the Galata tower further up, the Maiden's tower on its
		# islet in the water at |x| = 31 (corridor 20 + wings 3.7, with clearance; no collision).
		if randf() < 0.06:
			var yx := side * randf_range(40.0, 46.0)
			var yz := z0 + randf_range(5.0, 30.0)
			_add_landmark(level, "yali", yx, Level.terrain_height(yx, yz) - 0.3, yz, side)
		elif randf() < 0.035:
			var gx := side * randf_range(60.0, 74.0)
			var gz := z0 + randf_range(5.0, 30.0)
			_add_landmark(level, "galata", gx, Level.terrain_height(gx, gz) - 0.3, gz, side)
		elif randf() < 0.02:
			_add_landmark(level, "maiden", side * 31.0, -0.3, z0 + randf_range(5.0, 30.0), side)


## A landmark with a front (+z): turned to face the water on either shore.
func _add_landmark(level: Level, kind: String, x: float, y: float, z: float, side: float) -> void:
	_add_prop(level, kind, Vector3(x, y, z), Vector3.ONE, Color.WHITE)
	level.props[level.props.size() - 1].rot_y = landmark_turn(side)


## +90 degrees on the left shore (x < 0), -90 on the right one, so the model's +z faces x = 0.
static func landmark_turn(side: float) -> float:
	return PI * 0.5 if side < 0.0 else -PI * 0.5


# ---------- patterns: simit, fish, ships, kites, flocks, storms, power-ups ----------

func _pattern(level: Level, z: float, run_time: float) -> void:
	var early := run_time < 30.0
	var r := randf()
	if r < 0.26:
		_simit_pattern(level, z)
	elif r < 0.34:
		_fish_pattern(level, z)
	elif r < 0.60:
		_ship_pattern(level, z, run_time)
	elif r < 0.72 and not early:
		_kite_pattern(level, z)
	elif r < 0.80 and not early:
		_flock_pattern(level, z)
	elif r < 0.86 and not early:
		_storm_pattern(level, z)
	else:
		_power_pattern(level, z)


func _simit_pattern(level: Level, z: float) -> void:
	var x := randf_range(-17.0, 17.0)
	if randf() < 0.5:
		var y0 := randf_range(6.0, 16.0)
		for i in 4:
			_add_pickup(level, "simit", x + sin(i * 0.9) * 2.5, y0 + sin(i * 0.8) * 2.0, z + i * 4.2)
	else:
		for i in 5:
			_add_pickup(level, "simit", x, randf_range(4.5, 6.0), z + i * 3.6)


func _fish_pattern(level: Level, z: float) -> void:
	for i in 2 + randi() % 2:
		var length := randf_range(40.0, 58.0)
		var zf := z + i * 14.0 + randf_range(0.0, 8.0)
		var p := _add_pickup(level, "fish", randf_range(-16.0, 16.0), 0.0, zf)
		p.fish_start = zf - length
		p.fish_length = length
		p.fish_peak = randf_range(4.5, 10.0)


func _ship_pattern(level: Level, z: float, run_time: float) -> void:
	var r := randf()
	var index := 3
	if r < 0.33:
		index = 0
	elif r < 0.55:
		index = 1
	elif r < 0.72:
		index = 2 if run_time > 40.0 else 0
	var bt: BoatType = BOAT_TYPES[index]
	var x := randf_range(-16.0, 16.0)
	var o := _add_obstacle(level, "boat", x, 0.0, z)
	o.boat = bt
	o.speed = bt.speed
	if bt.id == "ferry":
		for j in 3:
			var p := _add_pickup(level, "simit", x, 5.3, z - 4.0 + j * 5.0)
			p.follow = o
			p.follow_offset = -4.0 + j * 5.0


func _kite_pattern(level: Level, z: float) -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	for i in 1 + randi() % 2:
		var o := _add_obstacle(level, "kite", side * randf_range(14.0, 21.0), randf_range(14.0, 28.0), z + i * randf_range(12.0, 30.0))
		o.color = Color.html(_pick(KITE_HEX))
		o.sway = o.x


func _flock_pattern(level: Level, z: float) -> void:
	var hostile := randf() < 0.6
	var o := _add_obstacle(level, "flock", randf_range(-12.0, 12.0), randf_range(6.0, 22.0), z + 40.0 if hostile else z - 20.0)
	o.hostile = hostile
	o.speed = -9.0 if hostile else 9.0
	# Followers trail behind the leader, against the flight direction, so the V points where it flies.
	var back := -signf(o.speed)
	o.members = [Vector3(0, 0, 0), Vector3(-2.2, 1, 2.5 * back), Vector3(2.2, 1, 2.5 * back), Vector3(-4.4, 2, 5.0 * back)]


func _storm_pattern(level: Level, z: float) -> void:
	var o := _add_obstacle(level, "storm", randf_range(-12.0, 12.0), randf_range(20.0, 27.0), z + 30.0)
	o.speed = -1.0 if randf() < 0.5 else 1.0
	o.sway = o.x


func _power_pattern(level: Level, z: float) -> void:
	var r := randf()
	var kind := "tail" if r < 0.4 else ("gold" if r < 0.7 else "shield")
	_add_pickup(level, kind, randf_range(-15.0, 15.0), randf_range(7.0, 18.0), z + 10.0)


func _bridge(level: Level, z: float) -> void:
	_add_obstacle(level, "bridge", 0.0, 0.0, z)
