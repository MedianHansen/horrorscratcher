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
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)


func _on_hover_in() -> void:
	hovered.emit(skill)
	_scale_to(1.08)


func _on_hover_out() -> void:
	unhovered.emit(skill)
	_scale_to(1.0)


func _scale_to(value: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(value, value), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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

	var border := Color(0.12, 0.12, 0.14)
	if maxed:
		border = UiTheme.STATE_MAXED
	elif locked:
		border = UiTheme.STATE_LOCKED
	elif can_buy:
		border = UiTheme.STATE_LEARNABLE

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	if can_buy:
		sb.shadow_color = Color(UiTheme.STATE_LEARNABLE.r, UiTheme.STATE_LEARNABLE.g, UiTheme.STATE_LEARNABLE.b, 0.45)
		sb.shadow_size = 8
	draw_style_box(sb, Rect2(Vector2.ZERO, size))

	var glyph := skill.glyph if skill.glyph != "" else skill.title.substr(0, 1)
	var fs := 30
	var lum := 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
	var glyph_color := Color(0.06, 0.06, 0.07) if lum > 0.5 else Color(0.95, 0.95, 0.95)
	var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2((size.x - glyph_size.x) * 0.5, (size.y + glyph_size.y) * 0.5 - 6.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glyph_color)

	var rank_text := "%d/%d" % [rank, skill.max_ranks]
	var rank_size := font.get_string_size(rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(size.x - rank_size.x - 4.0, size.y - 5.0), rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))
