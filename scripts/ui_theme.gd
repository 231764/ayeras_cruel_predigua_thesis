class_name UITheme
extends RefCounted

# Hand-Inked Paper & Sticker Palette (matched to original desk/envelope/planner/phone illustrations)
const INK_DARK := Color(0.13, 0.11, 0.10, 1.0)       # #211c1a - Bold charcoal ink outline & primary text
const INK_MUTED := Color(0.36, 0.31, 0.27, 1.0)      # #5c4f45 - Secondary ink text
const INK_BORDER := Color(0.15, 0.13, 0.12, 1.0)     # #26211e - Crisp comic/sticker outline

const PAPER_CREAM := Color(0.96, 0.94, 0.89, 0.98)   # #f5f0e3 - Primary card & neutral button surface
const PAPER_WARM := Color(0.92, 0.89, 0.81, 0.98)    # #ebe3cf - Inner recessed paper box
const PAPER_STICKY := Color(0.99, 0.95, 0.78, 0.98)  # #fcf2c7 - Baldo sticky note / tip card
const PAPER_KRAFT := Color(0.92, 0.86, 0.58, 0.98)   # #ebdc94 - Manila envelope / highlight surface

const BTN_SAGE := Color(0.46, 0.78, 0.40, 1.0)       # #75c766 - Primary positive CTA (matches STATUS laptop)
const BTN_GOLD := Color(0.95, 0.79, 0.36, 1.0)       # #f2c95c - Warm gold action / active tab
const BTN_BLUE := Color(0.53, 0.75, 0.86, 1.0)       # #87bfdc - Sky blue accent (matches PHONE)
const BTN_CORAL := Color(0.90, 0.48, 0.42, 1.0)      # #e67a6b - Destructive / debt / withdraw action
const BTN_CREAM := Color(0.96, 0.93, 0.86, 1.0)      # #f5ede0 - Neutral tactile button

const TEXT_SUCCESS := Color(0.11, 0.44, 0.20, 1.0)   # #1c7033 - Forest green for positive values on cream
const TEXT_WARN := Color(0.58, 0.32, 0.05, 1.0)      # #94520d - Deep amber for warnings on cream
const TEXT_DANGER := Color(0.66, 0.15, 0.12, 1.0)    # #a8261f - Deep crimson for negative/shortfall on cream

# Strict Typographic Scale (5 deliberate roles across the entire game)
const TYPE_CAPTION := 12   # Pills, bar overlays, secondary notes, calendar day headers
const TYPE_BODY := 14      # Body prose, standard buttons, inputs, dropdowns, tooltips
const TYPE_SUBHEAD := 16   # Card titles, primary CTAs, top HUD date, subpanel headers
const TYPE_HEADING := 20   # Modal & feature panel title banners (Fredoka SemiBold)
const TYPE_HERO_NUM := 30  # Envelope primary balance display (Fredoka Bold)
const TYPE_DISPLAY := 44   # Main title PALDO emblem lockup (Fredoka Bold)

const FONT_BODY: Font = preload("res://assets/fonts/font_body.tres")
const FONT_UI: Font = preload("res://assets/fonts/font_ui.tres")
const FONT_BOLD: Font = preload("res://assets/fonts/font_bold.tres")
const FONT_HEADING: Font = preload("res://assets/fonts/font_heading.tres")
const FONT_DISPLAY: Font = preload("res://assets/fonts/font_display.tres")

# Uniform Hand-Inked Vector UI Icons (16-18px, stroke-width 2.6, #211c1a)
const ICON_ARROW_LEFT: Texture2D = preload("res://assets/icons/arrow_left.svg")
const ICON_ARROW_RIGHT: Texture2D = preload("res://assets/icons/arrow_right.svg")
const ICON_FAST_FORWARD: Texture2D = preload("res://assets/icons/fast_forward.svg")
const ICON_PAUSE: Texture2D = preload("res://assets/icons/pause.svg")
const ICON_CHEVRON_DOWN: Texture2D = preload("res://assets/icons/chevron_down.svg")
const ICON_CHEVRON_UP: Texture2D = preload("res://assets/icons/chevron_up.svg")
const ICON_MENU: Texture2D = preload("res://assets/icons/menu.svg")
const ICON_DOWNLOAD: Texture2D = preload("res://assets/icons/download.svg")

