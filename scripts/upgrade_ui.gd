extends Control

var _game: Node
var _player: Node
var _coins_label: Label
var _rows: Array = []


func _ready() -> void:
	add_to_group("upgrade_ui")
	_game = get_tree().get_first_node_in_group("game")
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
	title.text = "Workshop - Upgrades"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_coins_label = Label.new()
	box.add_child(_coins_label)

	if _game:
		for id in _game.upgrade_ids():
			box.add_child(_make_row(id))

	var hint := Label.new()
	hint.text = "ESC to close"
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


func _make_row(id: StringName) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = _game.upgrade_title(id)
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)

	var desc := Label.new()
	desc.text = _game.upgrade_description(id)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(440, 0)
	row.add_child(desc)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)

	var level_label := Label.new()
	level_label.custom_minimum_size = Vector2(150, 0)
	line.add_child(level_label)

	var cost_label := Label.new()
	cost_label.custom_minimum_size = Vector2(150, 0)
	line.add_child(cost_label)

	var button := Button.new()
	button.text = "Buy"
	button.pressed.connect(_buy.bind(id))
	line.add_child(button)

	row.add_child(line)
	_rows.append({"id": id, "level": level_label, "cost": cost_label, "button": button})
	return row


func _buy(id: StringName) -> void:
	if _game and _game.buy_upgrade(id):
		_refresh()


func _refresh() -> void:
	if _game == null:
		return
	var coins := int(_player.get("coins")) if _player else 0
	_coins_label.text = "Coins: %d" % coins
	for row in _rows:
		var id: StringName = row["id"]
		var level: int = int(_game.upgrade_level(id))
		var max_level: int = int(_game.upgrade_max(id))
		row["level"].text = "Level %d/%d" % [level, max_level]
		var cost: int = int(_game.upgrade_cost(id))
		if cost < 0:
			row["cost"].text = "Maxed"
		else:
			row["cost"].text = "Cost: %d coins" % cost
		var button: Button = row["button"]
		button.disabled = not _game.can_buy_upgrade(id)
		button.text = "Maxed" if cost < 0 else "Buy"


func open() -> void:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player and bool(_player.get("input_locked")):
		return
	visible = true
	_refresh()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(true)


func close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(false)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
