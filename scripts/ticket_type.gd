class_name TicketType
extends Resource

enum Special { NONE, DISTANCE_REWARD }

@export var type_name: String = ""
@export var tile_count: int = 3
@export var level_cap: int = 1
@export var xp_base: int = 5
@export var xp_growth: float = 1.5
@export var level_reward_bonus: float = 1.0
@export var spawn_per_night: float = 1.0
@export var min_night: int = 1
@export var special: Special = Special.NONE
@export var distance_full_mult: float = 4.0
@export var distance_full_meters: float = 120.0
@export var paper_color: Color = Color(0.93, 0.91, 0.84)
@export var icons: Array[TicketIcon] = []
@export var skills: Array[Skill] = []


func xp_to_next(level: int) -> int:
	if level < 1 or level >= level_cap:
		return 0
	return int(round(float(xp_base) * pow(xp_growth, float(level - 1))))


func level_reward_multiplier(level: int) -> float:
	return 1.0 + float(maxi(0, level - 1)) * level_reward_bonus


func distance_multiplier(distance: float) -> float:
	if special != Special.DISTANCE_REWARD:
		return 1.0
	var t := clampf(distance / maxf(1.0, distance_full_meters), 0.0, 1.0)
	return 1.0 + t * (distance_full_mult - 1.0)
