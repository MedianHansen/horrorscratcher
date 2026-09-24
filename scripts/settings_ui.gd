extends Control

const ROWS := [
	{"key": "head_bob", "label": "Head bob", "desc": "Camera bobs while you walk and run."},
	{"key": "screen_shake", "label": "Screen shake", "desc": "Camera shakes on danger and payouts."},
]

var _game: Node
var _player: Node
var _panel: PanelContainer
var _buttons: Dictionary = {}


func _ready() -> void:
	theme = UiTheme.shared()
	_game = get_tree().get_first_node_in_group("game")
	_player = get_tree().get_first_node_in_group("player")
	_build()
	visible = false


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UiTheme.SP_XL)
	margin.add_theme_constant_override("margin_right", UiTheme.SP_XL)
	margin.add_theme_constant_override("margin_top", UiTheme.SP_LG)
	margin.add_theme_constant_override("margin_bottom", UiTheme.SP_LG)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.SP_MD)
	box.custom_minimum_size = Vector2(460, 0)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Settings"
	title.theme_type_variation = &"TitleLabel"
	box.add_child(title)

	var rule := ColorRect.new()
	rule.color = UiTheme.AMBER
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)

	for row in ROWS:
		box.add_child(_make_row(row))

	var hint := Label.new()
	hint.text = "O or ESC to close"
	hint.theme_type_variation = &"MutedLabel"
	box.add_child(hint)


func _make_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UiTheme.SP_LG)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)

	var name := Label.new()
	name.text = row["label"]
	name.theme_type_variation = &"HeadingLabel"
	text.add_child(name)

	var desc := Label.new()
	desc.text = row["desc"]
	desc.theme_type_variation = &"MutedLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(320, 0)
	text.add_child(desc)

	var button := Button.new()
	button.custom_minimum_size = Vector2(84, 0)
	button.pressed.connect(_on_toggle.bind(String(row["key"])))
	line.add_child(button)
	_buttons[String(row["key"])] = button
	return line


func _refresh() -> void:
	if _game == null:
		return
	for row in ROWS:
		var key := String(row["key"])
		var button: Button = _buttons.get(key)
		if button == null:
			continue
		var on: bool = _game.get_setting(key)
		button.text = "ON" if on else "OFF"
		button.add_theme_color_override("font_color", UiTheme.AMBER if on else UiTheme.MUTED)


func _on_toggle(key: String) -> void:
	if _game == null:
		return
	var current: bool = _game.get_setting(key)
	_game.set_setting(key, not current)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("settings"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if visible:
		_close()
	else:
		_open()


func _open() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player and bool(_player.get("input_locked")):
		return
	visible = true
	_refresh()
	_animate_open()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(true)


func _close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(false)


func _animate_open() -> void:
	if _panel == null:
		return
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.98, 0.98)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
