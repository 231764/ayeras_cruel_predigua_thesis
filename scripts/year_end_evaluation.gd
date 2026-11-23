extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

signal evaluation_closed
signal play_again_requested

@onready var title_label: Label = $Backdrop/Panel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Backdrop/Panel/VBoxContainer/SubtitleLabel
@onready var report_label: RichTextLabel = $Backdrop/Panel/VBoxContainer/ReportLabel
@onready var export_ledger_button: Button = get_node_or_null("Backdrop/Panel/VBoxContainer/ButtonsRow/ExportLedgerButton")
@onready var play_again_button: Button = $Backdrop/Panel/VBoxContainer/ButtonsRow/PlayAgainButton
@onready var close_button: Button = $Backdrop/Panel/VBoxContainer/ButtonsRow/CloseButton

var last_eval_data: Dictionary = {}

func _ready() -> void:
	visible = false
	_apply_visual_styles()

func _style_btn(btn: Button, bg: Color, radius: int = 8) -> void:
	UITheme.style_Button(btn, bg, radius, 4)

func _apply_visual_styles() -> void:
	UITheme.style_header_banner(title_label, UITheme.BTN_GOLD, 8, 6.0)
	_style_btn(export_ledger_button, UITheme.BTN_BLUE, 8)
	_style_btn(play_again_button, UITheme.BTN_SAGE, 8)
	_style_btn(close_button, UITheme.PAPER_CREAM, 8)

func _animate_modal_in() -> void:
	var panel_node: Control = get_node_or_null("Backdrop/Panel")
	if not panel_node:
		return
	panel_node.pivot_offset = panel_node.size * 0.5
	panel_node.scale = Vector2(0.96, 0.96)
	panel_node.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_node, "scale", Vector2.ONE, 0.16)
	tw.tween_property(panel_node, "modulate:a", 1.0, 0.16)

func show_year_end_evaluation() -> Dictionary:
	last_eval_data = StatManager.evaluate_year_end()
	
	title_label.text = str(last_eval_data["ending_title"])
	subtitle_label.text = "Year-End Victory Conditions Met: " + str(last_eval_data["conditions_met_count"]) + " / 4"
	
	var c1_badge := "[color=#1c7033][PASADO][/color]" if bool(last_eval_data["goal_reached"]) else "[color=#a8261f][BAGSAK][/color]"
	var c2_badge := "[color=#1c7033][PASADO][/color]" if bool(last_eval_data["wellbeing_maintained"]) else "[color=#a8261f][BAGSAK][/color]"
	var c3_badge := "[color=#1c7033][PASADO][/color]" if bool(last_eval_data["good_credit"]) else "[color=#a8261f][BAGSAK][/color]"
	var c4_badge := "[color=#1c7033][PASADO][/color]" if bool(last_eval_data["debt_free"]) else "[color=#a8261f][BAGSAK][/color]"
	
	var txt := "[b]1. GDD Year-End Victory Conditions Checklist:[/b]\n"
	txt += "- [b]Life Goal (\"" + str(last_eval_data["goal_title"]) + "\"):[/b] " + c1_badge + " — Ipon: PHP " + str(last_eval_data["savings"]) + " / PHP " + str(last_eval_data["goal_target"]) + "\n"
	txt += "- [b]Well-Being & Relationships (Need >=50):[/b] " + c2_badge + " — Happiness: " + str(last_eval_data["happy"]) + "/100 | Social: " + str(last_eval_data["social"]) + "/100\n"
	txt += "- [b]Good Credit Standing (Need >=70):[/b] " + c3_badge + " — Credit Score: " + str(last_eval_data["credit_score"]) + "/100\n"
	txt += "- [b]Completely Debt-Free (Need PHP 0):[/b] " + c4_badge + " — Unpaid Debt/Loans/Credit: PHP " + str(last_eval_data["total_obligations"]) + "\n\n"
	
	var l_stats := LedgerManager.get_analytics_summary()
	txt += "[b]2. Year-End Financial Literacy & Master Ledger Summary:[/b]\n"
	txt += "- Final Employment: " + StatManager.get_employment_display_text() + " | Remaining Pocket Cash: PHP " + UITheme.format_num(int(last_eval_data["current_balance"])) + "\n"
	txt += "- Ledger Cash Flow: Inflow [color=#1c7033]+PHP " + UITheme.format_num(int(l_stats["total_inflow"])) + "[/color] | Outflow [color=#a8261f]-PHP " + UITheme.format_num(int(l_stats["total_outflow"])) + "[/color] | Net Worth: [b]PHP " + UITheme.format_num(int(l_stats["net_worth"])) + "[/b] (Savings Rate: " + str(l_stats["savings_rate_pct"]) + "%)\n"
	txt += "- Recorded History: [b]" + str(l_stats["entry_count"]) + "[/b] Ledger Records (" + str(l_stats["decisions_count"]) + " Decisions & Tradeoffs) | Badges: [color=#1a4b7c][b]" + str(l_stats["achievements_unlocked"]) + " / " + str(l_stats["achievements_total"]) + "[/b][/color]\n"
	txt += "- Savings Compounding Interest Earned (+2%/mo): [color=#1c7033]+PHP " + UITheme.format_num(StatManager.total_savings_interest_earned) + "[/color] | Credit & Loan Interest: [color=#94520d]PHP " + UITheme.format_num(StatManager.total_credit_interest_incurred + StatManager.total_loan_interest_incurred) + "[/color] | Investment P&L: [color=#1a4b7c]PHP " + UITheme.format_num(StatManager.total_investment_gains) + "[/color]\n\n"
	
	txt += "[b]3. Narrative Outcome:[/b]\n" + str(last_eval_data["ending_summary"]) + "\n\n"
	txt += "[b][color=#94520d]Mensahe ni Baldo (Financial Coach):[/color][/b]\n[i]\"" + str(last_eval_data["baldo_verdict"]) + "\"[/i]"
	
	report_label.text = txt
	if export_ledger_button:
		export_ledger_button.text = "Download Ledger"
		export_ledger_button.disabled = false
	visible = true
	_animate_modal_in()
	return last_eval_data

func _on_export_ledger_button_pressed() -> void:
	var res := LedgerManager.export_to_device_downloads()
	if export_ledger_button:
		if bool(res.get("ok", false)):
			var folder_lbl: String = str(res.get("folder_label", "Downloads"))
			export_ledger_button.text = "Saved to " + folder_lbl + "!"
			report_label.text += "\n\n[color=#1c7033][b][DOWNLOADED TO " + folder_lbl.to_upper() + "][/b] " + str(res.get("csv_filename", "")) + " & .json (" + str(res["entry_count"]) + " rows)[/color]"
		else:
			export_ledger_button.text = "Download Failed"

func _on_play_again_button_pressed() -> void:
	visible = false
	play_again_requested.emit()

func _on_close_button_pressed() -> void:
	visible = false
	evaluation_closed.emit()
