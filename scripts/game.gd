extends Node

signal phase_changed(phase: int)
signal night_started()
signal day_started()
signal backpack_changed()
signal gadgets_changed()
signal upgrades_changed()
signal player_died()

enum Phase { DAY, NIGHT }

const TICKET_SCENE_PATH := "res://scenes/scratch_ticket.tscn"
const ACTIVE_GADGET := &"stun"
const UPGRADES := {
	&"scratch_damage": {
		"title": "Scratch Damage",
		"description": "+25% scratch damage per level.",
		"max": 10,
		"mult": 1.25,
		"base_cost": 20,
	},
	&"move_speed": {
		"title": "Movement Speed",
		"description": "+10% movement speed per level.",
		"max": 5,
		"mult": 1.10,
		"base_cost": 30,
	},
	&"trashcan": {
		"title": "Trashcan",
		"description": "Unlocks a bin in the hideout to discard a held ticket.",
		"max": 1,
		"mult": 1.0,
		"base_cost": 1,
	},
	&"bag_space": {
		"title": "Bag Space",
		"description": "+2 backpack slots per level.",
		"max": 5,
		"mult": 1.0,
		"base_cost": 60,
	},
	&"brush_size": {
		"title": "Brush Size",
		"description": "+20% scratch brush radius per level.",
		"max": 5,
		"mult": 1.2,
		"base_cost": 35,
	},
	&"restful_bed": {
		"title": "Restful Bed",
		"description": "Sleeping restores 10 stamina instead of 5.",
		"max": 1,
		"mult": 1.0,
		"base_cost": 80,
	},
}

var night_duration: float = 120.0
var tickets_per_night: int = 10
var backpack_capacity: int = 5
var noise_sprint_radius: float = 12.0
var noise_walk_radius: float = 4.0
var capture_range: float = 1.2

var phase: int = Phase.DAY
var night_time_left: float = 0.0
var player_in_hideout: bool = true
var backpack: Array = []
var stash: Array = []
var gadgets: Dictionary = {}
var gadget_charges: int = 0
var upgrades: Dictionary = {}
var held_ticket: Node = null


func _ready() -> void:
	add_to_group("game")


func _unhandled_input(event: InputEvent) -> void:
	if held_ticket != null:
		return
	if not event.is_action_pressed("take_ticket"):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and bool(player.get("input_locked")):
		return
	if take_for_scratch():
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if phase != Phase.NIGHT or player_in_hideout:
		return
	night_time_left -= delta
	if night_time_left <= 0.0:
		end_night(false)


func is_night() -> bool:
	return phase == Phase.NIGHT


func set_phase(value: int) -> void:
	if phase == value:
		return
	phase = value
	phase_changed.emit(phase)


func start_night() -> void:
	if phase == Phase.NIGHT:
		return
	night_time_left = night_duration
	reset_gadgets()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("restore_stamina"):
		player.restore_stamina(float(sleep_stamina_rest()))
	set_phase(Phase.NIGHT)
	night_started.emit()


func end_night(safe: bool) -> void:
	if phase != Phase.NIGHT:
		return
	night_time_left = 0.0
	if not safe:
		cancel_held()
		backpack.clear()
		backpack_changed.emit()
		_teleport_player_home()
		player_died.emit()
	set_phase(Phase.DAY)
	_clear_guests()
	day_started.emit()


func pocket(data) -> bool:
	if backpack.size() >= backpack_capacity:
		return false
	backpack.append(data)
	backpack_changed.emit()
	return true


func deposit_all() -> int:
	var count := backpack.size()
	if count == 0:
		return 0
	stash.append_array(backpack)
	backpack.clear()
	backpack_changed.emit()
	return count


func buy_gadget(gadget: Gadget) -> bool:
	if gadget == null or gadgets.has(gadget.id):
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player == null or int(player.get("coins")) < gadget.cost:
		return false
	if player.has_method("add_coins"):
		player.add_coins(-gadget.cost)
	gadgets[gadget.id] = gadget
	if gadget.id == ACTIVE_GADGET:
		gadget_charges = gadget.charges_per_night
	gadgets_changed.emit()
	return true


func use_active_gadget() -> bool:
	if phase != Phase.NIGHT:
		return false
	var gadget = gadgets.get(ACTIVE_GADGET)
	if gadget == null or gadget_charges <= 0:
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var origin: Vector3 = (player as Node3D).global_position
	for guest in get_tree().get_nodes_in_group("guest"):
		if guest is Node3D and (guest as Node3D).global_position.distance_to(origin) <= gadget.stun_radius:
			if guest.has_method("stun"):
				guest.stun(gadget.stun_duration)
	gadget_charges -= 1
	gadgets_changed.emit()
	return true


