extends Node
## Autoload "Sound": every sound is synthesised in code (no audio files).
## Effects are rendered once at start-up. The music loop is rendered a bar per frame, so the
## browser never stalls on one long synthesis.

const RATE := 22050
const MUSIC_BARS := 4
const STEP := 60.0 / 124.0 / 4.0
const SFX_VOICES := 6
const CHORDS := [
	{"root": 110.0, "arp": [440.0, 523.3, 659.3, 880.0], "pad": [220.0, 261.6, 329.6]},
	{"root": 87.3, "arp": [349.2, 440.0, 523.3, 698.5], "pad": [174.6, 220.0, 261.6]},
	{"root": 130.8, "arp": [392.0, 523.3, 659.3, 784.0], "pad": [196.0, 261.6, 329.6]},
	{"root": 98.0, "arp": [392.0, 493.9, 587.3, 784.0], "pad": [196.0, 246.9, 293.7]},
]

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_buf: Array[float] = []
var _music_bar: int = 0
var _music_ready: bool = false
var _want_music: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	# The window close is handled in _notification, so the engine must not quit on its own.
	get_tree().auto_accept_quit = false
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_build_sfx()
	_music_buf.resize(int(MUSIC_BARS * 16 * STEP * RATE) + RATE)
	_music_buf.fill(0.0)


## On a window close, release the audio first and quit one frame later. Otherwise Godot reports
## "ObjectDB instances were leaked at exit" for the audio playbacks that are still alive.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_release_audio()
		_quit_after_frame()


func _quit_after_frame() -> void:
	await get_tree().process_frame
	get_tree().quit()


## Stops every player and drops the streams, so no audio object is left alive at exit.
func _release_audio() -> void:
	for p in _players:
		p.stop()
		p.stream = null
	_music_player.stop()
	_music_player.stream = null
	_sfx.clear()


func _exit_tree() -> void:
	_release_audio()


func _process(_delta: float) -> void:
	if _music_ready:
		return
	var t0 := Time.get_ticks_usec()
	while _music_bar < MUSIC_BARS and Time.get_ticks_usec() - t0 < 8000:
		_fill_bar(_music_bar)
		_music_bar += 1
	if _music_bar >= MUSIC_BARS:
		_finish_music()


## Plays a named effect. pitch lets the same chime rise with the combo.
func play(sfx_name: String, pitch: float = 1.0) -> void:
	# Headless runs have no audio output. Playing there only leaves playback objects alive at exit.
	if not _sfx.has(sfx_name) or DisplayServer.get_name() == "headless":
		return
	var player := _free_player()
	player.stream = _sfx[sfx_name]
	player.pitch_scale = pitch
	player.play()


func start_music() -> void:
	_want_music = true
	if _music_ready and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_want_music = false
	_music_player.stop()


func apply_volumes() -> void:
	_apply_bus("Master", Save.settings["master"], true)
	_apply_bus("Music", Save.settings["music"], Save.settings["music_on"])
	_apply_bus("SFX", Save.settings["sfx"], Save.settings["sfx_on"])
	if Save.settings["music_on"] and _want_music and _music_ready and not _music_player.playing:
		_music_player.play()


func _apply_bus(bus_name: String, volume: float, on: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.001)))
	AudioServer.set_bus_mute(idx, not on or volume <= 0.0)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


func _finish_music() -> void:
	var stream := _to_wav(_music_buf)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = _music_buf.size()
	_music_player.stream = stream
	_music_ready = true
	if _want_music and Save.settings["music_on"]:
		_music_player.play()


# ---------- effects ----------

func _build_sfx() -> void:
	_sfx["flap"] = _to_wav(_sfx_flap())
	_sfx["call"] = _to_wav(_sfx_call())
	_sfx["horn"] = _to_wav(_sfx_horn())
	_sfx["chime"] = _to_wav(_sfx_chime())
	_sfx["hit"] = _to_wav(_sfx_hit())
	_sfx["whoosh"] = _to_wav(_sfx_whoosh())
	_sfx["steal"] = _to_wav(_sfx_steal())
	_sfx["boom"] = _to_wav(_sfx_boom())
	_sfx["start"] = _to_wav(_sfx_start())


func _sfx_flap() -> Array[float]:
	var b := _blank(0.14)
	_noise(b, 0.0, 0.14, 0.35, 0.25, false)
	return b


func _sfx_call() -> Array[float]:
	var b := _blank(0.36)
	_voice(b, 0.0, 0.12, 900.0, 1500.0, 0.25, 3)
	_voice(b, 0.13, 0.2, 1500.0, 1100.0, 0.2, 3)
	return b


