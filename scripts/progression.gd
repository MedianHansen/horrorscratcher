class_name Progression
extends RefCounted

static var _profiles: Dictionary = {}
static var _seeded := false


static func ensure_seeded() -> void:
	if _seeded:
		return
	_seeded = true
	var bytes := Crypto.new().generate_random_bytes(8)
	seed(bytes.decode_u64(0))


static func profile(type_name: String) -> Dictionary:
	if not _profiles.has(type_name):
		_profiles[type_name] = {"xp": 0, "level": 1, "normal": 0, "epic": 0, "ranks": {}}
	return _profiles[type_name]


static func add_xp(type: TicketType, amount: int) -> Dictionary:
	var p: Dictionary = profile(type.type_name)
	p["xp"] = int(p["xp"]) + amount
	var levels_gained := 0
	while int(p["level"]) < type.level_cap:
		var need := type.xp_to_next(int(p["level"]))
		if need <= 0 or int(p["xp"]) < need:
			break
		p["xp"] = int(p["xp"]) - need
		p["level"] = int(p["level"]) + 1
		if int(p["level"]) % 5 == 0:
			p["epic"] = int(p["epic"]) + 1
		else:
			p["normal"] = int(p["normal"]) + 1
		levels_gained += 1
	return {
		"level": int(p["level"]),
		"levels_gained": levels_gained,
		"normal": int(p["normal"]),
		"epic": int(p["epic"]),
	}


static func rank(type_name: String, skill_id: StringName) -> int:
	var ranks: Dictionary = profile(type_name)["ranks"]
	return int(ranks.get(skill_id, 0))


static func can_buy(type: TicketType, skill: Skill) -> bool:
	if skill == null or type == null:
		return false
	if rank(type.type_name, skill.id) >= skill.max_ranks:
		return false
	if skill.requires != &"" and rank(type.type_name, skill.requires) <= 0:
		return false
	var p: Dictionary = profile(type.type_name)
	if skill.cost == Skill.Cost.EPIC:
		return int(p["epic"]) >= 1
	return int(p["normal"]) >= 1


static func buy(type: TicketType, skill: Skill) -> bool:
	if not can_buy(type, skill):
		return false
	var p: Dictionary = profile(type.type_name)
	if skill.cost == Skill.Cost.EPIC:
		p["epic"] = int(p["epic"]) - 1
	else:
		p["normal"] = int(p["normal"]) - 1
	var ranks: Dictionary = p["ranks"]
	ranks[skill.id] = rank(type.type_name, skill.id) + 1
	return true


static func icon_weight(type: TicketType, icon_id: StringName) -> float:
	var value := 0.0
	if type == null:
		return value
	for icon in type.icons:
		if icon.id == icon_id:
			value = icon.weight
			break
	for skill in type.skills:
		if skill.kind == Skill.Kind.ICON_WEIGHT and skill.target_icon == icon_id:
			value += skill.amount * float(rank(type.type_name, skill.id))
	return maxf(0.0, value)


static func prize_multiplier(type: TicketType) -> float:
	var mult := 1.0
	if type == null:
		return mult
	for skill in type.skills:
		if skill.kind == Skill.Kind.PRIZE_MULTIPLIER:
			mult += skill.amount * float(rank(type.type_name, skill.id))
	return mult