func reset_gadgets() -> void:
	var gadget = gadgets.get(ACTIVE_GADGET)
	if gadget != null:
		gadget_charges = gadget.charges_per_night
		gadgets_changed.emit()


func upgrade_ids() -> Array:
	return UPGRADES.keys()


func upgrade_title(id: StringName) -> String:
	if not UPGRADES.has(id):
		return ""
	return String(UPGRADES[id]["title"])


func upgrade_description(id: StringName) -> String:
	if not UPGRADES.has(id):
		return ""
	return String(UPGRADES[id]["description"])


func upgrade_level(id: StringName) -> int:
	return int(upgrades.get(id, 0))


func upgrade_max(id: StringName) -> int:
	if not UPGRADES.has(id):
		return 0
	return int(UPGRADES[id]["max"])


func upgrade_cost(id: StringName) -> int:
	if not UPGRADES.has(id):
		return -1
	var level := upgrade_level(id)
	if level >= int(UPGRADES[id]["max"]):
		return -1
	return int(UPGRADES[id]["base_cost"]) * (level + 1)


func can_buy_upgrade(id: StringName) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0:
		return false
	var player := get_tree().get_first_node_in_group("player")
	return player != null and int(player.get("coins")) >= cost


func buy_upgrade(id: StringName) -> bool:
	if not can_buy_upgrade(id):
		return false
	var cost := upgrade_cost(id)
	var player := get_tree().get_first_node_in_group("player")
	if player.has_method("add_coins"):
		player.add_coins(-cost)
	upgrades[id] = upgrade_level(id) + 1
	upgrades_changed.emit()
	return true


func scratch_damage_multiplier() -> float:
	return _upgrade_multiplier(&"scratch_damage")


func move_speed_multiplier() -> float:
	return _upgrade_multiplier(&"move_speed")


func has_trashcan() -> bool:
	return upgrade_level(&"trashcan") > 0


func backpack_bonus() -> int:
	return 2 * upgrade_level(&"bag_space")


func effective_backpack_capacity() -> int:
	return backpack_capacity + backpack_bonus()


func brush_scale() -> float:
	return _upgrade_multiplier(&"brush_size")


func sleep_stamina_rest() -> int:
	return 10 if upgrade_level(&"restful_bed") > 0 else 5


func _upgrade_multiplier(id: StringName) -> float:
	if not UPGRADES.has(id):
		return 1.0
	return pow(float(UPGRADES[id]["mult"]), float(upgrade_level(id)))


func take_for_scratch() -> bool:
	if held_ticket != null or backpack.is_empty():
		return false
	var data = backpack[backpack.size() - 1]
	var scene: PackedScene = load(TICKET_SCENE_PATH)
	if scene == null:
		return false
	var ticket := scene.instantiate()
	ticket.ticket_type = data.type
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(ticket)
	ticket.stowed.connect(_on_ticket_stowed)
	ticket.finished.connect(_on_ticket_finished)
	ticket.discarded.connect(_on_ticket_discarded)
	ticket.hold(data)
	held_ticket = ticket
	return true


func cancel_held() -> void:
	if held_ticket != null and is_instance_valid(held_ticket):
		held_ticket.queue_free()
	held_ticket = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_input_locked"):
		player.set_input_locked(false)


func _on_ticket_stowed(_data) -> void:
	held_ticket = null


func _on_ticket_finished(data) -> void:
	backpack.erase(data)
	backpack_changed.emit()
	held_ticket = null


func _on_ticket_discarded(data) -> void:
	backpack.erase(data)
	backpack_changed.emit()
	held_ticket = null


func enter_hideout() -> void:
	player_in_hideout = true
	if phase == Phase.NIGHT:
		end_night(true)


func on_caught() -> void:
	if phase == Phase.NIGHT:
		end_night(false)
	else:
		_teleport_player_home()
		player_died.emit()


func exit_hideout() -> void:
	player_in_hideout = false


func _teleport_player_home() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var marker := get_tree().get_first_node_in_group("hideout_spawn")
	if player != null and marker != null and player is Node3D:
		(player as Node3D).global_position = (marker as Node3D).global_position
		player.set("velocity", Vector3.ZERO)
	player_in_hideout = true


func _clear_guests() -> void:
	for guest in get_tree().get_nodes_in_group("guest"):
		guest.queue_free()
