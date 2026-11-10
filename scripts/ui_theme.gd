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
	var hover_sb := make_tactile_btn_style(surface.lightened(0.07), INK_DARK, radius, bottom_lip, pad_h, pad_v, 0.0)
	var pressed_sb := make_tactile_btn_style(surface.darkened(0.06), INK_DARK, radius, 2, pad_h, pad_v, 2.0)
	var disabled_sb := make_tactile_btn_style(Color(0.84, 0.81, 0.75, 0.88), Color(0.48, 0.44, 0.40, 0.75), radius, 2, pad_h, pad_v, 0.0)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)

	btn.add_theme_color_override("font_color", INK_DARK)
	btn.add_theme_color_override("font_hover_color", Color(0.06, 0.05, 0.04, 1.0))
	btn.add_theme_color_override("font_pressed_color", INK_DARK)
	btn.add_theme_color_override("font_focus_color", INK_DARK)
	btn.add_theme_color_override("font_disabled_color", Color(0.46, 0.42, 0.38, 0.9))
	btn.add_theme_constant_override("outline_size", 0)

static func style_option_button(opt: OptionButton) -> void:
	if not opt:
		return
	style_Button(opt, PAPER_KRAFT, 7, 4, 10.0, 4.0)
	var popup := opt.get_popup()
	if popup:
		var pop_panel := make_card_style(PAPER_CREAM, INK_BORDER, 8, 2, 4, 8.0, 6.0)
		var pop_hover := make_tactile_btn_style(BTN_GOLD, INK_BORDER, 5, 2, 6.0, 4.0)
		popup.add_theme_stylebox_override("panel", pop_panel)
		popup.add_theme_stylebox_override("hover", pop_hover)
		popup.add_theme_color_override("font_color", INK_DARK)
		popup.add_theme_color_override("font_hover_color", INK_DARK)
		popup.add_theme_font_size_override("font_size", 14)

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

static func style_header_banner(lbl: Label, banner_color: Color = BTN_GOLD, radius: int = 8, pad_v: float = 6.0) -> void:
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

static func spawn_game_notice(
	parent: Node,
	title_text: String,
	body_text: String,
	banner_color: Color = BTN_GOLD,
	btn_text: String = "OK, Tuloy!",
	on_close: Callable = Callable()
) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "GameNoticeCanvas"
	layer.layer = 115

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 0.72)
	layer.add_child(backdrop)

	var card := Panel.new()
	card.name = "NoticeCard"
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -265.0
	card.offset_top = -145.0
	card.offset_right = 265.0
	card.offset_bottom = 145.0
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
	title_lbl.add_theme_font_size_override("font_size", 19)
	style_header_banner(title_lbl, banner_color, 8, 7.0)
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.name = "BodyLabel"
	body_lbl.text = body_text
	body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 14)
	body_lbl.add_theme_color_override("font_color", INK_DARK)
	body_lbl.add_theme_stylebox_override("normal", make_card_style(PAPER_WARM, INK_BORDER, 8, 2, 3, 14.0, 10.0))
	vbox.add_child(body_lbl)

	var ok_btn := Button.new()
	ok_btn.name = "ConfirmButton"
	ok_btn.text = btn_text
	ok_btn.custom_minimum_size = Vector2(200, 42)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.add_theme_font_size_override("font_size", 15)
	style_Button(ok_btn, BTN_SAGE, 8, 5, 18.0, 7.0)
	vbox.add_child(ok_btn)

	parent.add_child(layer)

	card.pivot_offset = Vector2(265.0, 145.0)
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
		layer.visible = false
		layer.queue_free()
		if on_close.is_valid():
			on_close.call()

	ok_btn.pressed.connect(close_fn)
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

	var card := Panel.new()
	card.name = "ConfirmCard"
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280.0
	card.offset_top = -150.0
	card.offset_right = 280.0
	card.offset_bottom = 150.0
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
	title_lbl.add_theme_font_size_override("font_size", 20)
	style_header_banner(title_lbl, banner_color, 8, 7.0)
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.name = "BodyLabel"
	body_lbl.text = body_text
	body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 14)
	body_lbl.add_theme_color_override("font_color", INK_DARK)
	body_lbl.add_theme_stylebox_override("normal", make_card_style(PAPER_WARM, INK_BORDER, 8, 2, 3, 14.0, 10.0))
	vbox.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.name = "OkButton"
	ok_btn.text = ok_text
	ok_btn.custom_minimum_size = Vector2(210, 42)
	ok_btn.add_theme_font_size_override("font_size", 14)
	style_Button(ok_btn, BTN_SAGE, 8, 5, 14.0, 6.0)
	btn_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = cancel_text
	cancel_btn.custom_minimum_size = Vector2(180, 42)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	style_Button(cancel_btn, BTN_CORAL, 8, 5, 14.0, 6.0)
	btn_row.add_child(cancel_btn)

	parent.add_child(layer)

	var closed := [false]
	ok_btn.pressed.connect(func():
		if closed[0]:
			return
		closed[0] = true
		layer.visible = false
		layer.queue_free()
		if on_confirm.is_valid():
			on_confirm.call()
	)
	cancel_btn.pressed.connect(func():
		if closed[0]:
			return
		closed[0] = true
		layer.visible = false
		layer.queue_free()
		if on_cancel.is_valid():
			on_cancel.call()
	)
	return layer
