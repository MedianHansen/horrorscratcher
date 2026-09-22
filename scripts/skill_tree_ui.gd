extends Control

@export var ticket_type: TicketType

const NODE_SIZE := 64.0
const H_SPACE := 130.0
const V_SPACE := 140.0
const TOP_MARGIN := 40.0
const BOTTOM_MARGIN := 20.0

var _player: Node
var _points_label: Label
var _tree_area: Control
var _tooltip_title: Label
var _tooltip_body: Label
var _tooltip_hint: Label


func _ready() -> void:
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

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "%s - Talents" % (ticket_type.type_name if ticket_type else "?")
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_points_label = Label.new()
	box.add_child(_points_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	box.add_child(hbox)

	_tree_area = Control.new()
	_tree_area.set_script(load("res://scripts/skill_tree_lines.gd"))
	_tree_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_tree_area.custom_minimum_size = Vector2(420, 260)
	hbox.add_child(_tree_area)

	var tip := PanelContainer.new()
	tip.custom_minimum_size = Vector2(290, 230)
	hbox.add_child(tip)
	var tip_margin := MarginContainer.new()
	tip_margin.add_theme_constant_override("margin_left", 12)
	tip_margin.add_theme_constant_override("margin_right", 12)
	tip_margin.add_theme_constant_override("margin_top", 10)
	tip_margin.add_theme_constant_override("margin_bottom", 10)
	tip.add_child(tip_margin)
	var tip_box := VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 8)
	tip_margin.add_child(tip_box)
	_tooltip_title = Label.new()
	_tooltip_title.add_theme_font_size_override("font_size", 20)
	tip_box.add_child(_tooltip_title)
	_tooltip_body = Label.new()
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_body.custom_minimum_size = Vector2(266, 0)
	tip_box.add_child(_tooltip_body)
	_tooltip_hint = Label.new()
	_tooltip_hint.modulate = Color(1, 1, 1, 0.65)
	_tooltip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_hint.custom_minimum_size = Vector2(266, 0)
	tip_box.add_child(_tooltip_hint)

	var hint := Label.new()
	hint.text = "Click a skill to learn it. T or ESC to close."
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


func _refresh() -> void:
	if ticket_type == null:
		return
	var profile: Dictionary = Progression.profile(ticket_type.type_name)
	_points_label.text = "Level %d    Normal points: %d    Epic points: %d" % [
		int(profile["level"]), int(profile["normal"]), int(profile["epic"])
	]
	_build_tree()
	if _tooltip_title.text == "":
		_tooltip_title.text = "Hover a skill"
		_tooltip_body.text = "Click a node to spend a point."
		_tooltip_hint.text = ""


func _build_tree() -> void:
	for child in _tree_area.get_children():
		child.queue_free()

	var depths := {}
	for skill in ticket_type.skills:
		depths[skill.id] = _depth_of(skill)

	var layers := {}
	var max_cols := 1
	for skill in ticket_type.skills:
		var d: int = depths[skill.id]
		if not layers.has(d):
			layers[d] = []
		layers[d].append(skill)
		max_cols = maxi(max_cols, layers[d].size())

	var layer_count := 0
	for d in layers.keys():
		layer_count = maxi(layer_count, int(d) + 1)

	var width := float(max_cols) * H_SPACE
	var height := TOP_MARGIN + float(maxi(0, layer_count - 1)) * V_SPACE + NODE_SIZE + BOTTOM_MARGIN
	_tree_area.custom_minimum_size = Vector2(width, height)

	var positions := {}
	for d in range(layer_count):
		var layer: Array = layers.get(d, [])
		var count := layer.size()
		for i in range(count):
			var skill: Skill = layer[i]
			var center := Vector2(
				width * 0.5 + (float(i) - float(count - 1) * 0.5) * H_SPACE,
				TOP_MARGIN + float(d) * V_SPACE + NODE_SIZE * 0.5
			)
			positions[skill.id] = center
			_add_node(skill, center)

	var links := []
	for skill in ticket_type.skills:
		if skill.requires == &"" or not positions.has(skill.id) or not positions.has(skill.requires):
			continue
		var a: Vector2 = positions[skill.requires]
		var b: Vector2 = positions[skill.id]
		var met := Progression.rank(ticket_type.type_name, skill.requires) > 0
		var color := Color(0.9, 0.75, 0.2) if met else Color(0.28, 0.28, 0.32)
		links.append({
			"from": a + Vector2(0, NODE_SIZE * 0.5),
			"to": b - Vector2(0, NODE_SIZE * 0.5),
			"color": color,
		})
	_tree_area.set_links(links)


func _add_node(skill: Skill, center: Vector2) -> void:
	var node := SkillNode.new()
	var rank := Progression.rank(ticket_type.type_name, skill.id)
	var locked := skill.requires != &"" and Progression.rank(ticket_type.type_name, skill.requires) <= 0
	node.setup(skill, rank, Progression.can_buy(ticket_type, skill), locked)
	node.position = center - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
	_tree_area.add_child(node)
	node.pressed.connect(_on_node_pressed)
	node.hovered.connect(_show_tooltip)


func _depth_of(skill: Skill) -> int:
	var depth := 0
	var current := skill
	var guard := 0
	while current.requires != &"" and guard < 32:
		var parent := _find_skill(current.requires)
		if parent == null:
			break
		depth += 1
		current = parent
		guard += 1
	return depth


func _find_skill(id: StringName) -> Skill:
	for skill in ticket_type.skills:
		if skill.id == id:
			return skill
	return null


func _show_tooltip(skill: Skill) -> void:
	if skill == null:
		return
	var rank := Progression.rank(ticket_type.type_name, skill.id)
	_tooltip_title.text = skill.title
	var lines := [skill.description, "", "Rank: %d / %d" % [rank, skill.max_ranks]]
	lines.append("Cost: 1 %s point" % ("epic" if skill.cost == Skill.Cost.EPIC else "normal"))
	if skill.requires != &"":
		var parent := _find_skill(skill.requires)
		var parent_rank := Progression.rank(ticket_type.type_name, skill.requires)
		var name := parent.title if parent != null else String(skill.requires)
		lines.append("Requires: %s (%s)" % [name, "met" if parent_rank > 0 else "locked"])
	_tooltip_body.text = "\n".join(lines)
	if rank >= skill.max_ranks:
		_tooltip_hint.text = "Maxed out."
	elif Progression.can_buy(ticket_type, skill):
		_tooltip_hint.text = "Click to learn."
	else:
		_tooltip_hint.text = "Not enough points."


func _on_node_pressed(skill: Skill) -> void:
	if ticket_type and Progression.buy(ticket_type, skill):
		_refresh()


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