static func _play_ui_sfx(node: Node, sfx_name: String) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var tree := node.get_tree()
	if not tree or not tree.root:
		return
	var am := tree.root.get_node_or_null("AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx_name)

static func apply_type(ctrl: Control, size: int, font_res: Font = null) -> void:
	if not ctrl:
		return
	if ctrl is RichTextLabel:
		ctrl.add_theme_font_size_override("normal_font_size", size)
		ctrl.add_theme_font_size_override("bold_font_size", size)
		if font_res:
			ctrl.add_theme_font_override("normal_font", font_res)
	else:
		ctrl.add_theme_font_size_override("font_size", size)
		if font_res:
			ctrl.add_theme_font_override("font", font_res)

static func set_button_icon(btn: Button, icon_tex: Texture2D, align_right: bool = false, icon_only: bool = false) -> void:
	if not btn:
		return
	btn.icon = icon_tex
	btn.expand_icon = false
	btn.add_theme_constant_override("h_separation", 8)
	if icon_only:
		btn.text = ""
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif align_right:
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

static func make_card_style(
	bg: Color = PAPER_CREAM,
	border: Color = INK_BORDER,
	radius: int = 10,
	border_w: int = 3,
	bottom_lip: int = 5,
	pad_h: float = 14.0,
	pad_v: float = 10.0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = bottom_lip
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.shadow_color = Color(0.06, 0.05, 0.04, 0.22)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(2, 3)
	return sb

static func make_tactile_btn_style(
	bg: Color,
	border: Color = INK_BORDER,
	radius: int = 8,
	bottom_lip: int = 4,
	pad_h: float = 12.0,
	pad_v: float = 6.0,
	pressed_offset: float = 0.0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = bottom_lip
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v + pressed_offset
	sb.content_margin_bottom = max(2.0, pad_v - pressed_offset)
	sb.shadow_color = Color(0.06, 0.05, 0.04, 0.18 if bottom_lip > 2 else 0.08)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(1, 2 if bottom_lip > 2 else 1)
	return sb

static func style_Button(
	btn: Button,
	surface: Color = BTN_CREAM,
	radius: int = 8,
	bottom_lip: int = 4,
	pad_h: float = 12.0,
	pad_v: float = 6.0
) -> void:
	if not btn:
		return
	var normal_sb := make_tactile_btn_style(surface, INK_BORDER, radius, bottom_lip, pad_h, pad_v, 0.0)
	var hover_bg: Color = surface.lerp(BTN_GOLD, 0.24) if surface.get_luminance() > 0.80 else surface.lightened(0.11)
	var hover_sb := make_tactile_btn_style(hover_bg, INK_DARK, radius, bottom_lip, pad_h, pad_v, 0.0)
	var pressed_sb := make_tactile_btn_style(surface.darkened(0.06), INK_DARK, radius, 2, pad_h, pad_v, 2.0)
	var disabled_sb := make_tactile_btn_style(Color(0.84, 0.81, 0.75, 0.88), Color(0.48, 0.44, 0.40, 0.75), radius, 2, pad_h, pad_v, 0.0)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)

	btn.add_theme_font_override("font", FONT_UI)
	btn.add_theme_color_override("font_color", INK_DARK)
	btn.add_theme_color_override("font_hover_color", Color(0.06, 0.05, 0.04, 1.0))
	btn.add_theme_color_override("font_pressed_color", INK_DARK)
	btn.add_theme_color_override("font_focus_color", INK_DARK)
	btn.add_theme_color_override("font_disabled_color", Color(0.46, 0.42, 0.38, 0.9))
	btn.add_theme_constant_override("outline_size", 0)

	if not btn.has_meta("_tactile_wired"):
		btn.set_meta("_tactile_wired", true)
		btn.button_down.connect(func():
			if not is_instance_valid(btn) or btn.disabled:
				return
			btn.pivot_offset = btn.size * 0.5
			var tw := btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.08)
		)
		btn.button_up.connect(func():
			if not is_instance_valid(btn):
				return
			btn.pivot_offset = btn.size * 0.5
			var tw := btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2.ONE, 0.12)
		)

