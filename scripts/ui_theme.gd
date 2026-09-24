class_name UiTheme
extends RefCounted

## Grimy carnival horror UI theme, built in code (no editor needed).
## Applied to the root Window so every Control inherits it.

const BG := Color(0.043, 0.039, 0.055)
const PANEL_BG := Color(0.086, 0.075, 0.110, 0.94)
const PANEL_BG_DARK := Color(0.055, 0.048, 0.072, 0.96)
const INSET_BG := Color(0.024, 0.021, 0.033, 0.90)
const BORDER := Color(0.230, 0.180, 0.280)
const BORDER_LIT := Color(0.560, 0.380, 0.160)
const AMBER := Color(0.850, 0.550, 0.170)
const AMBER_DIM := Color(0.520, 0.330, 0.110)
const RUST := Color(0.620, 0.300, 0.120)
const BLOOD := Color(0.780, 0.120, 0.110)
const BONE := Color(0.910, 0.880, 0.820)
const MUTED := Color(0.580, 0.545, 0.500)
const GOLD := Color(0.900, 0.760, 0.350)
const GREEN := Color(0.450, 0.720, 0.300)

const BODY_FONT_PATH := "res://fonts/Inter-Variable.ttf"
const DISPLAY_FONT_PATH := "res://fonts/Rye-Regular.ttf"

static var _shared: Theme


static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func build() -> Theme:
	var theme := Theme.new()
	var body: Font = load(BODY_FONT_PATH)
	var display: Font = load(DISPLAY_FONT_PATH)
	if body != null:
		theme.default_font = body
	theme.default_font_size = 16

	_build_label(theme, body, display)
	_build_button(theme, body)
	_build_panels(theme)
	_build_progress(theme)
	_build_misc(theme)
	return theme


static func _build_label(theme: Theme, body: Font, display: Font) -> void:
	theme.set_font("font", "Label", body)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_color("font_color", "Label", BONE)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)

	_variation(theme, "TitleLabel", "Label", display, 30, AMBER)
	_variation(theme, "HeadingLabel", "Label", body, 20, BONE)
	_variation(theme, "MutedLabel", "Label", body, 14, MUTED)
	_variation(theme, "ChipLabel", "Label", body, 16, BONE)
	_variation(theme, "GoldLabel", "Label", body, 18, GOLD)
	_variation(theme, "AlertLabel", "Label", display, 36, BLOOD)


static func _variation(theme: Theme, name: StringName, base: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, base)
	if font != null:
		theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


static func _build_button(theme: Theme, body: Font) -> void:
	theme.set_font("font", "Button", body)
	theme.set_font_size("font_size", "Button", 16)
	theme.set_color("font_color", "Button", BONE)
	theme.set_color("font_hover_color", "Button", AMBER)
	theme.set_color("font_pressed_color", "Button", AMBER_DIM)
	theme.set_color("font_focus_color", "Button", BONE)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "Button", _sb(INSET_BG, BORDER, 1, 3, 10, 6))
	theme.set_stylebox("hover", "Button", _sb(PANEL_BG.lightened(0.08), BORDER_LIT, 1, 3, 10, 6))
	theme.set_stylebox("pressed", "Button", _sb(PANEL_BG_DARK, AMBER_DIM, 1, 3, 10, 6))
	theme.set_stylebox("disabled", "Button", _sb(Color(0.05, 0.045, 0.06, 0.6), Color(0.16, 0.14, 0.18), 1, 3, 10, 6))
	theme.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), AMBER, 1, 3, 10, 6))

	theme.set_type_variation("DangerButton", "Button")
	theme.set_color("font_color", "DangerButton", Color(0.95, 0.62, 0.58))
	theme.set_color("font_hover_color", "DangerButton", Color(1.0, 0.78, 0.74))
	theme.set_color("font_pressed_color", "DangerButton", Color(0.7, 0.3, 0.28))
	theme.set_stylebox("normal", "DangerButton", _sb(Color(0.14, 0.05, 0.05, 0.8), Color(0.45, 0.14, 0.12), 1, 3, 10, 6))
	theme.set_stylebox("hover", "DangerButton", _sb(Color(0.22, 0.06, 0.06, 0.9), BLOOD, 1, 3, 10, 6))
	theme.set_stylebox("pressed", "DangerButton", _sb(Color(0.1, 0.03, 0.03, 0.9), Color(0.55, 0.12, 0.1), 1, 3, 10, 6))
	theme.set_stylebox("focus", "DangerButton", _sb(Color(0, 0, 0, 0), BLOOD, 1, 3, 10, 6))


static func _build_panels(theme: Theme) -> void:
	var panel := _sb(PANEL_BG, BORDER, 2, 4, 16, 14)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 8
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "ScrollContainer", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0))

	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _sb(PANEL_BG_DARK, BORDER, 1, 3, 12, 10))


static func _build_progress(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", _sb(INSET_BG, BORDER, 1, 3, 2, 2))
	theme.set_stylebox("fill", "ProgressBar", _sb(Color(1, 1, 1, 0.92), Color(0, 0, 0, 0), 0, 2, 0, 0))
	theme.set_color("font_color", "ProgressBar", BONE)
	theme.set_font_size("font_size", "ProgressBar", 13)


static func _build_misc(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", _sb(PANEL_BG_DARK, BORDER_LIT, 1, 3, 8, 6))
	theme.set_color("font_color", "TooltipLabel", BONE)
	theme.set_font_size("font_size", "TooltipLabel", 14)


static func _sb(bg: Color, border: Color, border_w: int, radius: int, margin_h: int, margin_v: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = float(margin_h)
	sb.content_margin_right = float(margin_h)
	sb.content_margin_top = float(margin_v)
	sb.content_margin_bottom = float(margin_v)
	sb.anti_aliasing = true
	return sb
