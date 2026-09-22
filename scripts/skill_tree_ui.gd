extends Control

@export var ticket_type: TicketType

var _player: Node
var _points_label: Label
var _rows: Array = []


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_build()
	visible = false


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "%s - Skill Tree" % (ticket_type.type_name if ticket_type else "?")
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_points_label = Label.new()
	box.add_child(_points_label)

	if ticket_type:
		for skill in ticket_type.skills:
			box.add_child(_make_row(skill))

	var hint := Label.new()
	hint.text = "T or ESC to close"
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


func _make_row(skill: Skill) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = skill.title
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)

	var desc := Label.new()
	desc.text = skill.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(440, 0)
	row.add_child(desc)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)

	var rank_label := Label.new()
	rank_label.custom_minimum_size = Vector2(130, 0)
	line.add_child(rank_label)

	var cost_label := Label.new()
	cost_label.custom_minimum_size = Vector2(150, 0)
	line.add_child(cost_label)

	var button := Button.new()
	button.text = "Learn"
	button.pressed.connect(_buy.bind(skill))
	line.add_child(button)

	row.add_child(line)
	_rows.append({"skill": skill, "rank": rank_label, "cost": cost_label, "button": button})
	return row


func _buy(skill: Skill) -> void:
	if ticket_type and Progression.buy(ticket_type, skill):
		_refresh()


func _refresh() -> void:
	if ticket_type == null:
		return
	var p: Dictionary = Progression.profile(ticket_type.type_name)
	_points_label.text = "Level %d    Normal points: %d    Epic points: %d" % [
		int(p["level"]), int(p["normal"]), int(p["epic"])
	]
	for row in _rows:
		var skill: Skill = row["skill"]
		var r := Progression.rank(ticket_type.type_name, skill.id)
		row["rank"].text = "Rank %d/%d" % [r, skill.max_ranks]
		row["cost"].text = "Cost: 1 %s" % ("epic" if skill.cost == Skill.Cost.EPIC else "normal")
		var can := Progression.can_buy(ticket_type, skill)
		var button: Button = row["button"]
		button.disabled = not can
		if r >= skill.max_ranks:
			button.text = "Maxed"
		elif skill.requires != &"" and Progression.rank(ticket_type.type_name, skill.requires) <= 0:
			button.text = "Locked"
		else:
			button.text = "Learn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skills"):
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
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(true)


func _close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(false)
