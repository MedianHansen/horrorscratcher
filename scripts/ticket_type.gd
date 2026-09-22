class_name TicketType
extends Resource

@export var type_name: String = ""
@export var tile_count: int = 3
@export var level_cap: int = 1
@export var level_xp: PackedInt32Array = PackedInt32Array()
@export var paper_color: Color = Color(0.93, 0.91, 0.84)
@export var icons: Array[TicketIcon] = []
@export var skills: Array[Skill] = []


func xp_to_next(level: int) -> int:
	var index := level - 1
	if index < 0 or index >= level_xp.size():
		return 0
	return level_xp[index]
