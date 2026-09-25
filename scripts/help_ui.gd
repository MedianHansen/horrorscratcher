extends Control

const SECTIONS := [
	{"title": "Movement", "rows": [
		["WASD", "Move"],
		["Shift", "Sprint (drains stamina)"],
		["Space", "Jump"],
		["Mouse", "Look"],
		["ESC", "Release mouse"],
	]},
	{"title": "Tickets", "rows": [
		["E", "Pocket a ticket / interact"],
		["Q", "Hold a ticket to scratch it"],
		["Left Mouse", "Scrub the foil"],
		["E / ESC", "Stow the held ticket"],
	]},
	{"title": "Hideout", "rows": [
		["E", "Bed: sleep and start the night"],
		["E", "Stash: deposit carried tickets"],
		["E", "Gadget bench / Workshop: buy"],
		["G", "Use the Stun Device (night)"],
	]},
	{"title": "Menus", "rows": [
		["T", "Skill tree"],
		["O", "Settings"],
		["F1", "This help"],
		["H", "Guest sense debug overlays"],
	]},
]

var _player: Node
var _panel: PanelContainer


func _ready() -> void:
	theme = UiTheme.shared()
	_player = get_tree().get_first_node_in_group("player")
	_build()
	visible = false


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
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
	box.custom_minimum_size = Vector2(560, 0)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Controls"
	title.theme_type_variation = &"TitleLabel"
	box.add_child(title)

	var rule := ColorRect.new()
	rule.color = UiTheme.AMBER
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)

	for section in SECTIONS:
		var heading := Label.new()
		heading.text = section["title"].to_upper()
		heading.theme_type_variation = &"SectionLabel"
		box.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", UiTheme.SP_LG)
		grid.add_theme_constant_override("v_separation", 2)
		box.add_child(grid)
		for row in section["rows"]:
			var key := Label.new()
			key.text = "[%s]" % row[0]
			key.theme_type_variation = &"ChipLabel"
			key.add_theme_color_override("font_color", UiTheme.AMBER)
			key.custom_minimum_size = Vector2(120, 0)
			grid.add_child(key)
			var desc := Label.new()
			desc.text = row[1]
			desc.theme_type_variation = &"BodyLabel"
			grid.add_child(desc)

	var hint := Label.new()
	hint.text = "F1 or ESC to close"
	hint.theme_type_variation = &"MutedLabel"
	box.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
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
