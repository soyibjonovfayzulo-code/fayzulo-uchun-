class_name V04UiTheme
extends RefCounted
## One visual language for every screen: condensed DIN-like font (Bahnschrift on Windows), smoky dark
## panels with a rust-red accent line, soft drop shadows, muted paper-white text.

const BG := Color(0.065, 0.065, 0.06, 0.88)
const BG_SOLID := Color(0.08, 0.078, 0.07, 0.97)
const BORDER := Color(0.32, 0.3, 0.26, 0.9)
const ACCENT := Color(0.78, 0.36, 0.24)
const ACCENT_DIM := Color(0.52, 0.27, 0.2)
const TEXT := Color(0.9, 0.87, 0.78)
const DIM := Color(0.62, 0.6, 0.54)
const GOOD := Color("#8aa060")
const BAD := Color("#c8483a")

static var _theme: Theme
static var _font: Font
static var _font_bold: Font


static func font(bold := false) -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "DejaVu Sans"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		_font = f
		var fb := SystemFont.new()
		fb.font_names = PackedStringArray(["Bahnschrift SemiBold", "Bahnschrift", "Segoe UI Semibold", "Arial"])
		fb.font_weight = 600
		_font_bold = fb
	return _font_bold if bold else _font


static func panel_box(bg := BG, accent := true, margin := 9) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	if accent:
		sb.border_width_top = 2
		sb.border_color = Color(BORDER, 0.95)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.set_content_margin_all(margin)
	return sb


static func accent_line(sb: StyleBoxFlat) -> StyleBoxFlat:
	sb.border_color = ACCENT_DIM
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 15)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.13, 0.125, 0.11, 0.95)
	btn.border_color = Color(0.3, 0.28, 0.24)
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(2)
	btn.set_content_margin_all(6)
	btn.content_margin_left = 12
	btn.content_margin_right = 12
	var hov := btn.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.24, 0.19, 0.14, 0.97)
	hov.border_color = ACCENT
	var prs := hov.duplicate() as StyleBoxFlat
	prs.bg_color = Color(0.32, 0.2, 0.14, 1.0)
	var dis := btn.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.1, 0.1, 0.09, 0.8)
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		pass
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("pressed", "Button", prs)
	t.set_stylebox("disabled", "Button", dis)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.44, 0.4))
	t.set_font_size("font_size", "Button", 16)
	for cls in ["OptionButton", "CheckBox", "MenuButton"]:
		t.set_stylebox("normal", cls, btn)
		t.set_stylebox("hover", cls, hov)
		t.set_stylebox("pressed", cls, prs)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 0.95, 0.85))
	var pm := panel_box(BG_SOLID, false, 4)
	t.set_stylebox("panel", "PopupMenu", pm)
	var ph := StyleBoxFlat.new()
	ph.bg_color = Color(0.36, 0.2, 0.14, 1)
	ph.set_corner_radius_all(2)
	t.set_stylebox("hover", "PopupMenu", ph)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.96, 0.86))
	t.set_color("font_separator_color", "PopupMenu", ACCENT)
	t.set_font_size("font_size", "PopupMenu", 15)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.05, 0.05, 0.045, 0.95)
	le.border_color = BORDER
	le.set_border_width_all(1)
	le.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", accent_line(le.duplicate()))
	t.set_color("font_color", "LineEdit", TEXT)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = Color(0.16, 0.14, 0.12, 1)
	tab_sel.border_color = ACCENT
	tab_sel.border_width_top = 2
	tab_sel.set_content_margin_all(7)
	var tab_un := tab_sel.duplicate() as StyleBoxFlat
	tab_un.bg_color = Color(0.09, 0.09, 0.08, 1)
	tab_un.border_color = BORDER
	tab_un.border_width_top = 1
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_sel)
	t.set_stylebox("panel", "TabContainer", panel_box(Color(0.1, 0.098, 0.09, 0.95), false))
	t.set_color("font_selected_color", "TabContainer", TEXT)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	var sl_bg := StyleBoxFlat.new()
	sl_bg.bg_color = Color(0.16, 0.15, 0.13)
	sl_bg.set_content_margin_all(3)
	var sl_fill := StyleBoxFlat.new()
	sl_fill.bg_color = ACCENT_DIM
	t.set_stylebox("slider", "HSlider", sl_bg)
	t.set_stylebox("grabber_area", "HSlider", sl_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", sl_fill)
	t.set_color("font_color", "CheckBox", TEXT)
	var tt := panel_box(BG_SOLID, false, 6)
	t.set_stylebox("panel", "TooltipPanel", tt)
	t.set_color("font_color", "TooltipLabel", TEXT)
	_theme = t
	return t


## Coloured status bar (health, hunger...) with a dark trough and a thin border.
static func bar(color: Color, w := 120.0, h := 11.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.001
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.115, 0.1)
	bg.border_color = Color(0.28, 0.26, 0.22)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(2)
	fg.border_color = color.lightened(0.25)
	fg.border_width_top = 1
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Scales a full-screen root Control by the interface scale: it is sized to viewport / scale and
## scaled back up, so every anchored child keeps its layout. Re-fits on window resize.
static func fit(c: Control) -> void:
	var vp := c.get_viewport()
	if vp == null:
		return
	var s := V04GameOptions.ui_scale
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2.ZERO
	c.scale = Vector2(s, s)
	c.size = vp.get_visible_rect().size / s
	if not c.has_meta("ui_fit"):
		c.set_meta("ui_fit", true)
		vp.size_changed.connect(func() -> void:
			if is_instance_valid(c):
				fit(c))


## Screen pixel position -> position inside a fitted Control.
static func to_ui(p: Vector2) -> Vector2:
	return p / V04GameOptions.ui_scale
