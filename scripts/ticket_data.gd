class_name TicketData
extends RefCounted

var type: TicketType
var panels: Array = []


func panel_count() -> int:
	return panels.size()
