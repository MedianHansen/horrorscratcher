extends Control

const BONE := UiTheme.BONE
const AMBER := UiTheme.AMBER
const GOLD := UiTheme.GOLD
const BLOOD := UiTheme.BLOOD
const MUTED := UiTheme.MUTED
const GREEN := UiTheme.GREEN

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
var _last_alert := 0


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
	resized.connect(queue_redraw)
	refresh()


func _process(_delta: float) -> void:
	_update_timer()
	_update_alert()
	_update_stamina()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_status()
	_build_coins()
	_build_stamina()
	_build_chips()
	_build_center()
	_build_toasts()


func _build_status() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.anchor_left = 0.0
	_status_panel.anchor_top = 0.0
	_status_panel.offset_left = 16.0
	_status_panel.offset_top = 16.0
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_status_panel.add_child(box)

	_phase_label = Label.new()
	_phase_label.theme_type_variation = &"TitleLabel"
	_phase_label.text = "DAY"
	box.add_child(_phase_label)

	_timer_label = Label.new()
	_timer_label.theme_type_variation = &"MutedLabel"
	box.add_child(_timer_label)


func _build_coins() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
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
	var box := VBoxContainer.new()
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 16.0
	box.offset_bottom = -16.0
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.custom_minimum_size = Vector2(220, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)

	var title := Label.new()
	title.theme_type_variation = &"MutedLabel"
	title.text = "STAMINA"
	head.add_child(title)

	_stamina_value = Label.new()
	_stamina_value.theme_type_variation = &"MutedLabel"
	_stamina_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stamina_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_stamina_value)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(220, 14)
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
	panel.offset_right = -16.0
	panel.offset_bottom = -16.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

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
	_prompt_label.offset_left = -320.0
	_prompt_label.offset_right = 320.0
	_prompt_label.offset_bottom = -72.0
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
	_toast_box.offset_bottom = -110.0
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override("separation", 4)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 2.0, Color(1, 1, 1, 0.75))
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + dir * 5.0, center + dir * 10.0, Color(1, 1, 1, 0.55), 1.5)


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
		_coins_label.text = "%d" % int(_player.get("coins"))


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
	if level >= 2:
		_alert_label.text = "SPOTTED!"
		_alert_label.modulate = Color(1, 1, 1, 1)
	elif level == 1:
		_alert_label.text = "?"
		_alert_label.modulate = Color(1, 1, 1, 0.9)
	else:
		_alert_label.text = ""
	if level == 2 and _last_alert < 2:
		push_toast("SPOTTED!", BLOOD)
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


func _on_ticket_completed(result: Dictionary) -> void:
	var xp := int(result.get("xp", 0))
	var coins := int(result.get("coins", 0))
	if xp > 0:
		push_toast("+%d XP" % xp, GOLD)
	if coins > 0:
		push_toast("+%d coins" % coins, GOLD)
	if int(result.get("levels_gained", 0)) > 0:
		push_toast("LEVEL UP  \u2192  %d" % int(result.get("level", 0)), AMBER)


func push_toast(text: String, color: Color = BONE) -> void:
	if _toast_box == null:
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_toast_box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(1.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func set_coins(value: int) -> void:
	if _coins_label:
		_coins_label.text = "%d" % value


func set_prompt(text: String) -> void:
	if _prompt_label:
		_prompt_label.text = text