func _sfx_horn() -> Array[float]:
	var b := _blank(0.85)
	_voice(b, 0.0, 0.8, 233.0, 233.0, 0.1, 1)
	_voice(b, 0.0, 0.8, 246.0, 246.0, 0.1, 1)
	return b


func _sfx_chime() -> Array[float]:
	var b := _blank(0.3)
	_voice(b, 0.0, 0.2, 660.0, 660.0, 0.3, 0)
	_voice(b, 0.06, 0.22, 990.0, 990.0, 0.2, 0)
	return b


func _sfx_hit() -> Array[float]:
	var b := _blank(0.35)
	_voice(b, 0.0, 0.3, 160.0, 40.0, 0.6, 0)
	_noise(b, 0.0, 0.18, 0.5, 0.1, false)
	return b


func _sfx_whoosh() -> Array[float]:
	var b := _blank(0.65)
	_noise(b, 0.0, 0.6, 0.35, 0.15, false)
	return b


func _sfx_steal() -> Array[float]:
	var b := _blank(0.3)
	_voice(b, 0.0, 0.25, 600.0, 200.0, 0.2, 1)
	return b


func _sfx_boom() -> Array[float]:
	var b := _blank(0.85)
	_noise(b, 0.0, 0.8, 0.6, 0.05, false)
	_voice(b, 0.0, 0.5, 80.0, 40.0, 0.4, 0)
	return b


func _sfx_start() -> Array[float]:
	var b := _blank(0.3)
	_voice(b, 0.0, 0.12, 523.0, 523.0, 0.3, 3)
	_voice(b, 0.1, 0.16, 784.0, 784.0, 0.3, 3)
	return b


# ---------- music ----------

func _fill_bar(bar: int) -> void:
	var ch: Dictionary = CHORDS[bar % CHORDS.size()]
	var root: float = ch["root"]
	var arp: Array = ch["arp"]
	var pad: Array = ch["pad"]
	for s in 16:
		var t := (bar * 16 + s) * STEP
		if s % 4 == 0:
			_voice(_music_buf, t, 0.2, 130.0, 42.0, 0.8, 0)
		if s % 2 == 0:
			_noise(_music_buf, t, 0.05, 0.12 if s % 4 == 2 else 0.07, 0.9, true)
		if s == 4 or s == 12:
			_noise(_music_buf, t, 0.12, 0.2, 0.3, false)
		if s % 2 == 0:
			var f := root * 2.0 if s % 4 == 2 else root
			_voice(_music_buf, t, STEP * 1.8, f, f, 0.1, 1)
		var a: float = arp[(s + bar) % 4] * (1.0 if s % 8 < 4 else 1.5)
		_voice(_music_buf, t, 0.11, a, a, 0.05, 2)
		if s == 0:
			for f2 in pad:
				_voice(_music_buf, t, STEP * 15.0, f2, f2, 0.03, 0)


# ---------- synthesis helpers ----------

func _blank(dur: float) -> Array[float]:
	var b: Array[float] = []
	b.resize(int((dur + 0.05) * RATE))
	b.fill(0.0)
	return b


## One tone with a frequency sweep from f0 to f1 and an exponential decay.
## kind: 0 sine, 1 saw, 2 and 3 triangles.
func _voice(buf: Array[float], start: float, dur: float, f0: float, f1: float, vol: float, kind: int) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	if n <= 0:
		return
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			break
		var t := float(i) / float(n)
		phase = fposmod(phase + lerpf(f0, f1, t) / RATE, 1.0)
		var attack := minf(1.0, float(i) / (0.004 * RATE))
		buf[idx] += _wave(kind, phase) * vol * attack * exp(-4.0 * t)


## Noise burst. A one-pole filter gives a low-pass sound; hp turns it into a hi-hat style hiss.
func _noise(buf: Array[float], start: float, dur: float, vol: float, coef: float, hp: bool) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var y := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			break
		var x := _rng.randf_range(-1.0, 1.0)
		y += coef * (x - y)
		var t := float(i) / float(n)
		buf[idx] += (x - y if hp else y) * vol * exp(-5.0 * t)


func _wave(kind: int, phase: float) -> float:
	match kind:
		0:
			return sin(TAU * phase)
		1:
			return 2.0 * phase - 1.0
		2:
			return 1.0 - 4.0 * absf(phase - 0.5)
		_:
			return 4.0 * absf(phase - 0.5) - 1.0


func _to_wav(samples: Array[float]) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
