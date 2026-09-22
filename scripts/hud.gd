extends Control

var _game: Node
var _player: Node
var _phase_label: Label
var _timer_label: Label
var _carried_label: Label
var _gadget_label: Label
var _death_label: Label
var _alert_label: Label
var _stamina_bar: ProgressBar


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game")
	_player = get_tree().get_first_node_in_group("player")
	_phase_label = get_node_or_null("PhaseLabel")
	_timer_label = get_node_or_null("NightTimer")
	_carried_label = get_node_or_null("Carried")
	_gadget_label = get_node_or_null("Gadget")
	_death_label = get_node_or_null("DeathMessage")
	_alert_label = get_node_or_null("Alert")
	_stamina_bar = get_node_or_null("Stamina")
	if _game:
		_game.phase_changed.connect(_on_phase_changed)
		_game.backpack_changed.connect(refresh)
		_game.gadgets_changed.connect(refresh)
		_game.player_died.connect(_on_player_died)
	refresh()


func _process(_delta: float) -> void:
	_update_timer()
	_update_alert()
	_update_stamina()


func refresh() -> void:
	if _game == null:
		return
	if _phase_label:
		_phase_label.text = "NIGHT" if _game.is_night() else "DAY"
	if _carried_label:
		_carried_label.text = "Tickets: %d / %d" % [_game.backpack.size(), _game.effective_backpack_capacity()]
	if _gadget_label:
		_gadget_label.text = "Stun: %d" % _game.gadget_charges
	_update_timer()


func _update_timer() -> void:
	if _game == null or _timer_label == null:
		return
	if _game.is_night():
		_timer_label.text = "Night: %d" % int(ceil(_game.night_time_left))
	else:
		_timer_label.text = ""


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
		_alert_label.add_theme_color_override("font_color", Color(0.95, 0.15, 0.12))
	elif level == 1:
		_alert_label.text = "?"
		_alert_label.add_theme_color_override("font_color", Color(0.96, 0.72, 0.16))
	else:
		_alert_label.text = ""


func _update_stamina() -> void:
	if _stamina_bar == null or _player == null:
		return
	var value := float(_player.get("stamina"))
	var max_value := float(_player.get("stamina_max"))
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value
	var ratio := value / maxf(1.0, max_value)
	var color := Color(0.35, 0.8, 0.4)
	if ratio < 0.2:
		color = Color(0.9, 0.2, 0.15)
	elif ratio < 0.5:
		color = Color(0.92, 0.72, 0.2)
	_stamina_bar.modulate = color
