extends Control

var _game: Node
var _player: Node
var _coins_label: Label
var _scroll: ScrollContainer
var _panel: PanelContainer
var _rows: Array = []


func _ready() -> void:
	add_to_group("upgrade_ui")
	theme = UiTheme.shared()
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
	_panel = panel

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
	title.theme_type_variation = &"TitleLabel"
	box.add_child(title)

	var rule := ColorRect.new()
	rule.color = UiTheme.AMBER
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)

	_coins_label = Label.new()
	_coins_label.theme_type_variation = &"GoldLabel"
	box.add_child(_coins_label)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(480, 360)
	box.add_child(_scroll)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(rows)

	if _game:
		for id in _game.upgrade_ids():
			rows.add_child(_make_row(id))

	var reset := Button.new()
	reset.text = "Reset save (wipe progress)"
	reset.theme_type_variation = &"DangerButton"
	reset.pressed.connect(_reset)
	box.add_child(reset)

	var hint := Label.new()
	hint.text = "ESC to close"
	hint.theme_type_variation = &"MutedLabel"
	box.add_child(hint)


func _reset() -> void:
	if _game and _game.has_method("reset_save"):
		_game.reset_save()
	_refresh()


func _make_row(id: StringName) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	card.add_child(row)

	var title := Label.new()
	title.text = _game.upgrade_title(id)
	title.theme_type_variation = &"HeadingLabel"
	row.add_child(title)

	var desc := Label.new()
	desc.text = _game.upgrade_description(id)
	desc.theme_type_variation = &"MutedLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(420, 0)
	row.add_child(desc)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)

	var level_label := Label.new()
	level_label.theme_type_variation = &"ChipLabel"
	level_label.custom_minimum_size = Vector2(150, 0)
	line.add_child(level_label)

	var cost_label := Label.new()
	cost_label.theme_type_variation = &"ChipLabel"
	cost_label.custom_minimum_size = Vector2(150, 0)
	line.add_child(cost_label)

	var button := Button.new()
	button.text = "Buy"
	button.pressed.connect(_buy.bind(id))
	line.add_child(button)

	row.add_child(line)
	_rows.append({"id": id, "level": level_label, "cost": cost_label, "button": button})
	return card


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
	if _scroll:
		var available := get_viewport_rect().size.y * 0.62
		_scroll.custom_minimum_size.y = clampf(available, 220.0, 720.0)
	visible = true
	_refresh()
	_animate_open()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(true)


func close() -> void:
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


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
