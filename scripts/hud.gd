extends Control

var _game: Node
var _phase_label: Label
var _timer_label: Label
var _carried_label: Label
var _gadget_label: Label
var _death_label: Label


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game")
	_phase_label = get_node_or_null("PhaseLabel")
	_timer_label = get_node_or_null("NightTimer")
	_carried_label = get_node_or_null("Carried")
	_gadget_label = get_node_or_null("Gadget")
	_death_label = get_node_or_null("DeathMessage")
	if _game:
		_game.phase_changed.connect(_on_phase_changed)
		_game.backpack_changed.connect(refresh)
		_game.gadgets_changed.connect(refresh)
		_game.player_died.connect(_on_player_died)
	refresh()


func _process(_delta: float) -> void:
	_update_timer()


func refresh() -> void:
	if _game == null:
		return
	if _phase_label:
		_phase_label.text = "NIGHT" if _game.is_night() else "DAY"
	if _carried_label:
		_carried_label.text = "Tickets: %d / %d" % [_game.backpack.size(), _game.backpack_capacity]
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
