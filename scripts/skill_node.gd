class_name SkillNode
extends Control

signal pressed(skill: Skill)
signal hovered(skill: Skill)
signal unhovered(skill: Skill)

const NODE_SIZE := 64.0

var skill: Skill
var rank: int = 0
var maxed: bool = false
var can_buy: bool = false
var locked: bool = false


func setup(s: Skill, r: int, purchasable: bool, is_locked: bool) -> void:
	skill = s
	rank = r
	maxed = r >= s.max_ranks
	can_buy = purchasable
	locked = is_locked
	custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	size = Vector2(NODE_SIZE, NODE_SIZE)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hovered.emit(skill))
	mouse_exited.connect(func(): unhovered.emit(skill))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(skill)


func _draw() -> void:
	var font := get_theme_default_font()
	if font == null or skill == null:
		return

	var bg := skill.icon_color
	if locked:
		bg = bg.darkened(0.6)
	elif not can_buy and not maxed:
		bg = bg.darkened(0.25)
	draw_rect(Rect2(Vector2.ZERO, size), bg)

	var border := Color(0.12, 0.12, 0.14)
	if maxed:
		border = Color(1.0, 0.82, 0.25)
	elif locked:
		border = Color(0.22, 0.22, 0.25)
	elif can_buy:
		border = Color(0.35, 0.9, 0.35)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 3.0)

	var glyph := skill.glyph if skill.glyph != "" else skill.title.substr(0, 1)
	var fs := 30
	var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2((size.x - glyph_size.x) * 0.5, (size.y + glyph_size.y) * 0.5 - 6.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.06, 0.06, 0.07))

	var rank_text := "%d/%d" % [rank, skill.max_ranks]
	var rank_size := font.get_string_size(rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(size.x - rank_size.x - 4.0, size.y - 5.0), rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))
