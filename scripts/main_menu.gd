extends Control

const UITheme = preload("res://scripts/ui_theme.gd")
const GameMenus = preload("res://scripts/game_menus.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

const BG_DESK := preload("res://assets/background_day.png")
const ICON_CASH := preload("res://assets/cashonhand.png")
const ICON_BANK := preload("res://assets/bank.png")
const GAMEPLAY_SCENE_PATH := "res://scenes/main_gameplay_interface.tscn"
const PREWARM_TEXTURES: PackedStringArray = [
	"res://assets/background_day_blur.png",
	"res://assets/phone.png",
	"res://assets/phone hover.png",
	"res://assets/laptop.png",
	"res://assets/laptop hover.png",
	"res://assets/budget.png",
	"res://assets/budget hover.png",
	"res://assets/planner.png",
	"res://assets/planner hover.png",
	"res://assets/envelope.png",
	"res://assets/open envelope.png",
	"res://assets/creditcard.png",
	"res://assets/creditscore.png",
	"res://assets/loan.png",
	"res://assets/social.png",
	"res://assets/no_goal.png",
	"res://assets/happy90.png",
	"res://assets/happy 60.png",
	"res://assets/neutral.png",
	"res://assets/sad40.png",
	"res://assets/sad10.png",
	"res://assets/planner face.png"
]

var _continue_card: PanelContainer
var _continue_btn: Button
var _delete_save_btn: Button
var _new_game_btn: Button
var _save_meta_lbl: Label
var _save_prog_bar: ProgressBar
var _save_prog_lbl: Label
var _selected_goal_index: int = 0
var _goal_cards: Array[Button] = []
var _goal_badges: Array[Label] = []
var _selected_goal_preview_card: PanelContainer
var _selected_goal_preview_lbl: RichTextLabel
var _is_transitioning: bool = false
var _pending_prewarm: Array[String] = []
var _warmed_textures: Array[Resource] = []

func _ready() -> void:
	_build_ui()
	_refresh_continue_state()
	if DisplayServer.get_name() != "headless":
		for tex_path in PREWARM_TEXTURES:
			if ResourceLoader.load_threaded_get_status(tex_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_request(tex_path, "Texture2D")
				_pending_prewarm.append(tex_path)

func _process(_delta: float) -> void:
	if _pending_prewarm.is_empty():
		return
	for i in range(_pending_prewarm.size() - 1, -1, -1):
		var tex_path: String = _pending_prewarm[i]
		var st := ResourceLoader.load_threaded_get_status(tex_path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(tex_path)
			if res:
				_warmed_textures.append(res)
			_pending_prewarm.remove_at(i)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pending_prewarm.remove_at(i)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = BG_DESK
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	
	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.11, 0.08, 0.05, 0.34)
	add_child(tint)
	
	# ==========================================
	# LEFT COLUMN: EDITORIAL TITLE & ACTIONS
	# ==========================================
	var left_card := Panel.new()
	left_card.name = "TitleCard"
	left_card.clip_contents = true
	left_card.offset_left = 36.0
	left_card.offset_top = 32.0
	left_card.offset_right = 524.0
	left_card.offset_bottom = 616.0
	left_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 18, 4, 8, 22.0, 18.0))
	add_child(left_card)
	
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24.0
	vb.offset_top = 18.0
	vb.offset_right = -24.0
	vb.offset_bottom = -18.0
	vb.add_theme_constant_override("separation", 10)
	left_card.add_child(vb)
	
	# Illustrated PALDO Title Lockup
	var title_box := PanelContainer.new()
	title_box.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.BTN_GOLD, UITheme.INK_BORDER, 14, 3, 6, 16.0, 10.0))
	vb.add_child(title_box)
	
	var title_hbox := HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.add_theme_constant_override("separation", 14)
	title_box.add_child(title_hbox)
	
	var ic_left := TextureRect.new()
	ic_left.texture = ICON_CASH
	ic_left.custom_minimum_size = Vector2(48, 48)
	ic_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_hbox.add_child(ic_left)
	
	var title_lbl := Label.new()
	title_lbl.name = "GameTitleLabel"
	title_lbl.text = "PALDO"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_type(title_lbl, UITheme.TYPE_DISPLAY, UITheme.FONT_DISPLAY)
	title_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	title_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.84, 0.9))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_hbox.add_child(title_lbl)
	
	var ic_right := TextureRect.new()
	ic_right.texture = ICON_BANK
	ic_right.custom_minimum_size = Vector2(48, 48)
	ic_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_hbox.add_child(ic_right)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "Labindalawang buwan ng sahod, ipon, at tamang desisyon bilang breadwinner."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_type(sub_lbl, UITheme.TYPE_BODY, UITheme.FONT_BODY)
	sub_lbl.add_theme_color_override("font_color", UITheme.INK_MUTED)
	vb.add_child(sub_lbl)
	
	# Live Saved Run Card (auto-hides if no saved run exists)
	_continue_card = PanelContainer.new()
	_continue_card.name = "SavedRunCard"
	_continue_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_WARM, UITheme.INK_BORDER, 10, 2, 4, 12.0, 10.0))
	vb.add_child(_continue_card)
	
	var c_vb := VBoxContainer.new()
	c_vb.add_theme_constant_override("separation", 8)
	_continue_card.add_child(c_vb)
	
	_save_meta_lbl = Label.new()
	_save_meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_type(_save_meta_lbl, UITheme.TYPE_BODY, UITheme.FONT_UI)
	_save_meta_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	c_vb.add_child(_save_meta_lbl)
	
	_save_prog_bar = ProgressBar.new()
	_save_prog_bar.custom_minimum_size = Vector2(0, 22)
	_save_prog_bar.show_percentage = false
	UITheme.style_progress_bar(_save_prog_bar, UITheme.BTN_SAGE, 6)
	c_vb.add_child(_save_prog_bar)
	
	_save_prog_lbl = Label.new()
	_save_prog_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_save_prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_prog_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_prog_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_type(_save_prog_lbl, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	_save_prog_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	_save_prog_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.94, 0.92))
	_save_prog_lbl.add_theme_constant_override("outline_size", 3)
	_save_prog_bar.add_child(_save_prog_lbl)
	
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	c_vb.add_child(action_row)
	
	_continue_btn = _make_btn("ContinueButton", "Continue Saved Run", UITheme.BTN_SAGE, 44)
	UITheme.set_button_icon(_continue_btn, UITheme.ICON_ARROW_RIGHT, true)
	_continue_btn.pressed.connect(_on_continue_pressed)
	action_row.add_child(_continue_btn)
	
	_delete_save_btn = _make_btn("DeleteSaveButton", "Burahin", UITheme.BTN_CORAL, 44)
	_delete_save_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_delete_save_btn.custom_minimum_size = Vector2(104, 44)
	_delete_save_btn.pressed.connect(_on_delete_save_pressed)
	action_row.add_child(_delete_save_btn)
	
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	
	# Live Selected Goal Summary Strip (links right-column selector to Start New Run)
	_selected_goal_preview_card = PanelContainer.new()
	_selected_goal_preview_card.name = "SelectedGoalPreview"
	_selected_goal_preview_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_STICKY, UITheme.INK_BORDER, 9, 2, 3, 12.0, 7.0))
	vb.add_child(_selected_goal_preview_card)
	
	_selected_goal_preview_lbl = RichTextLabel.new()
	_selected_goal_preview_lbl.name = "SelectedGoalPreviewLabel"
	_selected_goal_preview_lbl.bbcode_enabled = true
	_selected_goal_preview_lbl.fit_content = true
	_selected_goal_preview_lbl.scroll_active = false
	_selected_goal_preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_goal_preview_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_goal_preview_lbl.add_theme_color_override("default_color", UITheme.INK_DARK)
	_selected_goal_preview_lbl.add_theme_font_override("normal_font", UITheme.FONT_BODY)
	_selected_goal_preview_lbl.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
	_selected_goal_preview_lbl.add_theme_font_size_override("normal_font_size", 13)
	_selected_goal_preview_lbl.add_theme_font_size_override("bold_font_size", 13)
	_selected_goal_preview_card.add_child(_selected_goal_preview_lbl)
	
	_new_game_btn = _make_btn("NewGameButton", "Start New Run", UITheme.BTN_GOLD, 48, UITheme.TYPE_SUBHEAD)
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	vb.add_child(_new_game_btn)
	
	var secondary_row := HBoxContainer.new()
	secondary_row.add_theme_constant_override("separation", 10)
	vb.add_child(secondary_row)
	
	var how_btn := _make_btn("HowToPlayButton", "How to Play", UITheme.PAPER_KRAFT, 42)
	how_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		GameMenus.spawn_how_to_play_modal(self)
	)
	secondary_row.add_child(how_btn)
	
	var set_btn := _make_btn("SettingsButton", "Settings", UITheme.PAPER_CREAM, 42)
	set_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		GameMenus.spawn_settings_modal(self)
	)
	secondary_row.add_child(set_btn)
	
	var quit_btn := _make_btn("QuitButton", "Quit", UITheme.BTN_CORAL, 40)
	quit_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		get_tree().quit()
	)
	vb.add_child(quit_btn)
	
	# ==========================================
	# RIGHT COLUMN: 1-YEAR LIFE GOALS SHOWCASE
	# ==========================================
	var right_card := Panel.new()
	right_card.name = "VisionBoardCard"
	right_card.clip_contents = true
	right_card.offset_left = 552.0
	right_card.offset_top = 32.0
	right_card.offset_right = 1116.0
	right_card.offset_bottom = 616.0
	right_card.add_theme_stylebox_override("panel", UITheme.make_card_style(Color(0.93, 0.89, 0.79, 0.96), UITheme.INK_BORDER, 18, 4, 8, 20.0, 16.0))
	add_child(right_card)
	
	var r_vb := VBoxContainer.new()
	r_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	r_vb.offset_left = 20.0
	r_vb.offset_top = 20.0
	r_vb.offset_right = -20.0
	r_vb.offset_bottom = -20.0
	r_vb.add_theme_constant_override("separation", 12)
	right_card.add_child(r_vb)
	
	var board_hdr := Label.new()
	board_hdr.text = "Piliin ang 1-Year Life Goal"
	board_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_header_banner(board_hdr, UITheme.BTN_SAGE, 10, 6.0, UITheme.TYPE_SUBHEAD)
	r_vb.add_child(board_hdr)
	
	var board_hint := Label.new()
	board_hint.text = "I-click ang target na pangarap bago pindutin ang Start New Run."
	board_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_type(board_hint, UITheme.TYPE_CAPTION, UITheme.FONT_BODY)
	board_hint.add_theme_color_override("font_color", UITheme.INK_MUTED)
	r_vb.add_child(board_hint)
	
	_goal_cards.clear()
	_goal_badges.clear()
	var goals_list: Array = StatManager.life_goals
	for i in range(goals_list.size()):
		var g: Dictionary = goals_list[i]
		var g_btn := Button.new()
		g_btn.name = "GoalOption" + str(i)
		g_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		g_btn.custom_minimum_size = Vector2(0, 128)
		g_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UITheme.style_Button(g_btn, UITheme.PAPER_CREAM, 12, 4, 10.0, 8.0)
		
		var g_hb := HBoxContainer.new()
		g_hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		g_hb.offset_left = 14.0
		g_hb.offset_top = 10.0
		g_hb.offset_right = -14.0
		g_hb.offset_bottom = -10.0
		g_hb.add_theme_constant_override("separation", 14)
		g_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_btn.add_child(g_hb)
		
		var pic_frame := PanelContainer.new()
		pic_frame.custom_minimum_size = Vector2(78, 78)
		pic_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pic_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic_frame.add_theme_stylebox_override("panel", UITheme.make_card_style(Color(0.99, 0.97, 0.92, 1.0), UITheme.INK_BORDER, 10, 2, 3, 5.0, 5.0))
		var g_tex := TextureRect.new()
		g_tex.texture = g.get("icon", null)
		g_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		g_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic_frame.add_child(g_tex)
		g_hb.add_child(pic_frame)
		
		var text_vb := VBoxContainer.new()
		text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text_vb.add_theme_constant_override("separation", 4)
		text_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_hb.add_child(text_vb)
		
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vb.add_child(top_row)
		
		var title_item := Label.new()
		title_item.text = str(g.get("title", ""))
		title_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.apply_type(title_item, UITheme.TYPE_SUBHEAD, UITheme.FONT_BOLD)
		title_item.add_theme_color_override("font_color", UITheme.INK_DARK)
		top_row.add_child(title_item)
		
		var badge := Label.new()
		badge.name = "SelectedBadge"
		badge.text = "Napili"
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.apply_type(badge, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
		badge.add_theme_color_override("font_color", UITheme.INK_DARK)
		badge.add_theme_stylebox_override("normal", UITheme.make_tactile_btn_style(UITheme.BTN_SAGE, UITheme.INK_BORDER, 6, 2, 8.0, 2.0))
		top_row.add_child(badge)
		
		var g_rtf := RichTextLabel.new()
		g_rtf.bbcode_enabled = true
		g_rtf.fit_content = true
		g_rtf.scroll_active = false
		g_rtf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g_rtf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_rtf.add_theme_color_override("default_color", UITheme.INK_DARK)
		g_rtf.add_theme_font_override("normal_font", UITheme.FONT_BODY)
		g_rtf.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
		g_rtf.add_theme_font_size_override("normal_font_size", UITheme.TYPE_BODY)
		g_rtf.add_theme_font_size_override("bold_font_size", UITheme.TYPE_BODY)
		var diff_str: String = str(g.get("difficulty", "Balanced"))
		var diff_hex := "#1c7033" if diff_str == "Balanced" else ("#94520d" if diff_str == "Challenging" else "#a8261f")
		var rec_str := "  •  [color=#1c7033]Recommended[/color]" if bool(g.get("recommended", false)) else ""
		g_rtf.text = "[color=#94520d][b]₱%s[/b][/color]  •  [color=%s][b]%s[/b][/color]%s\n[color=#5c4f45]%s[/color]" % [
			UITheme.format_num(int(g.get("cost", 40000))),
			diff_hex,
			diff_str,
			rec_str,
			str(g.get("description", ""))
		]
		text_vb.add_child(g_rtf)
		
		g_btn.pressed.connect(_select_goal_card.bind(i, true))
		r_vb.add_child(g_btn)
		_goal_cards.append(g_btn)
		_goal_badges.append(badge)
	
	_select_goal_card(0, false)
	
	# Staggered entrance animation (exponential ease-out)
	left_card.modulate.a = 0.0
	left_card.position.x = 18.0
	right_card.modulate.a = 0.0
	right_card.position.x = 570.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(left_card, "modulate:a", 1.0, 0.22)
	tw.tween_property(left_card, "position:x", 36.0, 0.24)
	tw.tween_property(right_card, "modulate:a", 1.0, 0.26).set_delay(0.05)
	tw.tween_property(right_card, "position:x", 552.0, 0.28).set_delay(0.05)

func _select_goal_card(index: int, play_sound: bool = true) -> void:
	var goals_list: Array = StatManager.life_goals
	if goals_list.is_empty():
		return
	_selected_goal_index = clamp(index, 0, goals_list.size() - 1)
	if play_sound:
		AudioManager.play_sfx("toggle")
	for i in range(_goal_cards.size()):
		var is_sel: bool = (i == _selected_goal_index)
		var card_bg: Color = UITheme.PAPER_KRAFT if is_sel else UITheme.PAPER_CREAM
		UITheme.style_Button(_goal_cards[i], card_bg, 12, 4, 10.0, 8.0)
		if i < _goal_badges.size():
			_goal_badges[i].visible = is_sel
	if _selected_goal_preview_lbl:
		var g: Dictionary = goals_list[_selected_goal_index]
		var diff_str: String = str(g.get("difficulty", "Balanced"))
		var diff_hex := "#1c7033" if diff_str == "Balanced" else ("#94520d" if diff_str == "Challenging" else "#a8261f")
		_selected_goal_preview_lbl.text = "[center]Napiling Goal: [b]%s[/b]\n[color=#94520d][b]₱%s[/b][/color]  •  [color=%s][b]%s[/b][/color][/center]" % [
			str(g.get("title", "")),
			UITheme.format_num(int(g.get("cost", 40000))),
			diff_hex,
			diff_str
		]

func _make_btn(btn_name: String, txt: String, col: Color, min_h: int = 44, font_sz: int = UITheme.TYPE_BODY) -> Button:
	var btn := Button.new()
	btn.name = btn_name
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_type(btn, font_sz, UITheme.FONT_UI)
	UITheme.style_Button(btn, col, 10, 5, 14.0, 6.0)
	return btn

func _refresh_continue_state() -> void:
	var meta := SaveManager.get_save_summary()
	var has_valid := not meta.is_empty()
	if _continue_card:
		_continue_card.visible = has_valid
	if not has_valid:
		return
	var run_status := str(meta.get("run_status", "active"))
	var sav: int = int(meta.get("savings", 0))
	var target: int = max(1, int(meta.get("goal_target", 40000)))
	var pct: int = clamp(int(round((float(sav) / float(target)) * 100.0)), 0, 100)
	if run_status == "active":
		_continue_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_WARM, UITheme.INK_BORDER, 10, 2, 4, 12.0, 10.0))
		if _continue_btn:
			_continue_btn.visible = true
		if _delete_save_btn:
			_delete_save_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
			_delete_save_btn.custom_minimum_size = Vector2(104, 44)
			_delete_save_btn.text = "Burahin"
		if _save_meta_lbl:
			_save_meta_lbl.text = "%s %d, 2026  •  %s" % [
				str(meta.get("month_name", "January")),
				int(meta.get("day", 1)),
				str(meta.get("goal_title", "Life Goal"))
			]
	else:
		var is_go := (run_status == "game_over")
		var card_bg := Color(0.96, 0.88, 0.85, 1.0) if is_go else Color(0.87, 0.94, 0.85, 1.0)
		_continue_card.add_theme_stylebox_override("panel", UITheme.make_card_style(card_bg, UITheme.INK_BORDER, 10, 2, 4, 12.0, 10.0))
		if _continue_btn:
			_continue_btn.visible = false
		if _delete_save_btn:
			_delete_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_delete_save_btn.custom_minimum_size = Vector2(0, 42)
			_delete_save_btn.text = "Burahin ang Record"
		if _save_meta_lbl:
			var end_lbl := str(meta.get("ending_title", "Completed Run"))
			var avg_g := str(meta.get("average_grade", "—"))
			if is_go:
				_save_meta_lbl.text = "Game Over  •  %s %d, 2026\n%s" % [
					str(meta.get("month_name", "")),
					int(meta.get("day", 1)),
					str(meta.get("goal_title", "Life Goal"))
				]
			else:
				_save_meta_lbl.text = "Tapos na Laro: %s\n%s  •  Avg Grade: %s" % [
					end_lbl,
					str(meta.get("goal_title", "Life Goal")),
					avg_g
				]
	if _save_prog_bar:
		_save_prog_bar.max_value = target
		_save_prog_bar.value = min(sav, target)
	if _save_prog_lbl:
		_save_prog_lbl.text = "₱%s / ₱%s (%d%%)" % [
			UITheme.format_num(sav),
			UITheme.format_num(target),
			pct
		]

