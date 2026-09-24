extends Control

const BONE := UiTheme.BONE
const AMBER := UiTheme.AMBER
const GOLD := UiTheme.GOLD
const BLOOD := UiTheme.BLOOD
const MUTED := UiTheme.MUTED
const GREEN := UiTheme.GREEN

const VIGNETTE_SHADER := "shader_type canvas_item;\nuniform float intensity : hint_range(0.0, 1.0) = 0.4;\nuniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);\nvoid fragment() {\n\tfloat d = length(UV - vec2(0.5));\n\tfloat v = smoothstep(0.32, 0.86, d);\n\tCOLOR = vec4(tint.rgb, v * intensity);\n}\n"

var _game: Node
var _player: Node
var _phase_label: Label
var _timer_label: Label
var _status_panel: PanelContainer
var _coins_label: Label
var _carried_label: Label
var _gadget_label: Label
var _death_label: Label
var _alert_label: Label
var _prompt_label: Label
var _stamina_bar: ProgressBar
var _stamina_value: Label
var _toast_box: VBoxContainer
var _scratch_panel: PanelContainer
var _scratch_title: Label
var _scratch_level: Label
var _scratch_xp_bar: ProgressBar
var _scratch_xp_label: Label
var _scratch_rows: VBoxContainer
var _scratch_type: TicketType
var _completing := false
var _hide_token := 0
var _xp_burst_time := 0.0
var _xp_burst_accum := 0.0
var _xp_tween: Tween
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _focus_dim: ColorRect
var _spark_layer: Control
var _last_alert := 0
var _danger := 0
var _time := 0.0
var _coin_display := 0.0
var _coin_target := 0.0


func _ready() -> void:
	add_to_group("hud")
	theme = UiTheme.shared()
	_game = get_tree().get_first_node_in_group("game")
	_player = get_tree().get_first_node_in_group("player")
	_build()
	if _game:
		_game.phase_changed.connect(_on_phase_changed)
		_game.backpack_changed.connect(refresh)
		_game.gadgets_changed.connect(refresh)
		_game.player_died.connect(_on_player_died)
		_game.ticket_completed.connect(_on_ticket_completed)
		_game.ticket_held.connect(_on_ticket_held)
		_game.ticket_released.connect(_on_ticket_released)
	resized.connect(queue_redraw)
	refresh()


func _process(delta: float) -> void:
	_time += delta
	_update_timer()
	_update_alert()
	_update_stamina()
	_update_vignette(delta)
	_animate_coins(delta)
	_update_xp_burst(delta)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_atmosphere()
	_build_status()
	_build_coins()
	_build_stamina()
	_build_chips()
	_build_center()
	_build_toasts()
	_build_scratch_panel()
	_build_sparks()


func _build_sparks() -> void:
	_spark_layer = Control.new()
	_spark_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spark_layer)


func spawn_sparks(pos: Vector2, color: Color = BONE) -> void:
	if _spark_layer == null:
		return
	var spark_color := Color(color.r, color.g, color.b, 0.9)
	for i in range(3):
		var spark := ColorRect.new()
		spark.color = spark_color
		spark.size = Vector2(3, 3)
		spark.position = pos - spark.size * 0.5
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spark_layer.add_child(spark)
		var dir := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(10.0, 26.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + dir, 0.35)
		tween.tween_property(spark, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(spark.queue_free)


func _build_atmosphere() -> void:
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	_vignette_mat.set_shader_parameter("intensity", 0.34)
	_vignette_mat.set_shader_parameter("tint", Color(0, 0, 0, 1))
	_vignette = ColorRect.new()
	_vignette.material = _vignette_mat
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	_focus_dim = ColorRect.new()
	_focus_dim.color = Color(0, 0, 0, 0.16)
	_focus_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_focus_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_dim.visible = false
	add_child(_focus_dim)


func _build_status() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.anchor_left = 0.0
	_status_panel.anchor_top = 0.0
	_status_panel.offset_left = UiTheme.SP_LG
	_status_panel.offset_top = UiTheme.SP_LG
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_status_panel.add_child(box)

	_phase_label = Label.new()
	_phase_label.theme_type_variation = &"TitleLabel"
	_phase_label.text = "DAY"
	box.add_child(_phase_label)

	box.add_child(_accent_rule())

	_timer_label = Label.new()
	_timer_label.theme_type_variation = &"MutedLabel"
	box.add_child(_timer_label)


func _build_coins() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_right = -UiTheme.SP_LG
	panel.offset_top = UiTheme.SP_LG
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SP_SM)
	panel.add_child(row)

	var glyph := Label.new()
	glyph.theme_type_variation = &"GoldLabel"
	glyph.text = "\u25c8"
	row.add_child(glyph)

	_coins_label = Label.new()
	_coins_label.theme_type_variation = &"GoldLabel"
	_coins_label.text = "0"
	row.add_child(_coins_label)


