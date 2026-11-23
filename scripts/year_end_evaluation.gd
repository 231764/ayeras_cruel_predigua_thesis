extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

const ICON_GOAL_DEFAULT := preload("res://assets/goal_kapatid.png")
const ICON_JOYFUL := preload("res://assets/happy90.png")
const ICON_HAPPY := preload("res://assets/happy 60.png")
const ICON_NEUTRAL := preload("res://assets/neutral.png")
const ICON_SAD := preload("res://assets/sad40.png")
const ICON_SCORE := preload("res://assets/creditscore.png")
const ICON_LOAN := preload("res://assets/loan.png")

signal evaluation_closed
signal play_again_requested

@onready var hero_card: PanelContainer = $Backdrop/Panel/VBoxContainer/HeroCard
@onready var goal_frame: PanelContainer = $Backdrop/Panel/VBoxContainer/HeroCard/HeroHBox/GoalFrame
@onready var goal_icon_rect: TextureRect = $Backdrop/Panel/VBoxContainer/HeroCard/HeroHBox/GoalFrame/GoalIcon
@onready var mood_frame: PanelContainer = $Backdrop/Panel/VBoxContainer/HeroCard/HeroHBox/MoodFrame
@onready var mood_icon_rect: TextureRect = $Backdrop/Panel/VBoxContainer/HeroCard/HeroHBox/MoodFrame/MoodIcon
@onready var title_label: Label = $Backdrop/Panel/VBoxContainer/HeroCard/HeroHBox/CenterVBox/TitleLabel
@onready var subtitle_label: Label = $Backdrop/Panel/VBoxContainer/HeroCard/HeroHBox/CenterVBox/SubtitleLabel
@onready var pillars_row: HBoxContainer = $Backdrop/Panel/VBoxContainer/PillarsRow
@onready var grades_strip_card: PanelContainer = $Backdrop/Panel/VBoxContainer/GradesStripCard
@onready var grades_strip_hbox: HBoxContainer = $Backdrop/Panel/VBoxContainer/GradesStripCard/GradesStripHBox
@onready var report_label: RichTextLabel = $Backdrop/Panel/VBoxContainer/StoryPanel/ReportLabel
@onready var export_ledger_button: Button = $Backdrop/Panel/VBoxContainer/ButtonsRow/ExportLedgerButton
@onready var play_again_button: Button = $Backdrop/Panel/VBoxContainer/ButtonsRow/PlayAgainButton
@onready var close_button: Button = $Backdrop/Panel/VBoxContainer/ButtonsRow/CloseButton

var last_eval_data: Dictionary = {}

func _ready() -> void:
	visible = false
	_apply_visual_styles()

func _apply_visual_styles() -> void:
	if hero_card:
		hero_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.BTN_GOLD, UITheme.INK_BORDER, 12, 3, 5, 14.0, 10.0))
	if goal_frame:
		goal_frame.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 10, 2, 3, 6.0, 6.0))
	if mood_frame:
		mood_frame.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 10, 2, 3, 6.0, 6.0))
	if title_label:
		UITheme.apply_type(title_label, UITheme.TYPE_HEADING, UITheme.FONT_HEADING)
		title_label.add_theme_color_override("font_color", UITheme.INK_DARK)
	if subtitle_label:
		UITheme.apply_type(subtitle_label, UITheme.TYPE_SUBHEAD, UITheme.FONT_UI)
		subtitle_label.add_theme_color_override("font_color", UITheme.INK_DARK)
	if grades_strip_card:
		grades_strip_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_STICKY, UITheme.INK_BORDER, 8, 2, 3, 10.0, 6.0))
	if report_label:
		report_label.add_theme_font_override("normal_font", UITheme.FONT_BODY)
		report_label.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
		report_label.add_theme_font_override("italics_font", UITheme.FONT_BODY)
		report_label.add_theme_font_size_override("normal_font_size", UITheme.TYPE_BODY)
		report_label.add_theme_font_size_override("bold_font_size", UITheme.TYPE_BODY)
	UITheme.style_Button(export_ledger_button, UITheme.BTN_BLUE, 8, 4, 12.0, 6.0)
	UITheme.set_button_icon(export_ledger_button, UITheme.ICON_DOWNLOAD, false)
	UITheme.style_Button(play_again_button, UITheme.BTN_SAGE, 8, 4, 12.0, 6.0)
	UITheme.style_Button(close_button, UITheme.BTN_GOLD, 8, 4, 12.0, 6.0)