func _on_delete_save_pressed() -> void:
	if _is_transitioning:
		return
	AudioManager.play_sfx("click")
	UITheme.spawn_game_confirm(
		self,
		"Burahin ang Saved Run?",
		"Sigurado ka bang gusto mong burahin ang naka-save mong progress? Hindi na ito maibabalik.",
		"Oo, Burahin",
		"Kanselahin",
		UITheme.BTN_CORAL,
		func():
			AudioManager.play_sfx("error_bump")
			SaveManager.clear_save_file()
			_refresh_continue_state(),
		Callable()
	)

func _begin_transition(mode: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	if _new_game_btn:
		_new_game_btn.disabled = true
	if _continue_btn:
		_continue_btn.disabled = true
	if _delete_save_btn:
		_delete_save_btn.disabled = true
	for card in _goal_cards:
		card.disabled = true
	if _new_game_btn and mode == "new":
		_new_game_btn.text = "Naghahanda ng Desk..."
	elif _continue_btn and mode == "continue":
		_continue_btn.text = "Naghahanda ng Desk..."
	await get_tree().process_frame
	if mode == "new":
		StatManager.reset_for_new_run()
		StatManager.select_life_goal(_selected_goal_index)
		var chosen: Dictionary = StatManager.get_current_goal()
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Piniling Life Goal: " + str(chosen.get("title", "")) + " — Target ₱" + UITheme.format_num(int(chosen.get("cost", 40000))))
	elif mode == "continue":
		if not SaveManager.load_game():
			StatManager.reset_for_new_run()
			StatManager.select_life_goal(_selected_goal_index)
	get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("opportunity")
	_begin_transition("continue")

func _on_new_game_pressed() -> void:
	if SaveManager.has_active_save():
		AudioManager.play_sfx("click")
		var meta := SaveManager.get_save_summary()
		var msg := "May aktibong laro ka pa sa %s %d (%s).\nMabubura ang kasalukuyang save kapag nagsimula ka ng bagong laro. Ituloy ba?" % [
			str(meta.get("month_name", "January")),
			int(meta.get("day", 1)),
			str(meta.get("goal_title", "Life Goal"))
		]
		UITheme.spawn_game_confirm(
			self,
			"May Naka-Save Pang Laro",
			msg,
			"Simulan ang Bago",
			"Kanselahin",
			UITheme.BTN_GOLD,
			func():
				AudioManager.play_sfx("opportunity")
				_begin_transition("new"),
			Callable()
		)
	else:
		AudioManager.play_sfx("opportunity")
		_begin_transition("new")