func _build_stamina() -> void:
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = UiTheme.SP_LG
	panel.offset_bottom = -UiTheme.SP_LG
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(240, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.SP_XS)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.SP_SM)
	box.add_child(head)

	var title := Label.new()
	title.theme_type_variation = &"SectionLabel"
	title.text = "STAMINA"
	head.add_child(title)

	_stamina_value = Label.new()
	_stamina_value.theme_type_variation = &"ChipLabel"
	_stamina_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stamina_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_stamina_value)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(240, 12)
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 100.0
	_stamina_bar.show_percentage = false
	box.add_child(_stamina_bar)


func _build_chips() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_right = -UiTheme.SP_LG
	panel.offset_bottom = -UiTheme.SP_LG
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.SP_XS)
	panel.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"SectionLabel"
	title.text = "CARRY"
	box.add_child(title)

	_carried_label = Label.new()
	_carried_label.theme_type_variation = &"ChipLabel"
	_carried_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_carried_label)

	_gadget_label = Label.new()
	_gadget_label.theme_type_variation = &"ChipLabel"
	_gadget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_gadget_label)


func _build_center() -> void:
	_alert_label = Label.new()
	_alert_label.theme_type_variation = &"AlertLabel"
	_alert_label.anchor_left = 0.5
	_alert_label.anchor_right = 0.5
	_alert_label.offset_left = -320.0
	_alert_label.offset_right = 320.0
	_alert_label.offset_top = 84.0
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alert_label)

	_death_label = Label.new()
	_death_label.theme_type_variation = &"TitleLabel"
	_death_label.anchor_left = 0.5
	_death_label.anchor_top = 0.5
	_death_label.anchor_right = 0.5
	_death_label.anchor_bottom = 0.5
	_death_label.offset_left = -320.0
	_death_label.offset_top = -40.0
	_death_label.offset_right = 320.0
	_death_label.offset_bottom = 40.0
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_death_label)

	_prompt_label = Label.new()
	_prompt_label.theme_type_variation = &"ChipLabel"
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -360.0
	_prompt_label.offset_right = 360.0
	_prompt_label.offset_bottom = -UiTheme.SP_XL
	_prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_label)


func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.anchor_top = 1.0
	_toast_box.anchor_bottom = 1.0
	_toast_box.offset_left = -320.0
	_toast_box.offset_right = 320.0
	_toast_box.offset_top = -300.0
	_toast_box.offset_bottom = -120.0
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override("separation", UiTheme.SP_XS)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)


func _build_scratch_panel() -> void:
	_scratch_panel = PanelContainer.new()
	_scratch_panel.anchor_left = 0.0
	_scratch_panel.anchor_top = 0.5
	_scratch_panel.anchor_bottom = 0.5
	_scratch_panel.offset_left = UiTheme.SP_LG
	_scratch_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_scratch_panel.custom_minimum_size = Vector2(340, 0)
	_scratch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scratch_panel.visible = false
	add_child(_scratch_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.SP_SM)
	_scratch_panel.add_child(box)

	_scratch_title = Label.new()
	_scratch_title.theme_type_variation = &"TitleLabel"
	box.add_child(_scratch_title)

	box.add_child(_accent_rule())

	_scratch_level = Label.new()
	_scratch_level.theme_type_variation = &"HeadingLabel"
	box.add_child(_scratch_level)

	_scratch_xp_bar = ProgressBar.new()
	_scratch_xp_bar.custom_minimum_size = Vector2(0, 12)
	_scratch_xp_bar.show_percentage = false
	box.add_child(_scratch_xp_bar)

	_scratch_xp_label = Label.new()
	_scratch_xp_label.theme_type_variation = &"MutedLabel"
	box.add_child(_scratch_xp_label)

	var prizes := Label.new()
	prizes.theme_type_variation = &"SectionLabel"
	prizes.text = "PRIZES  (chance)"
	box.add_child(prizes)

	_scratch_rows = VBoxContainer.new()
	_scratch_rows.add_theme_constant_override("separation", UiTheme.SP_XS)
	box.add_child(_scratch_rows)


