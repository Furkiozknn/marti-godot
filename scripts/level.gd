class_name Level
extends RefCounted
## Everything in the world right now: hazards, pickups and shore props. Plain data; the world
## script turns it into nodes and the bot reads it to choose a lane.

const SEA_HALF_WIDTH := 170.0


class Obstacle:
	var kind: String = ""          # "boat", "bridge", "kite", "flock" or "storm"
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var speed: float = 0.0         # z speed for boats and flocks
	var boat: BoatType = null
	var color: Color = Color.WHITE
	var phase: float = 0.0
	var sway: float = 0.0          # x offset of kites and storms, updated every frame
	var hostile: bool = false      # rival flock: its members steal simit
	var members: Array[Vector3] = []
	var horned: bool = false       # ferry: its horn has sounded
	var node: Node3D = null


class Pickup:
	var kind: String = ""          # "simit", "fish", "tail", "gold" or "shield"
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var phase: float = 0.0
	var dead: bool = false
	var follow: Obstacle = null    # ferry simit ride on this boat
	var follow_offset: float = 0.0
	var fish_start: float = 0.0    # fish arc: starts at fish_start, lasts fish_length, peaks at fish_peak
	var fish_length: float = 0.0
	var fish_peak: float = 0.0
	var node: Node3D = null


class Prop:
	var kind: String = ""          # "house", "roof", "tree", "mosque", "yali", "galata", "maiden", "balloon" or "cloud"
	var pos: Vector3 = Vector3.ZERO
	var size: Vector3 = Vector3.ONE
	var color: Color = Color.WHITE
	var phase: float = 0.0
	var rot_y: float = 0.0         # turn about y (landmarks face the water)


var obstacles: Array[Obstacle] = []
var pickups: Array[Pickup] = []
var props: Array[Prop] = []
var props_dirty: bool = true
var next_band_z: float = 0.0
var next_pattern_z: float = 90.0
var next_bridge_z: float = 900.0


## Height of the land (and 0 on the water side) at world x, z. The land shader uses the same formula.
static func terrain_height(x: float, z: float) -> float:
	var ax := absf(x)
	var edge := maxf(0.0, ax - 30.0)
	var base := minf(edge * 0.22, 16.0)
	var s := sin(z * 0.021 + ax * 0.045)
	var bumps := 4.2 * s * s + 2.2 * sin(z * 0.067 - ax * 0.13 + 1.3)
	return maxf(0.0, base + maxf(0.0, bumps) * minf(1.0, edge / 10.0))


## Removes everything behind behind_z. Returns the nodes that the world must free.
func cull(behind_z: float) -> Array[Node3D]:
	var freed: Array[Node3D] = []
	var keep_obstacles: Array[Obstacle] = []
	for o in obstacles:
		var gone := o.z <= behind_z or (o.kind == "flock" and o.members.is_empty())
		if gone:
			if o.node:
				freed.append(o.node)
		else:
			keep_obstacles.append(o)
	obstacles = keep_obstacles
	var keep_pickups: Array[Pickup] = []
	for p in pickups:
		if p.z > behind_z and not p.dead:
			keep_pickups.append(p)
		elif p.node:
			freed.append(p.node)
	pickups = keep_pickups
	var keep_props: Array[Prop] = []
	for pr in props:
		if pr.pos.z > behind_z:
			keep_props.append(pr)
	if keep_props.size() != props.size():
		props_dirty = true
	props = keep_props
	return freed


func clear() -> Array[Node3D]:
	var freed: Array[Node3D] = []
	for o in obstacles:
		if o.node:
			freed.append(o.node)
	for p in pickups:
		if p.node:
			freed.append(p.node)
	obstacles.clear()
	pickups.clear()
	props.clear()
	props_dirty = true
	next_band_z = 0.0
	next_pattern_z = 90.0
	next_bridge_z = 900.0
	return freed
