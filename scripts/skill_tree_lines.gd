extends Control

var _links: Array = []


func set_links(links: Array) -> void:
	_links = links
	queue_redraw()


func _draw() -> void:
	for link in _links:
		draw_line(link["from"], link["to"], link["color"], 3.0)