func _accent_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = UiTheme.AMBER
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _draw() -> void:
	var center := size * 0.5
	var col := Color(1, 1, 1, 0.75)
	var gap := 5.0
	var length := 10.0
	if _danger >= 2:
		col = Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.9)
		gap = 8.0
		length = 13.0
	elif _danger == 1:
		col = Color(AMBER.r, AMBER.g, AMBER.b, 0.85)
	draw_circle(center, 1.8, col)
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + dir * gap, center + dir * length, col, 1.5)


func refresh() -> void:
	if _game == null:
		return
	if _phase_label:
		_phase_label.text = "NIGHT" if _game.is_night() else "DAY"
	if _carried_label:
		_carried_label.text = "TICKETS  %d / %d" % [_game.backpack.size(), _game.effective_backpack_capacity()]
	if _gadget_label:
		_gadget_label.text = "STUN  %d" % _game.gadget_charges
	_update_coins()
	_update_timer()


func _update_coins() -> void:
	if _coins_label == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		_coin_target = float(int(_player.get("coins")))


func _animate_coins(delta: float) -> void:
	if _coins_label == null:
		return
	if absf(_coin_display - _coin_target) < 0.5:
		_coin_display = _coin_target
	else:
		_coin_display = lerpf(_coin_display, _coin_target, clampf(delta * 8.0, 0.0, 1.0))
	_coins_label.text = "%d" % int(round(_coin_display))


func _update_timer() -> void:
	if _game == null or _timer_label == null:
		return
	if _game.is_night():
		var left := int(ceil(_game.night_time_left))
		_timer_label.text = "Dawn in %d s" % left
		_timer_label.add_theme_color_override("font_color", BLOOD if left <= 20 else MUTED)
	else:
		_timer_label.text = "Sleep to begin the night"


func _on_phase_changed(_phase: int) -> void:
	if _game and _game.is_night() and _death_label:
		_death_label.text = ""
	refresh()


func _on_player_died() -> void:
	if _death_label:
		_death_label.text = "CAUGHT"


func _update_alert() -> void:
	if _alert_label == null:
		return
	var level := 0
	for guest in get_tree().get_nodes_in_group("guest"):
		if guest.has_method("awareness"):
			level = maxi(level, int(guest.awareness()))
	if level != _danger:
		_danger = level
		queue_redraw()
	if level >= 2:
		_alert_label.text = "SPOTTED!"
		_alert_label.add_theme_color_override("font_color", BLOOD)
		_alert_label.modulate.a = 0.7 + 0.3 * sin(_time * 7.0)
	elif level == 1:
		_alert_label.text = "?"
		_alert_label.add_theme_color_override("font_color", AMBER)
		_alert_label.modulate.a = 0.7 + 0.3 * sin(_time * 4.0)
	else:
		_alert_label.text = ""
		_alert_label.modulate.a = 1.0
	if level == 2 and _last_alert < 2:
		push_toast("SPOTTED!", BLOOD)
		if _player and _player.has_method("add_shake"):
			_player.add_shake(0.4)
	_last_alert = level


func _update_stamina() -> void:
	if _stamina_bar == null or _player == null:
		return
	var value := float(_player.get("stamina"))
	var max_value := float(_player.get("stamina_max"))
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value
	var ratio := value / maxf(1.0, max_value)
	if _stamina_value:
		_stamina_value.text = "%d" % int(round(value))
	var color := GREEN
	if ratio < 0.2:
		color = BLOOD
	elif ratio < 0.5:
		color = AMBER
	_stamina_bar.modulate = color