static func style_option_button(opt: OptionButton) -> void:
	if not opt:
		return
	style_Button(opt, PAPER_KRAFT, 7, 4, 10.0, 4.0)
	opt.add_theme_font_size_override("font_size", TYPE_BODY)
	var popup := opt.get_popup()
	if popup:
		var pop_panel := make_card_style(PAPER_CREAM, INK_BORDER, 8, 2, 4, 8.0, 6.0)
		var pop_hover := make_tactile_btn_style(BTN_GOLD, INK_BORDER, 5, 2, 6.0, 4.0)
		popup.add_theme_stylebox_override("panel", pop_panel)
		popup.add_theme_stylebox_override("hover", pop_hover)
		popup.add_theme_color_override("font_color", INK_DARK)
		popup.add_theme_color_override("font_hover_color", INK_DARK)
		popup.add_theme_font_override("font", FONT_UI)
		popup.add_theme_font_size_override("font_size", TYPE_BODY)

static func style_progress_bar(bar: ProgressBar, fill_color: Color, radius: int = 8) -> void:
	if not bar:
		return
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.90, 0.87, 0.79, 0.98)
	bg_sb.border_width_left = 2
	bg_sb.border_width_top = 2
	bg_sb.border_width_right = 2
	bg_sb.border_width_bottom = 4
	bg_sb.border_color = INK_BORDER
	bg_sb.corner_radius_top_left = radius
	bg_sb.corner_radius_top_right = radius
	bg_sb.corner_radius_bottom_right = radius
	bg_sb.corner_radius_bottom_left = radius

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.border_width_left = 2
	fill_sb.border_width_top = 2
	fill_sb.border_width_right = 2
	fill_sb.border_width_bottom = 3
	fill_sb.border_color = INK_BORDER
	fill_sb.corner_radius_top_left = radius
	fill_sb.corner_radius_top_right = radius
	fill_sb.corner_radius_bottom_right = radius
	fill_sb.corner_radius_bottom_left = radius

	bar.add_theme_stylebox_override("background", bg_sb)
	bar.add_theme_stylebox_override("fill", fill_sb)
	bar.add_theme_font_override("font", FONT_UI)
	bar.add_theme_font_size_override("font_size", TYPE_CAPTION)
	bar.add_theme_color_override("font_color", INK_DARK)
	bar.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.94, 0.9))
	bar.add_theme_constant_override("outline_size", 3)

static func format_num(val: int) -> String:
	var neg: bool = (val < 0)
	var s: String = str(abs(val))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return ("-" + out) if neg else out

static func style_header_banner(lbl: Label, banner_color: Color = BTN_GOLD, radius: int = 8, pad_v: float = 6.0, font_size: int = TYPE_HEADING) -> void:
	if not lbl:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = banner_color
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 4
	sb.border_color = INK_BORDER
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	lbl.add_theme_stylebox_override("normal", sb)
	lbl.add_theme_font_override("font", FONT_HEADING)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", INK_DARK)
	lbl.add_theme_constant_override("outline_size", 0)

static func style_stat_badge(lbl: Label, accent_color: Color) -> void:
	if not lbl:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_CREAM
	sb.border_width_left = 8
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 5
	sb.border_color = INK_BORDER
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	sb.content_margin_left = 34.0
	sb.content_margin_top = 5.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 5.0
	sb.shadow_color = Color(0.06, 0.05, 0.04, 0.22)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(2, 3)
	lbl.add_theme_stylebox_override("normal", sb)
	lbl.add_theme_font_override("font", FONT_UI)
	lbl.add_theme_font_size_override("font_size", TYPE_BODY)

	# Add a colored inner accent bar on the left side inside the badge
	var accent_strip := lbl.get_node_or_null("AccentStrip")
	if not accent_strip:
		var rect := ColorRect.new()
		rect.name = "AccentStrip"
		rect.color = accent_color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		rect.offset_left = 22.0
		rect.offset_top = 6.0
		rect.offset_right = 27.0
		rect.offset_bottom = -8.0
		lbl.add_child(rect)
	else:
		(accent_strip as ColorRect).color = accent_color

static func _estimate_body_lines(body_text: String, chars_per_line: int = 54) -> int:
	var paragraphs: PackedStringArray = body_text.split("\n")
	var total_lines: int = 0
	for p in paragraphs:
		var trimmed: String = p.strip_edges()
		if trimmed == "":
			total_lines += 1
		else:
			total_lines += int(ceil(float(trimmed.length()) / float(max(1, chars_per_line))))
	return max(1, total_lines)

