class_name Bot
extends RefCounted
## Autoplay. Every 0.3 s it scores a grid of lanes (x, y) against the hazards ahead and steers to
## the cheapest one. It sees about 70 units ahead, like a decent human, and now and then makes a slip.

const CAND_X := [-20.0, -14.0, -8.0, -2.0, 4.0, 10.0, 16.0, 20.0]
const CAND_Y := [3.5, 7.0, 11.0, 15.0, 19.0, 23.0, 27.0, 31.0]
const LOOK_AHEAD := 70.0
const REPLAN_EVERY := 0.3
const SLIP_CHANCE := 0.1

var _timer: float = 0.0
var _target := Vector2(0.0, 12.0)


class Box:
	var kind: String   # "boat", "bridge", "cable", "kite" or "flock"
	var x: float
	var y0: float
	var y1: float
	var z: float
	var hw: float
	var hd: float

	func _init(bkind: String, bx: float, by0: float, by1: float, bz: float, bhw: float, bhd: float) -> void:
		kind = bkind
		x = bx
		y0 = by0
		y1 = by1
		z = bz
		hw = bhw
		hd = bhd


## Returns the lane the gull should fly to (x and y). Re-plans only every REPLAN_EVERY seconds.
func think(dt: float, level: Level, distance: float, gull: Vector2) -> Vector2:
	_timer -= dt
	if _timer > 0.0:
		return _target
	_timer = REPLAN_EVERY
	_target = choose(level, distance, gull)
	if randf() < SLIP_CHANCE:
		_target = Vector2(CAND_X[randi() % CAND_X.size()], CAND_Y[randi() % CAND_Y.size()])
	return _target


## The lane with the lowest cost. Hazards cost a lot, simit and power-ups pull the gull towards them.
static func choose(level: Level, distance: float, gull: Vector2) -> Vector2:
	var boxes := hazard_boxes(level)
	var picks: Array = []
	for p in level.pickups:
		if p.dead:
			continue
		var ahead := p.z - distance
		if ahead <= -2.0 or ahead >= 90.0:
			continue
		var weight := -22.0
		if p.kind == "fish":
			weight = -55.0
		elif p.kind == "tail" or p.kind == "gold" or p.kind == "shield":
			weight = -35.0
		picks.append([Vector2(p.x, p.y), weight])

	var ys: Array = CAND_Y.duplicate()
	for pick in picks:
		ys.append(clampf((pick[0] as Vector2).y, GameState.CONFIG.min_height, GameState.CONFIG.max_height))

	var best := Vector2(CAND_X[0], CAND_Y[0])
	var best_cost := INF
	for x: float in CAND_X:
		for y: float in ys:
			var cost := 0.0
			for b: Box in boxes:
				var ahead := b.z - distance
				if ahead < -4.0 or ahead > LOOK_AHEAD:
					continue
				if absf(x - b.x) < b.hw + 2.6 and y + 1.6 > b.y0 and y - 1.6 < b.y1:
					cost += 1000.0 / (1.0 + maxf(0.0, ahead) / 12.0)
			for pick in picks:
				var pp: Vector2 = pick[0]
				if absf(x - pp.x) < 3.0 and absf(y - pp.y) < 3.0:
					cost += float(pick[1])
			cost += absf(x - gull.x) * 0.5 + absf(y - gull.y) * 0.35
			if cost < best_cost:
				best_cost = cost
				best = Vector2(x, y)
	return best


## Collision boxes of everything that can hurt or steal, in world units.
static func hazard_boxes(level: Level) -> Array[Box]:
	var boxes: Array[Box] = []
	for o in level.obstacles:
		match o.kind:
			"boat":
				for aabb in o.boat.collision_boxes():
					var c := aabb.get_center()
					var h := aabb.size * 0.5
					boxes.append(Box.new("boat", o.x + c.x, c.y - h.y, c.y + h.y, o.z + c.z, h.x, h.z))
			"bridge":
				boxes.append(Box.new("bridge", -BridgeGeometry.TOWER_X, 0.0, 44.0, o.z, 1.8, 3.1))
				boxes.append(Box.new("bridge", BridgeGeometry.TOWER_X, 0.0, 44.0, o.z, 1.8, 3.1))
				boxes.append(Box.new("bridge", 0.0, BridgeGeometry.DECK_Y0, BridgeGeometry.DECK_Y1, o.z, 70.0, 4.0))
				boxes.append(Box.new("cable", 0.0, 25.5, 29.0, o.z, BridgeGeometry.TOWER_X, 3.1))
			"kite":
				boxes.append(Box.new("kite", o.sway, o.y - 1.6, o.y + 1.6, o.z, 1.6, 1.4))
			"flock":
				if o.hostile:
					for m in o.members:
						boxes.append(Box.new("flock", o.x + m.x, o.y + m.y - 1.5, o.y + m.y + 1.5, o.z + m.z, 2.2, 2.2))
	return boxes
