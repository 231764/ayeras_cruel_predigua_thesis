class_name GameMenus
extends RefCounted

const UITheme = preload("res://scripts/ui_theme.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

const ICON_BUDGET := preload("res://assets/budget.png")
const ICON_HAPPY := preload("res://assets/happy90.png")
const ICON_CREDIT := preload("res://assets/creditcard.png")
const ICON_SCORE := preload("res://assets/creditscore.png")

static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("AudioManager")
	return null

static func _play_sfx(sfx_name: String) -> void:
	var am := _audio()
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx_name)

static func spawn_settings_modal(parent: Node, on_closed: Callable = Callable()) -> CanvasLayer:
	var am := _audio()
	var layer := CanvasLayer.new()
	layer.name = "SettingsModalCanvas"
	layer.layer = 125
	
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 0.76)
	layer.add_child(backdrop)
	
	var card := Panel.new()
	card.name = "SettingsCard"
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280.0
	card.offset_top = -230.0
	card.offset_right = 280.0
	card.offset_bottom = 230.0
	card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 14, 3, 7, 18.0, 14.0))
	backdrop.add_child(card)
	
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20.0
	vb.offset_top = 16.0
	vb.offset_right = -20.0
	vb.offset_bottom = -16.0
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	
	var hdr := Label.new()
	hdr.text = "Settings"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_header_banner(hdr, UITheme.BTN_GOLD, 8, 6.0, UITheme.TYPE_HEADING)
	vb.add_child(hdr)
	
	var body_panel := PanelContainer.new()
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_panel.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_WARM, UITheme.INK_BORDER, 8, 2, 3, 14.0, 12.0))
	vb.add_child(body_panel)
	
	var content_vb := VBoxContainer.new()
	content_vb.add_theme_constant_override("separation", 10)
	body_panel.add_child(content_vb)
	
	content_vb.add_child(_make_slider_row("Master Volume", am.master_volume if am else 0.85, func(v: float):
		if am: am.set_master_volume(v)
	))
	
	content_vb.add_child(_make_slider_row("Music Volume", am.music_volume if am else 0.55, func(v: float):
		if am: am.set_music_volume(v)
	))
	var mute_row := HBoxContainer.new()
	mute_row.add_theme_constant_override("separation", 14)
	content_vb.add_child(mute_row)
	
	var mute_music_cb := CheckBox.new()
	mute_music_cb.text = "Mute Music"
	mute_music_cb.button_pressed = am.music_muted if am else false
	UITheme.apply_type(mute_music_cb, UITheme.TYPE_BODY, UITheme.FONT_UI)
	mute_music_cb.add_theme_color_override("font_color", UITheme.INK_DARK)
	mute_music_cb.toggled.connect(func(on: bool):
		if am: am.set_music_muted(on)
	)
	mute_row.add_child(mute_music_cb)
	
	var mute_sfx_cb := CheckBox.new()
	mute_sfx_cb.text = "Mute Sound Effects"
	mute_sfx_cb.button_pressed = am.sfx_muted if am else false
	UITheme.apply_type(mute_sfx_cb, UITheme.TYPE_BODY, UITheme.FONT_UI)
	mute_sfx_cb.add_theme_color_override("font_color", UITheme.INK_DARK)
	mute_sfx_cb.toggled.connect(func(on: bool):
		if am: am.set_sfx_muted(on)
	)
	mute_row.add_child(mute_sfx_cb)
	
	content_vb.add_child(_make_slider_row("Sound Effects", am.sfx_volume if am else 0.85, func(v: float):
		if am: am.set_sfx_volume(v)
	))
	
	var spd_row := HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 10)
	content_vb.add_child(spd_row)
	var spd_lbl := Label.new()
	spd_lbl.text = "Auto-Play Speed:"
	spd_lbl.custom_minimum_size = Vector2(130, 0)
	UITheme.apply_type(spd_lbl, UITheme.TYPE_BODY, UITheme.FONT_UI)
	spd_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	spd_row.add_child(spd_lbl)
	
	var spd_opt := OptionButton.new()
	spd_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var labels_list: Array = am.AUTOPLAY_LABELS if am else ["Normal (0.35s/day)", "Fast (0.20s/day)", "Turbo (0.09s/day)"]
	for lbl_txt in labels_list:
		spd_opt.add_item(str(lbl_txt))
	spd_opt.selected = am.autoplay_speed_index if am else 1
	UITheme.style_option_button(spd_opt)
	spd_opt.item_selected.connect(func(idx: int):
		if am: am.set_autoplay_speed(idx)
		_play_sfx("click")
	)
	spd_row.add_child(spd_opt)
	
	var test_sfx_btn := Button.new()
	test_sfx_btn.text = "Test Sound"
	test_sfx_btn.custom_minimum_size = Vector2(120, 34)
	UITheme.apply_type(test_sfx_btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.style_Button(test_sfx_btn, UITheme.PAPER_KRAFT, 6, 3, 10.0, 4.0)
	test_sfx_btn.pressed.connect(func(): _play_sfx("coin"))
	content_vb.add_child(test_sfx_btn)
	
	var close_btn := Button.new()
	close_btn.name = "CloseSettingsButton"
	close_btn.text = "Done"
	close_btn.custom_minimum_size = Vector2(180, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.apply_type(close_btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.style_Button(close_btn, UITheme.BTN_SAGE, 8, 5, 16.0, 6.0)
	close_btn.pressed.connect(func():
		_play_sfx("click")
		layer.visible = false
		layer.queue_free()
		if on_closed.is_valid():
			on_closed.call()
	)
	vb.add_child(close_btn)
	
	parent.add_child(layer)
	_animate_card(card, Vector2(280, 230))
	return layer

static func _make_slider_row(label_text: String, initial_val: float, on_changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	UITheme.apply_type(lbl, UITheme.TYPE_BODY, UITheme.FONT_UI)
	lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	row.add_child(lbl)
	
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	
	var pct_lbl := Label.new()
	pct_lbl.text = str(int(round(initial_val * 100.0))) + "%"
	pct_lbl.custom_minimum_size = Vector2(46, 0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_type(pct_lbl, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	pct_lbl.add_theme_color_override("font_color", UITheme.INK_MUTED)
	row.add_child(pct_lbl)
	
	slider.value_changed.connect(func(v: float):
		pct_lbl.text = str(int(round(v * 100.0))) + "%"
		on_changed.call(v)
	)
	return row

static func spawn_how_to_play_modal(parent: Node, on_closed: Callable = Callable()) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "HowToPlayModalCanvas"
	layer.layer = 125
	
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 0.76)
	layer.add_child(backdrop)
	
	var card := Panel.new()
	card.name = "HowToPlayCard"
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -435.0
	card.offset_top = -275.0
	card.offset_right = 435.0
	card.offset_bottom = 275.0
	card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 14, 3, 7, 18.0, 14.0))
	backdrop.add_child(card)
	
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20.0
	vb.offset_top = 16.0
	vb.offset_right = -20.0
	vb.offset_bottom = -16.0
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	
	var hdr := Label.new()
	hdr.text = "Paano Maglaro"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_header_banner(hdr, UITheme.BTN_SAGE, 8, 6.0, UITheme.TYPE_HEADING)
	vb.add_child(hdr)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)
	
	var cards_data := [
		[ICON_BUDGET, "Cash Envelopes", "Gamitin ang Smart Split tuwing Sahod (Day 1 at Day 15) para pondohan ang Upa, Bills, Pagkain, at Byahe."],
		[ICON_HAPPY, "Daily Routine at Weekend", "Panatilihing 50 pataas ang Happiness at Social. Kumpletohin ang 7 araw na envelope coverage para sa Streak Bonus."],
		[ICON_CREDIT, "Credit, Loans at Ipon", "Bayaran ang Credit Card sa Day 25 para iwas 3% interest. Kumita ng 0.5%/buwan (6%/yr) sa Digital Bank Ipon."],
		[ICON_SCORE, "Layunin sa Katapusan ng Taon", "Bago mag-Dec 31: 100% Life Goal, Happy/Social 50+, Credit Score 70+, at ₱0 Utang. Silipin ang Report Card tab para sa buwanang S Grade bonus."]
	]
	for cd in cards_data:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_WARM, UITheme.INK_BORDER, 10, 2, 4, 12.0, 10.0))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		box.add_child(hb)
		var ic := TextureRect.new()
		ic.texture = cd[0]
		ic.custom_minimum_size = Vector2(46, 46)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(ic)
		var cvb := VBoxContainer.new()
		cvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cvb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cvb.add_theme_constant_override("separation", 4)
		hb.add_child(cvb)
		var tl := Label.new()
		tl.text = str(cd[1])
		UITheme.apply_type(tl, UITheme.TYPE_SUBHEAD, UITheme.FONT_HEADING)
		tl.add_theme_color_override("font_color", UITheme.INK_DARK)
		cvb.add_child(tl)
		var dl := Label.new()
		dl.text = str(cd[2])
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_type(dl, UITheme.TYPE_BODY, UITheme.FONT_BODY)
		dl.add_theme_color_override("font_color", UITheme.INK_MUTED)
		cvb.add_child(dl)
		grid.add_child(box)
		
	var keys_lbl := Label.new()
	keys_lbl.text = "Shortcuts:  [Space] Susunod  •  [F] Auto-Play  •  [1] Status  •  [2] Planner  •  [3] Budget  •  [4] Phone  •  [Esc] Menu"
	keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_type(keys_lbl, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	keys_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	keys_lbl.add_theme_stylebox_override("normal", UITheme.make_card_style(UITheme.PAPER_STICKY, UITheme.INK_BORDER, 6, 2, 2, 10.0, 5.0))
	vb.add_child(keys_lbl)
	
	var close_btn := Button.new()
	close_btn.name = "CloseHowToPlayButton"
	close_btn.text = "Okay, Simulan Na"
	close_btn.custom_minimum_size = Vector2(210, 42)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.apply_type(close_btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.style_Button(close_btn, UITheme.BTN_GOLD, 8, 5, 16.0, 6.0)
	close_btn.pressed.connect(func():
		_play_sfx("click")
		layer.visible = false
		layer.queue_free()
		if on_closed.is_valid():
			on_closed.call()
	)
	vb.add_child(close_btn)
	
	parent.add_child(layer)
	_animate_card(card, Vector2(435, 275))
	return layer

static func spawn_pause_modal(parent: Node, on_resume: Callable, on_exit_menu: Callable) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "PauseMenuCanvas"
	layer.layer = 122
	
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 0.74)
	layer.add_child(backdrop)
	
	var card := Panel.new()
	card.name = "PauseCard"
	card.clip_contents = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -205.0
	card.offset_top = -175.0
	card.offset_right = 205.0
	card.offset_bottom = 175.0
	card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 14, 3, 7, 18.0, 14.0))
	backdrop.add_child(card)
	
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 22.0
	vb.offset_top = 18.0
	vb.offset_right = -22.0
	vb.offset_bottom = -18.0
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	
	var hdr := Label.new()
	hdr.text = "Paused"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_header_banner(hdr, UITheme.BTN_GOLD, 8, 6.0, UITheme.TYPE_HEADING)
	vb.add_child(hdr)
	
	var resume_btn := _make_menu_btn("Resume", UITheme.BTN_SAGE)
	resume_btn.pressed.connect(func():
		_play_sfx("click")
		layer.visible = false
		layer.queue_free()
		if on_resume.is_valid():
			on_resume.call()
	)
	vb.add_child(resume_btn)
	
	var howto_btn := _make_menu_btn("How to Play", UITheme.PAPER_KRAFT)
	howto_btn.pressed.connect(func():
		_play_sfx("click")
		spawn_how_to_play_modal(parent)
	)
	vb.add_child(howto_btn)
	
	var set_btn := _make_menu_btn("Settings", UITheme.PAPER_CREAM)
	set_btn.pressed.connect(func():
		_play_sfx("click")
		spawn_settings_modal(parent)
	)
	vb.add_child(set_btn)
	
	var exit_btn := _make_menu_btn("Save & Main Menu", UITheme.BTN_CORAL)
	exit_btn.pressed.connect(func():
		_play_sfx("click")
		SaveManager.save_game()
		layer.visible = false
		layer.queue_free()
		if on_exit_menu.is_valid():
			on_exit_menu.call()
	)
	vb.add_child(exit_btn)
	
	parent.add_child(layer)
	_animate_card(card, Vector2(205, 175))
	return layer

static func _make_menu_btn(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_type(btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.style_Button(btn, col, 8, 5, 14.0, 6.0)
	return btn

static func _animate_card(card: Control, pivot: Vector2) -> void:
	card.pivot_offset = pivot
	card.scale = Vector2(0.95, 0.95)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.15)
	tw.tween_property(card, "modulate:a", 1.0, 0.14)
