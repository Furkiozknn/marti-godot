class_name GameUI
extends CanvasLayer
## Every menu and the HUD: title, pause, game over, settings, toasts and "+points" pop-ups.
## Buttons only emit signals; main.gd decides what they do.

signal start_pressed
signal resume_pressed
signal menu_pressed
signal retry_pressed
signal restart_pressed
signal pause_pressed
signal music_pressed
signal sfx_pressed
signal lang_pressed
signal settings_changed
signal settings_opened

const CARD_MAX_WIDTH := 480.0
const SLIDER_KEYS := ["master", "music", "sfx"]
const LOGO := preload("res://assets/ui/logo.png")
## Focus ring and touch target rules of the arena design language.
const ACCENT := "#F59E0B"
const FOCUS_RING := "#FDE68A"
## Pause backdrop: a 13-tap blur of the frozen frame, darkened.
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * 3.0;
	vec3 c = texture(screen, SCREEN_UV).rgb * 0.2;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5236;
		vec2 d = vec2(cos(a), sin(a)) * px * (1.0 + float(i % 2));
		c += texture(screen, SCREEN_UV + d).rgb * (0.8 / 12.0);
	}
	COLOR = vec4(c * 0.55, 1.0);
}
"""

var _screens: Dictionary = {}
var _cards: Array[PanelContainer] = []
var _current: String = ""
var _fade: ColorRect
var _hud: Control
var _score: Label
var _combo: Label
var _dist: Label
var _best: Label
var _stamina: ProgressBar
var _stamina_fill: StyleBoxFlat
var _lives: LivesIcon
var _chips: Label
var _toasts: VBoxContainer
var _floats: Control
var _world: GameWorld
var _btn_pause: IconButton
var _btn_music: IconButton
var _btn_sfx: IconButton
var _btn_lang: IconButton
var _btn_settings: IconButton
var _title_tag: Label
var _title_how: Label
var _title_missions: Label
var _title_highs: Label
var _title_start: Button
var _title_settings: Button
var _title_credit: Label
var _hints: Array[Label] = []
var _over_head: Label
var _over_new: Label
var _over_reason: Label
var _over_stats: Label
var _over_missions: Label
var _over_retry: Button
var _pause_head: Label
var _pause_resume: Button
var _pause_restart: Button
var _pause_settings: Button
var _pause_menu: Button
var _over_menu: Button
var _over_settings: Button
var _set_head: Label
var _set_labels: Dictionary = {}
var _sliders: Dictionary = {}
var _set_lang: Button
var _set_quality: Button
var _set_fullscreen: CheckBox
var _set_back: Button
var _set_back_target: String = "title"


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_title()
	_build_pause()
	_build_over()
	_build_settings()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	get_viewport().size_changed.connect(_fit_cards)
	apply_texts()
	_fit_cards()
	show_screen("title", false)


func set_world(world: GameWorld) -> void:
	_world = world
	world.popup.connect(_on_popup)


# ---------- public API ----------

func show_screen(target: String, animate: bool = true) -> void:
	if _current == target and animate:
		return
	var swap := func() -> void:
		for key in _screens:
			(_screens[key] as Control).visible = key == target
		_current = target
		_hud.visible = target == "hud" or target == "pause"
		apply_texts()
		_fit_cards()
		var first := _first_button(target)
		if first:
			first.grab_focus()
	if animate:
		_transition(swap)
	else:
		swap.call()


func show_over(run: Dictionary, is_new_best: bool) -> void:
	_over_head.text = Loc.t("over")
	_over_reason.text = Loc.t("reason_" + str(run.get("reason", "crash")))
	_over_new.text = Loc.t("new_best") if is_new_best else ""
	_over_stats.text = "%s  %d\n%s  %d\n%s  %s\n%s  %d" % [
		Loc.t("score"), run["score"], Loc.t("best"), Save.best_score(),
		Loc.t("dist"), Loc.format_distance(run["dist"]), Loc.t("simit"), run["simit"]]
	_over_missions.text = _mission_summary()
	show_screen("over")


func set_music_on(on: bool) -> void:
	_btn_music.set_on(on)


func set_sfx_on(on: bool) -> void:
	_btn_sfx.set_on(on)


func update_hud() -> void:
	_score.text = "%s %d" % [Loc.t("score"), roundi(GameState.score)]
	_combo.text = "%s x%d" % [Loc.t("combo"), GameState.combo_multiplier()]
	_dist.text = Loc.format_distance(GameState.distance)
	_best.text = "%s %d" % [Loc.t("best"), maxi(Save.best_score(), roundi(GameState.score))]
	_lives.lives = GameState.lives
	_lives.queue_redraw()
	_stamina.value = GameState.stamina
	var low := GameState.stamina < 25.0
	_stamina_fill.bg_color = Color.html("#F87171") if low else Color.html("#F59E0B")
	var lines: Array[String] = []
	if GameState.tail_timer > 0.0:
		lines.append("%s %ds" % [Loc.t("chip_tail"), ceili(GameState.tail_timer)])
	if GameState.gold_timer > 0.0:
		lines.append("%s %ds" % [Loc.t("chip_gold"), ceili(GameState.gold_timer)])
	if GameState.shield:
		lines.append(Loc.t("chip_shield"))
	if GameState.combo >= 4:
		lines.append("x%d  %d" % [GameState.combo_multiplier(), GameState.combo])
	_chips.text = "\n".join(lines)


func toast(text: String, tone: String) -> void:
	if text == "":
		return
	# Tones of the arena design language: good (gold), bad (red), info (navy). "gold" is the old name of good.
	var good := tone == "good" or tone == "gold"
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _pill_style("#F59E0B" if good else ("#7F1D1D" if tone == "bad" else "#0F172A")))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := _label(text, 16, HORIZONTAL_ALIGNMENT_CENTER)
	# One line that sizes to its text: a wrapping label in this centred column would break every character.
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.add_theme_color_override("font_color", Color.html("#1F1300") if good else Color.WHITE)
	panel.add_child(lbl)
	_toasts.add_child(panel)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.45)
	tw.tween_callback(panel.queue_free)


## Refreshes every text (after a language change, or when a screen opens).
func apply_texts() -> void:
	_title_tag.text = Loc.t("tagline")
	_title_how.text = "%s\n%s\n%s\n%s" % [Loc.t("how_steer"), Loc.t("how_dive"), Loc.t("how_simit"), Loc.t("how_avoid")]
	_title_start.text = Loc.t("start")
	_title_settings.text = Loc.t("settings")
	_title_credit.text = Loc.t("credit")
	_title_missions.text = "%s\n%s" % [Loc.t("missions"), _mission_summary()]
	_title_highs.text = "%s\n%s" % [Loc.t("highs"), _high_summary()]
	for h in _hints:
		h.text = Loc.t("hint")
	_pause_head.text = Loc.t("paused")
	_pause_resume.text = Loc.t("resume")
	_pause_restart.text = Loc.t("restart")
	_pause_settings.text = Loc.t("settings")
	_pause_menu.text = Loc.t("menu")
	_over_retry.text = Loc.t("retry")
	_over_menu.text = Loc.t("menu")
	_over_settings.text = Loc.t("settings")
	_set_head.text = Loc.t("settings")
	_set_labels["master"].text = Loc.t("master")
	_set_labels["music"].text = Loc.t("music")
	_set_labels["sfx"].text = Loc.t("sfx")
	_set_lang.text = "%s: %s" % [Loc.t("language"), "English" if Loc.lang() == "en" else "Türkçe"]
	_set_quality.text = "%s: %s" % [Loc.t("quality"), Loc.t("quality_low") if Save.is_low_quality() else Loc.t("quality_high")]
	_set_fullscreen.text = Loc.t("fullscreen")
	_set_fullscreen.button_pressed = Save.settings["fullscreen"]
	_set_back.text = Loc.t("back")
	_btn_pause.tooltip_text = Loc.t("pause_btn")
	_btn_music.tooltip_text = Loc.t("music_btn")
	_btn_sfx.tooltip_text = Loc.t("sfx_btn")
	_btn_lang.tooltip_text = Loc.t("language")
	_btn_settings.tooltip_text = Loc.t("settings")
	for key in SLIDER_KEYS:
		(_sliders[key] as HSlider).value = Save.settings[key]
	set_music_on(Save.settings["music_on"])
	set_sfx_on(Save.settings["sfx_on"])


# ---------- building ----------

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = false
	add_child(_hud)
	_screens["hud"] = _hud

	# Top bar: a rounded panel with the stats, and a row of four icon buttons. Both fit side by side
	# on a 390 px wide phone screen.
	# A flow container: on a narrow phone the icon row (44 px touch targets) wraps under the stats.
	var bar := HFlowContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 8
	bar.alignment = FlowContainer.ALIGNMENT_END
	bar.add_theme_constant_override("h_separation", 8)
	bar.add_theme_constant_override("v_separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Toasts and chips sit just under the bar, however many rows it has.
	bar.resized.connect(func() -> void:
		if _chips and _toasts:
			_chips.offset_top = bar.size.y + 18
			_toasts.offset_top = bar.size.y + 18)
	_hud.add_child(bar)

	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _hud_style())
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(stats)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(stats_row)
	# Crest (28 px) and name on the left of the bar.
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 6)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.add_child(_crest(28))
	var name_lbl := _hud_label(16)
	name_lbl.text = "Martı"
	name_lbl.add_theme_color_override("font_color", Color.html("#FDE68A"))
	brand.add_child(name_lbl)
	stats_row.add_child(brand)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_child(lines)
	_score = _hud_label(20)
	lines.add_child(_score)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(mid)
	_combo = _hud_label(14)
	_dist = _hud_label(14)
	mid.add_child(_combo)
	mid.add_child(_dist)
	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 10)
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(low)
	_best = _hud_label(13)
	low.add_child(_best)
	_lives = LivesIcon.new()
	low.add_child(_lives)

	var icons := PanelContainer.new()
	icons.add_theme_stylebox_override("panel", _hud_style())
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(icons)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	icons.add_child(row)
	_btn_pause = _icon_button("pause", pause_pressed.emit)
	_btn_music = _icon_button("music", music_pressed.emit)
	_btn_sfx = _icon_button("sound", sfx_pressed.emit)
	_btn_lang = _icon_button("globe", lang_pressed.emit)
	_btn_settings = _icon_button("gear", _open_settings_from_hud)
	for b in [_btn_pause, _btn_music, _btn_sfx, _btn_lang, _btn_settings]:
		row.add_child(b)

	_chips = _label("", 14)
	_chips.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_chips.offset_left = 12
	_chips.offset_top = 104
	_chips.autowrap_mode = TextServer.AUTOWRAP_OFF
	_chips.add_theme_color_override("font_color", Color.html("#FDE68A"))
	_hud.add_child(_chips)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = 104
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_toasts)

	_stamina = ProgressBar.new()
	_stamina.min_value = 0.0
	_stamina.max_value = 100.0
	_stamina.show_percentage = false
	_stamina.custom_minimum_size = Vector2(0, 14)
	_stamina.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_stamina.offset_left = 12
	_stamina.offset_right = -12
	_stamina.offset_top = -26
	_stamina.offset_bottom = -12
	_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_fill = StyleBoxFlat.new()
	_stamina_fill.bg_color = Color.html("#F59E0B")
	_stamina_fill.set_corner_radius_all(7)
	_stamina.add_theme_stylebox_override("fill", _stamina_fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(7)
	_stamina.add_theme_stylebox_override("background", bg)
	_hud.add_child(_stamina)

	_floats = Control.new()
	_floats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_floats)


func _build_title() -> void:
	var box := _overlay("title")
	var crest := _crest(112)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(crest)
	box.add_child(_logo(52))
	_title_tag = _label("", 16, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title_tag)
	_title_how = _label("", 15)
	box.add_child(_title_how)
	var row := _row()
	_title_start = _button("", start_pressed.emit, Vector2(170, 52), true)
	_title_settings = _button("", func() -> void: _open_settings("title"), Vector2(150, 44))
	row.add_child(_title_start)
	row.add_child(_title_settings)
	box.add_child(row)
	_title_missions = _label("", 14)
	box.add_child(_title_missions)
	_title_highs = _label("", 14)
	box.add_child(_title_highs)
	box.add_child(_hint_label())
	_title_credit = _label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_title_credit.modulate.a = 0.6
	box.add_child(_title_credit)


## Pause: Resume, Restart, Settings, Main menu, one per row (the same order in every arena game).
func _build_pause() -> void:
	var box := _overlay("pause")
	# The frozen game shows through a dimmed, blurred backdrop.
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur := Shader.new()
	blur.code = BLUR_SHADER
	backdrop.material = ShaderMaterial.new()
	(backdrop.material as ShaderMaterial).shader = blur
	var root: Control = _screens["pause"]
	root.add_child(backdrop)
	root.move_child(backdrop, 0)
	_pause_head = _label("", 36, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_pause_head)
	box.add_child(_hint_label())
	_pause_resume = _button("", resume_pressed.emit, Vector2(240, 52), true)
	_pause_restart = _button("", restart_pressed.emit, Vector2(240, 46))
	_pause_settings = _button("", func() -> void: _open_settings("pause"), Vector2(240, 46))
	_pause_menu = _button("", menu_pressed.emit, Vector2(240, 46))
	for b in [_pause_resume, _pause_restart, _pause_settings, _pause_menu]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)


func _build_over() -> void:
	var box := _overlay("over")
	_over_head = _label("", 36, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_head)
	_over_reason = _label("", 16, HORIZONTAL_ALIGNMENT_CENTER)
	_over_reason.modulate.a = 0.85
	box.add_child(_over_reason)
	_over_new = _label("", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_over_new.add_theme_color_override("font_color", Color.html("#FDE68A"))
	box.add_child(_over_new)
	_over_stats = _label("", 20, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_stats)
	_over_missions = _label("", 14, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_missions)
	var row := _row()
	_over_retry = _button("", retry_pressed.emit, Vector2(170, 52), true)
	_over_menu = _button("", menu_pressed.emit, Vector2(150, 44))
	_over_settings = _button("", func() -> void: _open_settings("over"), Vector2(150, 44))
	row.add_child(_over_retry)
	row.add_child(_over_menu)
	row.add_child(_over_settings)
	box.add_child(row)


func _build_settings() -> void:
	var box := _overlay("settings")
	_set_head = _label("", 32, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_set_head)
	for key in SLIDER_KEYS:
		var lbl := _label("", 16)
		_set_labels[key] = lbl
		box.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(240, touch_size() * 0.8)
		slider.value_changed.connect(_on_slider.bind(key))
		# Saved when the drag ends too, so leaving settings with Esc never loses a change.
		slider.drag_ended.connect(func(_changed: bool) -> void: Save.save_all())
		slider.add_theme_stylebox_override("focus", _focus_ring(8))
		_sliders[key] = slider
		box.add_child(slider)
	_set_lang = _button("", _toggle_language, Vector2(260, 44))
	box.add_child(_set_lang)
	_set_quality = _button("", _toggle_quality, Vector2(260, 44))
	box.add_child(_set_quality)
	_set_fullscreen = CheckBox.new()
	_set_fullscreen.custom_minimum_size = Vector2(0, touch_size())
	_set_fullscreen.add_theme_stylebox_override("focus", _focus_ring(10))
	_set_fullscreen.toggled.connect(_on_fullscreen)
	box.add_child(_set_fullscreen)
	_set_back = _button("", _close_settings, Vector2(170, 48), true)
	box.add_child(_set_back)


func _overlay(screen_name: String) -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	_screens[screen_name] = root
	_cards.append(card)
	return box


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	return row


func _logo(size: int) -> Label:
	var lbl := _label("Martı.", size, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.add_theme_color_override("font_color", Color.html("#FDE68A"))
	return lbl


func _hint_label() -> Label:
	var lbl := _label(Loc.t("hint"), 12, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.modulate.a = 0.7
	_hints.append(lbl)
	return lbl


## The generated crest (a round badge), square, at the given size.
func _crest(px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = LOGO
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Touch screens get 44 px targets (the arena rule); a mouse gets slightly smaller icon buttons.
static func touch_size() -> float:
	return 44.0 if DisplayServer.is_touchscreen_available() else 38.0


func _label(text: String, size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", size)
	return lbl


func _button(text: String, handler: Callable, min_size: Vector2, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", _button_style("#F59E0B" if primary else "#1E293B"))
	b.add_theme_stylebox_override("hover", _button_style("#FBBF24" if primary else "#334155"))
	b.add_theme_stylebox_override("focus", _focus_ring(14))
	b.add_theme_stylebox_override("pressed", _button_style("#B45309" if primary else "#0F172A"))
	b.add_theme_color_override("font_color", Color.html("#1F1300") if primary else Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.html("#1F1300") if primary else Color.WHITE)
	b.pressed.connect(handler)
	return b


func _card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.09, 0.16, 0.86)
	s.border_color = Color(1, 1, 1, 0.18)
	s.set_border_width_all(1)
	s.set_corner_radius_all(22)
	return s


## A visible keyboard focus ring, drawn over the button's normal style.
static func _focus_ring(radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color.html(FOCUS_RING)
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.set_expand_margin_all(3)
	return s


func _button_style(hex: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.html(hex)
	s.set_corner_radius_all(14)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s


func _pill_style(hex: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.html(hex)
	s.bg_color.a = 0.85
	s.set_corner_radius_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## A rounded, semi-transparent panel behind the HUD stats, so the text reads over bright water and sky.
func _hud_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.06, 0.12, 0.55)
	s.set_corner_radius_all(14)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _hud_label(size: int) -> Label:
	var lbl := _label("", size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	return lbl


func _icon_button(kind: String, handler: Callable) -> IconButton:
	var b := IconButton.new(kind)
	b.pressed.connect(handler)
	return b


func _fit_cards() -> void:
	var width := get_viewport().get_visible_rect().size.x
	for card in _cards:
		card.custom_minimum_size.x = minf(CARD_MAX_WIDTH, width - 28.0)


func _first_button(target: String) -> Button:
	match target:
		"title":
			return _title_start
		"pause":
			return _pause_resume
		"over":
			return _over_retry
		"settings":
			return _set_back
	return null


# ---------- actions ----------

func _open_settings(from: String) -> void:
	_set_back_target = from
	settings_opened.emit()
	show_screen("settings")


## The gear in the HUD pauses the run first, so Back returns to the pause menu.
func _open_settings_from_hud() -> void:
	if GameState.phase == GameState.Phase.PLAYING:
		pause_pressed.emit()
	_open_settings.call_deferred("pause")


func _close_settings() -> void:
	Save.save_all()
	show_screen(_set_back_target)


func _on_slider(value: float, key: String) -> void:
	Save.settings[key] = value
	Sound.apply_volumes()


func _toggle_language() -> void:
	Save.settings["language"] = "en" if Loc.lang() == "tr" else "tr"
	apply_texts()
	settings_changed.emit()


func _toggle_quality() -> void:
	Save.settings["quality"] = "high" if Save.is_low_quality() else "low"
	apply_texts()
	settings_changed.emit()


func _on_fullscreen(on: bool) -> void:
	Save.settings["fullscreen"] = on
	settings_changed.emit()


func _on_popup(text: String, pos: Vector3) -> void:
	if _world == null or _world.camera.is_position_behind(pos):
		return
	var screen := _world.camera.unproject_position(pos)
	var lbl := _label(text, 22, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.add_theme_color_override("font_color", Color.html("#FDE68A"))
	lbl.position = screen - Vector2(30, 14)
	lbl.size = Vector2(120, 30)
	_floats.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 46.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)


func _transition(swap: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.14)
	tw.tween_callback(swap)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.22)


func _mission_summary() -> String:
	var lines: Array[String] = []
	for id in Save.daily_ids(Save.today_key()):
		var def := Save.mission_def(id)
		var done := Save.mission_done(id)
		var have := minf(Save.mission_progress(id), float(def.goal))
		var mark := "[x] " if done else ""
		lines.append("%s%s  (%d/%d)" % [mark, def.text(Loc.lang()), roundi(have), def.goal])
	return "\n".join(lines)


func _high_summary() -> String:
	if Save.highs.is_empty():
		return "-"
	var lines: Array[String] = []
	for h in Save.highs:
		lines.append("%d  ·  %s  ·  %d simit" % [h["score"], Loc.format_distance(float(h["dist"])), h["simit"]])
	return "\n".join(lines)


## Small row of feathers (as in the browser version): lost lives are dimmed.
class LivesIcon:
	extends Control
	var lives: int = 3

	func _init() -> void:
		custom_minimum_size = Vector2(3 * 16, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in 3:
			var base := Vector2(5 + i * 16, 17)
			var tip := base + Vector2(6, -16)
			var col := Color(1, 1, 1, 0.95) if i < lives else Color(1, 1, 1, 0.2)
			# A leaf-shaped vane around a slanted quill.
			var vane := PackedVector2Array()
			for k in 9:
				var t := k / 8.0
				vane.append(base.lerp(tip, t) + Vector2(-1, -0.4) * sin(t * PI) * 4.0)
			for k in range(7, 0, -1):
				var t := k / 8.0
				vane.append(base.lerp(tip, t) + Vector2(1, 0.4) * sin(t * PI) * 4.0)
			draw_colored_polygon(vane, col)
			draw_line(base + Vector2(-1, 2), tip, Color.html("#F59E0B") if i < lives else Color(1, 1, 1, 0.1), 1.2)


## A small round button with no text: its icon is drawn in code (see IconDraw), so no font is needed.
class IconButton:
	extends Button
	var _icon: IconDraw

	func _init(kind: String) -> void:
		var px := GameUI.touch_size()
		custom_minimum_size = Vector2(px, px)
		# Reachable with Tab, but a click does not keep the focus (Space must still dive while playing).
		focus_mode = Control.FOCUS_ALL
		add_theme_stylebox_override("normal", _style(Color(0.1, 0.14, 0.22, 0.6)))
		add_theme_stylebox_override("hover", _style(Color(0.2, 0.27, 0.38, 0.8)))
		add_theme_stylebox_override("pressed", _style(Color(0.02, 0.04, 0.08, 0.9)))
		add_theme_stylebox_override("focus", GameUI._focus_ring(10))
		pressed.connect(release_focus)
		_icon = IconDraw.new(kind)
		_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_icon)

	func set_on(on: bool) -> void:
		_icon.on = on
		_icon.queue_redraw()

	func _style(color: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = color
		s.set_corner_radius_all(10)
		return s


## Draws one icon: pause bars, a music note, a speaker, or a globe. Music and sound get a slash when off.
class IconDraw:
	extends Control
	var kind: String = ""
	var on: bool = true

	func _init(icon_kind: String) -> void:
		kind = icon_kind
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.3
		var col := Color.WHITE if on else Color(1, 1, 1, 0.45)
		match kind:
			"pause":
				draw_rect(Rect2(c.x - 0.6 * s, c.y - 0.7 * s, 0.45 * s, 1.4 * s), col)
				draw_rect(Rect2(c.x + 0.15 * s, c.y - 0.7 * s, 0.45 * s, 1.4 * s), col)
			"music":
				var top := c + Vector2(0.35 * s, -0.8 * s)
				draw_circle(c + Vector2(-0.3 * s, 0.6 * s), 0.38 * s, col)
				draw_line(c + Vector2(0.05 * s, 0.6 * s), top, col, 2.0)
				draw_colored_polygon(PackedVector2Array([top, top + Vector2(0.7 * s, 0.35 * s),
					top + Vector2(0.7 * s, 0.75 * s), top + Vector2(0.0, 0.4 * s)]), col)
			"sound":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-0.9 * s, -0.35 * s), c + Vector2(-0.45 * s, -0.35 * s),
					c + Vector2(0.1 * s, -0.8 * s), c + Vector2(0.1 * s, 0.8 * s), c + Vector2(-0.45 * s, 0.35 * s),
					c + Vector2(-0.9 * s, 0.35 * s)]), col)
				draw_arc(c + Vector2(0.1 * s, 0.0), 0.6 * s, -0.9, 0.9, 12, col, 2.0)
				draw_arc(c + Vector2(0.1 * s, 0.0), 1.0 * s, -0.9, 0.9, 16, col, 2.0)
			"globe":
				draw_arc(c, 0.95 * s, 0.0, TAU, 24, col, 2.0)
				draw_line(c + Vector2(-0.95 * s, 0.0), c + Vector2(0.95 * s, 0.0), col, 1.5)
				var meridian := PackedVector2Array()
				for i in 25:
					var a := TAU * i / 24.0
					meridian.append(c + Vector2(0.45 * s * cos(a), 0.95 * s * sin(a)))
				draw_polyline(meridian, col, 1.5)
			"gear":
				# Eight teeth around a ring with a hole.
				var teeth := PackedVector2Array()
				for i in 32:
					var a := TAU * i / 32.0
					var r := (1.0 if (i >> 1) % 2 == 0 else 0.72) * s
					teeth.append(c + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(teeth, col)
				draw_circle(c, 0.32 * s, Color(0.1, 0.14, 0.22, 1.0))
		if not on and (kind == "music" or kind == "sound"):
			draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Color.html("#F87171"), 2.5)