static func _estimate_notice_card_height(body_text: String, min_h: float = 220.0, max_h: float = 420.0) -> float:
	var lines: int = _estimate_body_lines(body_text, 54)
	return clamp(162.0 + float(lines) * 24.0, min_h, max_h)

static func spawn_game_notice(
	parent: Node,
	title_text: String,
	body_text: String,
	banner_color: Color = BTN_GOLD,
	btn_text: String = "Okay, Tuloy",
	on_close: Callable = Callable(),
	open_sfx: String = ""
) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "GameNoticeCanvas"
	layer.layer = 115

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 0.72)
	layer.add_child(backdrop)

	var card_h: float = _estimate_notice_card_height(body_text, 220.0, 420.0)
	var half_h: float = card_h * 0.5
	var lines_est: int = _estimate_body_lines(body_text, 54)

	var card := Panel.new()
	card.name = "NoticeCard"
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -300.0
	card.offset_top = -half_h
	card.offset_right = 300.0
	card.offset_bottom = half_h
	card.add_theme_stylebox_override("panel", make_card_style(PAPER_CREAM, INK_BORDER, 14, 3, 7, 18.0, 14.0))
	backdrop.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_top = 16.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -16.0
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_header_banner(title_lbl, banner_color, 8, 7.0, TYPE_HEADING)
	vbox.add_child(title_lbl)

	var body_wrap := PanelContainer.new()
	body_wrap.name = "BodyPanel"
	body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_wrap.add_theme_stylebox_override("panel", make_card_style(PAPER_WARM, INK_BORDER, 8, 2, 3, 16.0, 12.0))
	vbox.add_child(body_wrap)

	var body_scroll := ScrollContainer.new()
	body_scroll.name = "BodyScroll"
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_wrap.add_child(body_scroll)

	var body_lbl := Label.new()
	body_lbl.name = "BodyLabel"
	body_lbl.text = body_text
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if lines_est <= 3:
		body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		body_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_type(body_lbl, TYPE_BODY, FONT_BODY)
	body_lbl.add_theme_color_override("font_color", INK_DARK)
	body_scroll.add_child(body_lbl)

	var ok_btn := Button.new()
	ok_btn.name = "ConfirmButton"
	ok_btn.text = btn_text
	ok_btn.custom_minimum_size = Vector2(210, 42)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	apply_type(ok_btn, TYPE_BODY, FONT_UI)
	style_Button(ok_btn, BTN_SAGE, 8, 5, 18.0, 7.0)
	vbox.add_child(ok_btn)

	parent.add_child(layer)
	if open_sfx != "":
		_play_ui_sfx(parent, open_sfx)

	card.pivot_offset = Vector2(300.0, half_h)
	card.scale = Vector2(0.95, 0.95)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.15)
	tw.tween_property(card, "modulate:a", 1.0, 0.14)

	var closed := [false]
	var close_fn := func():
		if closed[0]:
			return
		closed[0] = true
		_play_ui_sfx(parent, "click")
		layer.visible = false
		layer.queue_free()
		if on_close.is_valid():
			on_close.call()

	ok_btn.pressed.connect(close_fn)
	ok_btn.grab_focus()
	return layer

