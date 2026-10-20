extends Node
## Autoload "GameState": the run's numbers and rules. It has no nodes, so the tests can call it directly.

signal message(key: String, tone: String)
signal stat_changed(stat: String, value: float, as_max: bool)
signal run_ended(run: Dictionary)

enum Phase { TITLE, PLAYING, PAUSED, OVER }

const CONFIG: GameConfig = preload("res://data/game_config.tres")

var phase: Phase = Phase.TITLE
var run_time: float = 0.0
var distance: float = 0.0
var speed: float = 27.0
var score: float = 0.0
var lives: int = 3
var stamina: float = 100.0
var combo: int = 0
var combo_timer: float = 0.0
var best_combo: int = 0
var tail_timer: float = 0.0
var gold_timer: float = 0.0
var shield: bool = false
var invuln: float = 0.0
var simit_count: int = 0
var fish_count: int = 0
var steal_count: int = 0
var power_count: int = 0
var last_run: Dictionary = {}


func _ready() -> void:
	reset_run()
	phase = Phase.TITLE


## True while the title or game-over screen plays its bot demo (no damage, no score).
func is_attract() -> bool:
	return phase != Phase.PLAYING


func reset_run() -> void:
	run_time = 0.0
	distance = 0.0
	speed = CONFIG.start_speed
	score = 0.0
	lives = CONFIG.lives
	stamina = CONFIG.stamina_max
	combo = 0
	combo_timer = 0.0
	best_combo = 0
	tail_timer = 0.0
	gold_timer = 0.0
	shield = false
	invuln = 0.0
	simit_count = 0
	fish_count = 0
	steal_count = 0
	power_count = 0
	last_run = {}


func start_run() -> void:
	reset_run()
	phase = Phase.PLAYING


# ---------- speed and multipliers ----------

## Forward speed the gull wants at a given run time (rises quickly at first, then levels off).
func base_speed(t: float) -> float:
	return CONFIG.start_speed + CONFIG.speed_gain * (1.0 - exp(-t / CONFIG.speed_time))


func target_speed() -> float:
	if is_attract():
		return CONFIG.attract_speed
	return base_speed(run_time) + (CONFIG.tail_boost if tail_timer > 0.0 else 0.0)


## 0 at the start, 1 after about three minutes: spacing and odds of hazards depend on it.
func difficulty() -> float:
	return clampf((run_time - 30.0) / 150.0, 0.0, 1.0)


func combo_multiplier() -> int:
	return 1 + mini(4, floori(combo / 4.0))


func score_multiplier() -> float:
	var m := 1.0
	if tail_timer > 0.0:
		m *= 1.5
	if gold_timer > 0.0:
		m *= 2.0
	return m


func pickup_points(base: int) -> int:
	return roundi(base * combo_multiplier() * score_multiplier())


# ---------- per-frame bookkeeping ----------

## Advances the clock, speed, timers and distance. Scores distance only while playing.
func tick(dt: float) -> void:
	run_time += dt
	tail_timer = maxf(0.0, tail_timer - dt)
	gold_timer = maxf(0.0, gold_timer - dt)
	invuln = maxf(0.0, invuln - dt)
	if combo > 0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo = 0
	speed += (target_speed() - speed) * minf(1.0, dt * 2.2)
	distance += speed * dt
	if not is_attract():
		score += speed * dt * 0.35 * score_multiplier()
		stat_changed.emit("dist", speed * dt, false)


func drain_stamina(dt: float, diving: bool) -> void:
	stamina -= (CONFIG.stamina_drain + run_time * CONFIG.stamina_drain_growth) * dt * (1.3 if diving else 1.0)
	if stamina <= 0.0:
		stamina = 0.0
		end_run("energy")


# ---------- pickups and damage ----------

func add_combo() -> void:
	combo += 1
	combo_timer = CONFIG.combo_window
	best_combo = maxi(best_combo, combo)
	stat_changed.emit("combo", float(best_combo), true)


## Returns the points gained.
func collect_simit() -> int:
	add_combo()
	simit_count += 1
	var pts := pickup_points(CONFIG.simit_points)
	score += pts
	stamina = minf(CONFIG.stamina_max, stamina + CONFIG.simit_stamina)
	stat_changed.emit("simit", 1.0, false)
	return pts


func collect_fish() -> int:
	add_combo()
	fish_count += 1
	var pts := pickup_points(CONFIG.fish_points)
	score += pts
	stamina = minf(CONFIG.stamina_max, stamina + CONFIG.fish_stamina)
	stat_changed.emit("fish", 1.0, false)
	return pts


## kind is "tail", "gold" or "shield".
func collect_power(kind: String) -> void:
	power_count += 1
	score += CONFIG.power_points
	stamina = minf(CONFIG.stamina_max, stamina + CONFIG.power_stamina)
	stat_changed.emit("power", 1.0, false)
	match kind:
		"tail":
			tail_timer = CONFIG.tail_time
			message.emit("tail", "gold")
		"gold":
			gold_timer = CONFIG.gold_time
			score += CONFIG.gold_bonus
			message.emit("gold", "gold")
		"shield":
			shield = true
			message.emit("shield", "gold")


## Returns true when the hit was absorbed (shield or invulnerability). Ends the run on the last life.
func take_hit() -> bool:
	if invuln > 0.0:
		return true
	if shield:
		shield = false
		invuln = CONFIG.shield_invuln
		message.emit("shield_used", "gold")
		return true
	lives -= 1
	combo = 0
	combo_timer = 0.0
	invuln = CONFIG.hit_invuln
	message.emit("hit", "bad")
	if lives <= 0:
		end_run("crash")
	return false


## A rival gull steals a simit: stamina and combo are lost. Ends the run when stamina runs out.
func steal_food() -> void:
	stamina -= CONFIG.steal_cost
	combo = 0
	combo_timer = 0.0
	steal_count += 1
	message.emit("steal", "bad")
	if stamina <= 0.0:
		stamina = 0.0
		end_run("energy")


func end_run(reason: String) -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.OVER
	combo = 0
	last_run = {
		"score": roundi(score),
		"dist": roundi(distance),
		"simit": simit_count,
		"fish": fish_count,
		"combo": best_combo,
		"time": snappedf(run_time, 0.1),
		"reason": reason,
	}
	run_ended.emit(last_run)


func pause() -> void:
	if phase == Phase.PLAYING:
		phase = Phase.PAUSED


func resume() -> void:
	if phase == Phase.PAUSED:
		phase = Phase.PLAYING


## One JSON line describing the current state, for tests, bots and debugging.
func get_state_text() -> String:
	return JSON.stringify({
		"phase": Phase.keys()[phase].to_lower(),
		"run_time": snappedf(run_time, 0.1),
		"distance": roundi(distance),
		"speed": snappedf(speed, 0.1),
		"score": roundi(score),
		"lives": lives,
		"stamina": snappedf(stamina, 0.1),
		"combo": combo,
		"best_combo": best_combo,
		"shield": shield,
		"tail": tail_timer > 0.0,
		"gold": gold_timer > 0.0,
		"simit": simit_count,
		"fish": fish_count,
		"steals": steal_count,
		"last_run": last_run,
	}, "", true)