func _update_vignette(delta: float) -> void:
	if _vignette_mat == null:
		return
	var target := 0.34
	if _game and _game.is_night():
		target += 0.12
	if _danger >= 2:
		target += 0.32
	elif _danger == 1:
		target += 0.12
	if _scratch_panel and _scratch_panel.visible:
		target += 0.22
	var raw = _vignette_mat.get_shader_parameter("intensity")
	var current := 0.34 if raw == null else float(raw)
	_vignette_mat.set_shader_parameter("intensity", lerpf(current, target, clampf(delta * 3.0, 0.0, 1.0)))


func push_toast(text: String, color: Color = BONE) -> void:
	if _toast_box == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SP_SM)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(3, 18)
	row.add_child(bar)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(label)

	row.modulate.a = 0.0
	_toast_box.add_child(row)
	var tween := create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.3)
	tween.tween_property(row, "modulate:a", 0.0, 0.6)
	tween.tween_callback(row.queue_free)


func set_coins(value: int) -> void:
	if _coins_label:
		_coins_label.text = "%d" % value


func set_prompt(text: String) -> void:
	if _prompt_label:
		_prompt_label.text = text


func _on_ticket_held(type: TicketType) -> void:
	if type == null:
		return
	_scratch_type = type
	_completing = false
	_scratch_title.text = type.type_name
	var profile: Dictionary = Progression.profile(type.type_name)
	var level := int(profile["level"])
	_scratch_level.text = "Level %d / %d" % [level, type.level_cap]
	var need := type.xp_to_next(level)
	var target_xp := int(profile["xp"])
	if _xp_tween and _xp_tween.is_valid():
		_xp_tween.kill()
	if need > 0:
		_scratch_xp_bar.max_value = need
		_scratch_xp_bar.value = 0
		_scratch_xp_label.text = "%d / %d XP to next level" % [target_xp, need]
	else:
		_scratch_xp_bar.max_value = 1
		_scratch_xp_bar.value = 1
		_scratch_xp_label.text = "Max level"
	_populate_prizes(type)
	_show_scratch_panel()
	if need > 0:
		_xp_tween = create_tween()
		_xp_tween.tween_property(_scratch_xp_bar, "value", float(target_xp), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_ticket_released() -> void:
	if _completing:
		return
	_hide_scratch_panel()


func _hide_scratch_panel() -> void:
	_completing = false
	if _scratch_panel:
		_scratch_panel.visible = false
	if _focus_dim:
		_focus_dim.visible = false


func _on_ticket_completed(result: Dictionary) -> void:
	var xp := int(result.get("xp", 0))
	var coins := int(result.get("coins", 0))
	if xp > 0:
		push_toast("+%d XP" % xp, GOLD)
	if coins > 0:
		push_toast("+%d coins" % coins, GOLD)
	if int(result.get("levels_gained", 0)) > 0:
		push_toast("LEVEL UP  \u2192  %d" % int(result.get("level", 0)), AMBER)
	if _scratch_type != null:
		_completing = true
		_animate_xp_after_award(result)
		_schedule_hide(1.7)


func _animate_xp_after_award(result: Dictionary) -> void:
	var type := _scratch_type
	var profile: Dictionary = Progression.profile(type.type_name)
	var new_level := int(profile["level"])
	var new_xp := int(profile["xp"])
	var need := type.xp_to_next(new_level)
	var levels_gained := int(result.get("levels_gained", 0))
	if _xp_tween and _xp_tween.is_valid():
		_xp_tween.kill()
	_xp_burst_time = 0.9
	var duration := 0.6
	if levels_gained > 0:
		_scratch_xp_bar.max_value = maxf(1.0, _scratch_xp_bar.max_value)
		_xp_tween = create_tween()
		_xp_tween.tween_property(_scratch_xp_bar, "value", _scratch_xp_bar.max_value, duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_xp_tween.tween_callback(_on_level_filled.bind(new_level, type.level_cap, need))
		_xp_tween.tween_property(_scratch_xp_bar, "value", float(new_xp), duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_scratch_xp_bar.max_value = float(need) if need > 0 else 1.0
		_xp_tween = create_tween()
		_xp_tween.tween_property(_scratch_xp_bar, "value", float(new_xp), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_xp_tween.tween_callback(_set_xp_label.bind(new_xp, need))


func _on_level_filled(level: int, cap: int, need: int) -> void:
	_scratch_level.text = "Level %d / %d" % [level, cap]
	_scratch_xp_bar.max_value = float(need) if need > 0 else 1.0
	_scratch_xp_bar.value = 0.0
	_xp_burst_time = maxf(_xp_burst_time, 0.6)


func _set_xp_label(xp: int, need: int) -> void:
	if need > 0:
		_scratch_xp_label.text = "%d / %d XP to next level" % [xp, need]
	else:
		_scratch_xp_label.text = "Max level"


func _schedule_hide(delay: float) -> void:
	_hide_token += 1
	var token := _hide_token
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		if token == _hide_token:
			_hide_scratch_panel()
	)


func _update_xp_burst(delta: float) -> void:
	if _xp_burst_time <= 0.0:
		return
	_xp_burst_time -= delta
	_xp_burst_accum += delta
	while _xp_burst_accum >= 0.03:
		_xp_burst_accum -= 0.03
		_spawn_xp_mote()


func _spawn_xp_mote() -> void:
	if _scratch_xp_bar == null or _spark_layer == null:
		return
	var ratio := 0.0
	if _scratch_xp_bar.max_value > 0.0:
		ratio = clampf(_scratch_xp_bar.value / _scratch_xp_bar.max_value, 0.0, 1.0)
	var base := _scratch_xp_bar.global_position
	var pos := Vector2(base.x + _scratch_xp_bar.size.x * ratio, base.y + _scratch_xp_bar.size.y * 0.5)
	var mote := ColorRect.new()
	mote.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.95)
	mote.size = Vector2(3, 3)
	mote.position = pos - mote.size * 0.5
	mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_layer.add_child(mote)
	var drift := Vector2(randf_range(-10.0, 10.0), randf_range(-26.0, -14.0))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mote, "position", mote.position + drift, 0.5)
	tween.tween_property(mote, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(mote.queue_free)


func _show_scratch_panel() -> void:
	_hide_token += 1
	_scratch_panel.visible = true
	_focus_dim.visible = true
	_scratch_panel.modulate.a = 0.0
	var base_x := float(UiTheme.SP_LG)
	_scratch_panel.position.x = base_x - 24.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_scratch_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(_scratch_panel, "position:x", base_x, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _populate_prizes(type: TicketType) -> void:
	for child in _scratch_rows.get_children():
		_scratch_rows.remove_child(child)
		child.queue_free()
	var total := 0.0
	var entries := []
	for icon in type.icons:
		var weight := Progression.icon_weight(type, icon.id)
		if weight > 0.0:
			entries.append({"icon": icon, "weight": weight})
			total += weight
	for entry in entries:
		var icon: TicketIcon = entry["icon"]
		var chance := (float(entry["weight"]) / total) * 100.0 if total > 0.0 else 0.0
		_scratch_rows.add_child(_make_prize_row(type, icon, chance))


func _make_prize_row(type: TicketType, icon: TicketIcon, chance: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SP_SM)

	var glyph := Label.new()
	glyph.theme_type_variation = &"ChipLabel"
	glyph.text = icon.label
	glyph.add_theme_color_override("font_color", icon.color)
	glyph.custom_minimum_size = Vector2(96, 0)
	row.add_child(glyph)

	var chance_label := Label.new()
	chance_label.theme_type_variation = &"MutedLabel"
	chance_label.text = _format_chance(chance)
	chance_label.custom_minimum_size = Vector2(52, 0)
	chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(chance_label)

	var reward := Label.new()
	reward.theme_type_variation = &"ChipLabel"
	reward.text = _icon_reward(type, icon)
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(reward)
	return row


func _format_chance(chance: float) -> String:
	if chance >= 10.0:
		return "%d%%" % int(round(chance))
	return "%.1f%%" % chance


func _icon_reward(type: TicketType, icon: TicketIcon) -> String:
	var parts := []
	var xp := icon.xp + Progression.icon_xp_bonus(type, icon.id)
	if xp > 0:
		parts.append("+%d XP" % xp)
	if icon.coins > 0:
		parts.append("+%d coin%s" % [icon.coins, "" if icon.coins == 1 else "s"])
	if parts.is_empty():
		return "\u2014"
	return "  ".join(parts)