func _animate_modal_in() -> void:
	var panel_node: Control = get_node_or_null("Backdrop/Panel")
	if not panel_node:
		return
	panel_node.pivot_offset = panel_node.size * 0.5
	panel_node.scale = Vector2(0.96, 0.96)
	panel_node.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_node, "scale", Vector2.ONE, 0.18)
	tw.tween_property(panel_node, "modulate:a", 1.0, 0.16)

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _make_pillar_card(icon_tex: Texture2D, heading_txt: String, value_txt: String, passed: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := Color(0.88, 0.95, 0.85, 1.0) if passed else Color(0.96, 0.87, 0.85, 1.0)
	card.add_theme_stylebox_override("panel", UITheme.make_card_style(bg, UITheme.INK_BORDER, 9, 2, 3, 10.0, 7.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 6)
	vb.add_child(top_hb)

	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.custom_minimum_size = Vector2(24, 24)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_hb.add_child(ic)

	var h_lbl := Label.new()
	h_lbl.text = heading_txt
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_type(h_lbl, UITheme.TYPE_CAPTION, UITheme.FONT_HEADING)
	h_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	top_hb.add_child(h_lbl)

	var pill := Label.new()
	pill.text = "Naabot" if passed else "Kulang"
	UITheme.apply_type(pill, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	pill.add_theme_color_override("font_color", UITheme.INK_DARK)
	pill.add_theme_stylebox_override("normal", UITheme.make_tactile_btn_style(UITheme.BTN_SAGE if passed else UITheme.BTN_CORAL, UITheme.INK_BORDER, 5, 2, 6.0, 2.0))
	top_hb.add_child(pill)

	var v_lbl := Label.new()
	v_lbl.text = value_txt
	UITheme.apply_type(v_lbl, UITheme.TYPE_BODY, UITheme.FONT_UI)
	v_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	vb.add_child(v_lbl)
	return card

func show_year_end_evaluation() -> Dictionary:
	last_eval_data = StatManager.evaluate_year_end()
	var ending_id := str(last_eval_data.get("ending_id", "financial_struggle"))
	var avg_grade := StatManager.get_average_grade_text()

	var banner_col := UITheme.BTN_CORAL
	if ending_id == "full_paldo":
		banner_col = UITheme.BTN_GOLD
	elif ending_id in ["pyrrhic_goal", "debt_free_survivor"]:
		banner_col = UITheme.BTN_SAGE
	if hero_card:
		hero_card.add_theme_stylebox_override("panel", UITheme.make_card_style(banner_col, UITheme.INK_BORDER, 12, 3, 5, 14.0, 10.0))

	var g_dict := StatManager.get_current_goal()
	if goal_icon_rect:
		goal_icon_rect.texture = g_dict.get("icon", ICON_GOAL_DEFAULT)
	if mood_icon_rect:
		var hap := StatManager.happy
		mood_icon_rect.texture = ICON_JOYFUL if hap >= 80 else (ICON_HAPPY if hap >= 55 else (ICON_NEUTRAL if hap >= 35 else ICON_SAD))

	if title_label:
		title_label.text = str(last_eval_data["ending_title"])
	if subtitle_label:
		subtitle_label.text = "%d sa 4 na Layunin  •  Average Grade: %s" % [int(last_eval_data["conditions_met_count"]), avg_grade]

	# Build 4 Visual Victory Pillar Cards
	if pillars_row:
		_clear_children(pillars_row)
		var g_ok := bool(last_eval_data["goal_reached"])
		var w_ok := bool(last_eval_data["wellbeing_maintained"])
		var c_ok := bool(last_eval_data["good_credit"])
		var d_ok := bool(last_eval_data["debt_free"])
		pillars_row.add_child(_make_pillar_card(
			g_dict.get("icon", ICON_GOAL_DEFAULT),
			"Life Goal",
			"₱" + UITheme.format_num(int(last_eval_data["savings"])) + " / ₱" + UITheme.format_num(int(last_eval_data["goal_target"])),
			g_ok
		))
		pillars_row.add_child(_make_pillar_card(
			ICON_HAPPY,
			"Well-Being",
			"Happy %d • Social %d" % [int(last_eval_data["happy"]), int(last_eval_data["social"])],
			w_ok
		))
		pillars_row.add_child(_make_pillar_card(
			ICON_SCORE,
			"Credit Score",
			"%d / 100" % int(last_eval_data["credit_score"]),
			c_ok
		))
		pillars_row.add_child(_make_pillar_card(
			ICON_LOAN,
			"Walang Utang",
			"₱" + UITheme.format_num(int(last_eval_data["total_obligations"])),
			d_ok
		))

	# Build 12-Month Report Card Strip
	if grades_strip_hbox:
		_clear_children(grades_strip_hbox)
		var title_l := Label.new()
		title_l.text = "Grades:"
		UITheme.apply_type(title_l, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
		title_l.add_theme_color_override("font_color", UITheme.INK_DARK)
		grades_strip_hbox.add_child(title_l)

		var g_by_idx: Dictionary = {}
		var g_by_name: Dictionary = {}
		for rec in StatManager.monthly_grades_history:
			if rec is Dictionary:
				var mi := int(rec.get("month_idx", -1))
				if mi >= 0:
					g_by_idx[mi] = rec
				g_by_name[str(rec.get("month", ""))] = rec
		for m_idx in range(StatManager.year.size()):
			var m_name: String = str(StatManager.year[m_idx]["month"])
			var rec: Dictionary = g_by_idx.get(m_idx, g_by_name.get(m_name, {}))
			var gr := str(rec.get("grade", "—")) if not rec.is_empty() else "—"
			var bg_c := Color(0.86, 0.83, 0.77, 1.0)
			if gr == "S":
				bg_c = UITheme.BTN_GOLD
			elif gr == "A":
				bg_c = UITheme.BTN_SAGE
			elif gr == "B":
				bg_c = UITheme.PAPER_KRAFT
			elif gr == "C":
				bg_c = UITheme.BTN_CORAL
			var pill := Label.new()
			pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pill.text = m_name.substr(0, 3) + ": " + gr
			UITheme.apply_type(pill, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
			pill.add_theme_color_override("font_color", UITheme.INK_DARK)
			pill.add_theme_stylebox_override("normal", UITheme.make_tactile_btn_style(bg_c, UITheme.INK_BORDER, 5, 2, 4.0, 2.0))
			grades_strip_hbox.add_child(pill)

	# Concise Financial Highlights + Narrative + Baldo Verdict
	var l_stats := LedgerManager.get_analytics_summary()
	var txt := "[b]Buod ng Pananalapi Ngayong Taon:[/b]\n"
	txt += "• Trabaho: " + StatManager.get_employment_display_text() + "   •   Natirang Cash: ₱" + UITheme.format_num(int(last_eval_data["current_balance"])) + "\n"
	txt += "• Pumasok: [color=#1c7033]+₱" + UITheme.format_num(int(l_stats["total_inflow"])) + "[/color]   •   Nagastos: [color=#a8261f]-₱" + UITheme.format_num(int(l_stats["total_outflow"])) + "[/color]   •   Net Worth: [b]₱" + UITheme.format_num(int(l_stats["net_worth"])) + "[/b]\n"
	txt += "• Tubo sa Ipon: [color=#1c7033]+₱" + UITheme.format_num(StatManager.total_savings_interest_earned) + "[/color]   •   Interest sa Utang: [color=#a8261f]₱" + UITheme.format_num(StatManager.total_credit_interest_incurred + StatManager.total_loan_interest_incurred) + "[/color]   •   Investment P&L: [color=#1a4b7c]₱" + UITheme.format_num(StatManager.total_investment_gains) + "[/color]\n"
	txt += "• Master Ledger: [b]" + str(l_stats["entry_count"]) + "[/b] Records   •   Badges: [color=#1a4b7c][b]" + str(l_stats["achievements_unlocked"]) + " / " + str(l_stats["achievements_total"]) + "[/b][/color]\n\n"
	txt += "[b]Kwento ng Iyong Taon:[/b]\n" + str(last_eval_data["ending_summary"]) + "\n\n"
	txt += "[b][color=#94520d]Mensahe ni Baldo:[/color][/b]\n[i]\"" + str(last_eval_data["baldo_verdict"]) + "\"[/i]"

	report_label.text = txt
	if export_ledger_button:
		export_ledger_button.text = "Download Ledger"
		export_ledger_button.disabled = false
	visible = true
	if bool(last_eval_data.get("is_full_paldo", false)):
		AudioManager.play_sfx("grade_s")
	elif int(last_eval_data.get("conditions_met_count", 0)) >= 2:
		AudioManager.play_sfx("milestone")
	else:
		AudioManager.play_sfx("alert")
	_animate_modal_in()
	return last_eval_data

func _on_export_ledger_button_pressed() -> void:
	var res := LedgerManager.export_to_device_downloads()
	if export_ledger_button:
		if bool(res.get("ok", false)):
			AudioManager.play_sfx("coin")
			var folder_lbl: String = str(res.get("folder_label", "Downloads"))
			export_ledger_button.text = "Saved to " + folder_lbl
			report_label.text += "\n\n[color=#1c7033][b]Na-save sa " + folder_lbl + ":[/b] " + str(res.get("html_filename", "")) + " at .csv — " + str(res["entry_count"]) + " rows[/color]"
		else:
			AudioManager.play_sfx("alert")
			export_ledger_button.text = "Download Failed"

func _on_play_again_button_pressed() -> void:
	AudioManager.play_sfx("click")
	visible = false
	play_again_requested.emit()

func _on_close_button_pressed() -> void:
	AudioManager.play_sfx("click")
	visible = false
	evaluation_closed.emit()
