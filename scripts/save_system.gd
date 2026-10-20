extends Node
## Autoload "Save": settings, high scores and daily missions, stored in user://marti_save.json.
## Every write is skipped when the game runs with --no-save (bot runs, tests, Movie Maker).

signal mission_completed(id: String)

const PATH := "user://marti_save.json"
const MAX_HIGHS := 5
const MISSION_RES := [
	preload("res://data/missions/simit.tres"),
	preload("res://data/missions/fish.tres"),
	preload("res://data/missions/dist.tres"),
	preload("res://data/missions/power.tres"),
	preload("res://data/missions/combo.tres"),
]

var enabled: bool = true
var settings: Dictionary = {}
var highs: Array = []
var missions: Dictionary = {}
var _daily_key: String = ""
var _daily: Array = []


func _ready() -> void:
	enabled = not Cli.has_flag("--no-save")
	settings = default_settings()
	load_all()


func default_settings() -> Dictionary:
	return {
		"master": 0.8,
		"music": 0.6,
		"sfx": 0.8,
		"music_on": true,
		"sfx_on": true,
		"language": "tr" if OS.get_locale_language() == "tr" else "en",
		"quality": "low" if OS.has_feature("web") else "high",
		"fullscreen": false,
	}


func load_all() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var saved: Dictionary = data
	settings.merge(saved.get("settings", {}), true)
	highs = saved.get("highs", [])
	missions = saved.get("missions", {})


func save_all() -> void:
	if not enabled:
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"settings": settings, "highs": highs, "missions": missions}, "\t"))


## Applies volumes, quality and window mode. Called at start-up and after each settings change.
func apply_all() -> void:
	Sound.apply_volumes()
	apply_display()


func apply_display() -> void:
	var low := is_low_quality()
	RenderingServer.directional_shadow_atlas_set_size(1024 if low else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_HARD if low else RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)


func is_low_quality() -> bool:
	return settings.get("quality", "low") == "low"


static func insert_high(list: Array, entry: Dictionary, max_count: int) -> Array:
	var out: Array = list.duplicate()
	out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	return out.slice(0, max_count)


func best_score() -> int:
	return int(highs[0]["score"]) if not highs.is_empty() else 0


func record_run(run: Dictionary) -> void:
	highs = insert_high(highs, {
		"score": run["score"],
		"dist": run["dist"],
		"simit": run["simit"],
		"date": Time.get_date_string_from_system(),
	}, MAX_HIGHS)
	save_all()


func today_key() -> String:
	return Time.get_date_string_from_system()


## The three missions of a given day, picked by a seeded shuffle so every player gets the same set.
func daily_ids(date_key: String) -> Array:
	# Cached per date: mission_track calls this on every frame (distance).
	if date_key == _daily_key:
		return _daily
	var ids: Array = []
	for res in MISSION_RES:
		ids.append((res as MissionDef).id)
	var rng := RandomNumberGenerator.new()
	rng.seed = date_key.hash()
	for i in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	_daily_key = date_key
	_daily = ids.slice(0, 3)
	return _daily


func mission_def(id: String) -> MissionDef:
	for res in MISSION_RES:
		if (res as MissionDef).id == id:
			return res
	return null


func _today() -> Dictionary:
	if missions.get("date", "") != today_key():
		missions = {"date": today_key(), "progress": {}, "done": []}
	return missions


func mission_progress(id: String) -> float:
	var stat := mission_def(id).stat
	return float(_today()["progress"].get(stat, 0.0))


func mission_done(id: String) -> bool:
	return _today()["done"].has(id)


## Adds progress for a run statistic. as_max keeps the largest value instead (used for combo).
func mission_track(stat: String, value: float, as_max: bool) -> void:
	var today := _today()
	var progress: Dictionary = today["progress"]
	var old: float = progress.get(stat, 0.0)
	progress[stat] = maxf(old, value) if as_max else old + value
	for id in daily_ids(today["date"]):
		var def := mission_def(id)
		if def.stat == stat and not today["done"].has(id) and float(progress[stat]) >= def.goal:
			today["done"].append(id)
			mission_completed.emit(id)
