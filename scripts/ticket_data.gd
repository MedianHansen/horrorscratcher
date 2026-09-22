class_name TicketData
extends RefCounted

var type: TicketType
var panels: Array = []


func panel_count() -> int:
	return panels.size()


func to_dict() -> Dictionary:
	var out := {"type": ""}
	if type != null:
		out["type"] = type.resource_path
	var panels_out := []
	for p in panels:
		var icon: TicketIcon = p.get("icon")
		var health: PackedFloat32Array = p.get("health", PackedFloat32Array())
		panels_out.append({
			"icon": String(icon.id) if icon != null else "",
			"health": Array(health),
			"damage": float(p.get("damage", 0.0)),
			"revealed": bool(p.get("revealed", false)),
		})
	out["panels"] = panels_out
	return out


static func from_dict(d: Dictionary) -> TicketData:
	var data := TicketData.new()
	var path := String(d.get("type", ""))
	if path != "" and ResourceLoader.exists(path):
		data.type = load(path)
	for p in d.get("panels", []):
		var icon: TicketIcon = null
		var icon_id := String(p.get("icon", ""))
		if data.type != null:
			for candidate in data.type.icons:
				if String(candidate.id) == icon_id:
					icon = candidate
					break
		var health := PackedFloat32Array()
		for value in p.get("health", []):
			health.append(float(value))
		data.panels.append({
			"icon": icon,
			"health": health,
			"damage": float(p.get("damage", 0.0)),
			"revealed": bool(p.get("revealed", false)),
		})
	return data