static func spawn_payslip_modal(
	parent: Node,
	payslip: Dictionary,
	on_close: Callable = Callable(),
	on_smart_split: Callable = Callable()
) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "PayslipModalCanvas"
	layer.layer = 115

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 0.72)
	layer.add_child(backdrop)

	var rows: Array = payslip.get("rows", [])
	var note_text: String = str(payslip.get("note", ""))
	var net_received: int = int(payslip.get("net_received", 0))
	var card_h: float = clamp(290.0 + float(rows.size()) * 28.0 + (32.0 if note_text != "" else 0.0), 310.0, 460.0)
	var half_h: float = card_h * 0.5

	var card := Panel.new()
	card.name = "PayslipCard"
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280.0
	card.offset_top = -half_h
	card.offset_right = 280.0
	card.offset_bottom = half_h
	card.add_theme_stylebox_override("panel", make_card_style(PAPER_CREAM, INK_BORDER, 14, 3, 7, 18.0, 14.0))
	backdrop.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_top = 16.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -16.0
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var banner_col: Color = payslip.get("banner_color", BTN_SAGE if net_received > 0 else BTN_CORAL)
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = str(payslip.get("title", "Sahod Day!"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_header_banner(title_lbl, banner_col, 8, 6.0, TYPE_HEADING)
	vbox.add_child(title_lbl)

	# Hero strip with icon, role pill, and big Net Take-Home number
	var hero_wrap := PanelContainer.new()
	hero_wrap.name = "HeroPanel"
	hero_wrap.add_theme_stylebox_override("panel", make_card_style(PAPER_STICKY if net_received > 0 else PAPER_WARM, INK_BORDER, 10, 2, 3, 12.0, 8.0))
	vbox.add_child(hero_wrap)

	var hero_hb := HBoxContainer.new()
	hero_hb.add_theme_constant_override("separation", 10)
	hero_wrap.add_child(hero_hb)

	var ic := TextureRect.new()
	ic.texture = preload("res://assets/cashonhand.png")
	ic.custom_minimum_size = Vector2(40, 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_hb.add_child(ic)

	var hero_left := VBoxContainer.new()
	hero_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_left.add_theme_constant_override("separation", 1)
	hero_hb.add_child(hero_left)

	var role_lbl := Label.new()
	role_lbl.name = "RoleLabel"
	role_lbl.text = str(payslip.get("subtitle", ""))
	apply_type(role_lbl, TYPE_CAPTION, FONT_UI)
	role_lbl.add_theme_color_override("font_color", INK_MUTED)
	hero_left.add_child(role_lbl)

	var net_caption := Label.new()
	net_caption.text = str(payslip.get("hero_label", "Net Take-Home Pay"))
	apply_type(net_caption, TYPE_BODY, FONT_HEADING)
	net_caption.add_theme_color_override("font_color", INK_DARK)
	hero_left.add_child(net_caption)

	var hero_amt := Label.new()
	hero_amt.name = "HeroAmountLabel"
	hero_amt.text = ("+₱" + format_num(net_received)) if net_received > 0 else "₱0"
	hero_amt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply_type(hero_amt, 22, FONT_HEADING)
	hero_amt.add_theme_color_override("font_color", TEXT_SUCCESS if net_received > 0 else TEXT_DANGER)
	hero_hb.add_child(hero_amt)

	# Structured receipt rows inside safe ScrollContainer
	var body_wrap := PanelContainer.new()
	body_wrap.name = "BreakdownPanel"
	body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_wrap.add_theme_stylebox_override("panel", make_card_style(PAPER_WARM, INK_BORDER, 8, 2, 3, 12.0, 8.0))
	vbox.add_child(body_wrap)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_wrap.add_child(scroll)

	var rows_vb := VBoxContainer.new()
	rows_vb.name = "RowsContainer"
	rows_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vb.add_theme_constant_override("separation", 5)
	scroll.add_child(rows_vb)

	for r in rows:
		if r is Dictionary:
			if bool(r.get("divider", false)):
				var div := HSeparator.new()
				rows_vb.add_child(div)
			var row_hb := HBoxContainer.new()
			row_hb.add_theme_constant_override("separation", 8)
			rows_vb.add_child(row_hb)

			var l_lbl := Label.new()
			l_lbl.text = str(r.get("label", ""))
			l_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			apply_type(l_lbl, TYPE_BODY, FONT_BOLD if bool(r.get("bold", false)) else FONT_BODY)
			l_lbl.add_theme_color_override("font_color", INK_DARK if bool(r.get("bold", false)) else INK_MUTED)
			row_hb.add_child(l_lbl)

			var v_lbl := Label.new()
			v_lbl.text = str(r.get("value", ""))
			v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			apply_type(v_lbl, TYPE_BODY, FONT_UI)
			v_lbl.add_theme_color_override("font_color", r.get("color", INK_DARK))
			row_hb.add_child(v_lbl)

	if note_text != "":
		var n_lbl := Label.new()
		n_lbl.name = "NoteLabel"
		n_lbl.text = note_text
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		apply_type(n_lbl, TYPE_CAPTION, FONT_UI)
		n_lbl.add_theme_color_override("font_color", INK_MUTED)
		vbox.add_child(n_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.name = "ButtonsRow"
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var closed := [false]
	if on_smart_split.is_valid() and net_received > 0:
		var split_btn := Button.new()
		split_btn.name = "SmartSplitButton"
		split_btn.text = "Smart Split Agad"
		split_btn.custom_minimum_size = Vector2(200, 42)
		apply_type(split_btn, TYPE_BODY, FONT_UI)
		style_Button(split_btn, BTN_GOLD, 8, 5, 14.0, 6.0)
		btn_row.add_child(split_btn)
		split_btn.pressed.connect(func():
			if closed[0]:
				return
			closed[0] = true
			layer.visible = false
			layer.queue_free()
			on_smart_split.call()
		)

	var ok_btn := Button.new()
	ok_btn.name = "ConfirmButton"
	ok_btn.text = str(payslip.get("ok_text", "OK, Tuloy!"))
	ok_btn.custom_minimum_size = Vector2(180, 42)
	apply_type(ok_btn, TYPE_BODY, FONT_UI)
	style_Button(ok_btn, BTN_SAGE, 8, 5, 16.0, 6.0)
	btn_row.add_child(ok_btn)
	ok_btn.pressed.connect(func():
		if closed[0]:
			return
		closed[0] = true
		_play_ui_sfx(parent, "click")
		layer.visible = false
		layer.queue_free()
		if on_close.is_valid():
			on_close.call()
	)

	parent.add_child(layer)

	card.pivot_offset = Vector2(280.0, half_h)
	card.scale = Vector2(0.95, 0.95)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.15)
	tw.tween_property(card, "modulate:a", 1.0, 0.14)

	ok_btn.grab_focus()
	return layer

static func spawn_game_confirm(
	parent: Node,
	title_text: String,
	body_text: String,
	ok_text: String,
	cancel_text: String,
	banner_color: Color,
	on_confirm: Callable,
	on_cancel: Callable
) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "GameConfirmCanvas"
	layer.layer = 120

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 0.78)
	layer.add_child(backdrop)

	var card_h: float = _estimate_notice_card_height(body_text, 230.0, 380.0)
	var half_h: float = card_h * 0.5
	var lines_est: int = _estimate_body_lines(body_text, 54)

	var card := Panel.new()
	card.name = "ConfirmCard"
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -300.0
	card.offset_top = -half_h
	card.offset_right = 300.0
	card.offset_bottom = half_h
	card.add_theme_stylebox_override("panel", make_card_style(PAPER_CREAM, INK_BORDER, 14, 3, 7, 18.0, 14.0))
	backdrop.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_top = 16.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -16.0
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_header_banner(title_lbl, banner_color, 8, 7.0, TYPE_HEADING)
	vbox.add_child(title_lbl)

	var body_wrap := PanelContainer.new()
	body_wrap.name = "BodyPanel"
	body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_wrap.add_theme_stylebox_override("panel", make_card_style(PAPER_WARM, INK_BORDER, 8, 2, 3, 16.0, 12.0))
	vbox.add_child(body_wrap)

	var body_scroll := ScrollContainer.new()
	body_scroll.name = "BodyScroll"
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_wrap.add_child(body_scroll)

	var body_lbl := Label.new()
	body_lbl.name = "BodyLabel"
	body_lbl.text = body_text
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if lines_est <= 3:
		body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		body_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_type(body_lbl, TYPE_BODY, FONT_BODY)
	body_lbl.add_theme_color_override("font_color", INK_DARK)
	body_scroll.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.name = "OkButton"
	ok_btn.text = ok_text
	ok_btn.custom_minimum_size = Vector2(210, 42)
	ok_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_type(ok_btn, TYPE_BODY, FONT_UI)
	style_Button(ok_btn, BTN_SAGE, 8, 5, 14.0, 6.0)
	btn_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = cancel_text
	cancel_btn.custom_minimum_size = Vector2(180, 42)
	cancel_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_type(cancel_btn, TYPE_BODY, FONT_UI)
	style_Button(cancel_btn, BTN_CORAL, 8, 5, 14.0, 6.0)
	btn_row.add_child(cancel_btn)

	parent.add_child(layer)

	var closed := [false]
	ok_btn.pressed.connect(func():
		if closed[0]:
			return
		closed[0] = true
		_play_ui_sfx(parent, "click")
		layer.visible = false
		layer.queue_free()
		if on_confirm.is_valid():
			on_confirm.call()
	)
	cancel_btn.pressed.connect(func():
		if closed[0]:
			return
		closed[0] = true
		_play_ui_sfx(parent, "click")
		layer.visible = false
		layer.queue_free()
		if on_cancel.is_valid():
			on_cancel.call()
	)
	return layer
