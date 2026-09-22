extends Interactable

@export var gadget: Gadget


func _ready() -> void:
	super()
	activated.connect(_on_activated)


func _on_activated(player: Node) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game and gadget:
		game.buy_gadget(gadget)


func _prompt_text() -> String:
	if gadget == null:
		return "Gadget bench"
	var game := get_tree().get_first_node_in_group("game")
	if game and game.gadgets.has(gadget.id):
		return "%s (owned) - %d charges/night" % [gadget.title, gadget.charges_per_night]
	var player := get_tree().get_first_node_in_group("player")
	var coins := int(player.get("coins")) if player else 0
	if coins < gadget.cost:
		return "%s costs %d coins (you have %d)" % [gadget.title, gadget.cost, coins]
	return "Press E to buy %s (%d coins)" % [gadget.title, gadget.cost]
