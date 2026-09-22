class_name Skill
extends Resource

enum Kind { ICON_WEIGHT, PRIZE_MULTIPLIER }
enum Cost { NORMAL, EPIC }

@export var id: StringName = &""
@export var title: String = ""
@export var description: String = ""
@export var icon_color: Color = Color(0.5, 0.5, 0.55)
@export var glyph: String = ""
@export var kind: Kind = Kind.ICON_WEIGHT
@export var target_icon: StringName = &""
@export var amount: float = 0.0
@export var target_icon_2: StringName = &""
@export var amount_2: float = 0.0
@export var max_ranks: int = 1
@export var cost: Cost = Cost.NORMAL
@export var requires: StringName = &""
