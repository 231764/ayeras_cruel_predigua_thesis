extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

signal evaluation_closed
signal play_again_requested

@onready var title_label: Label = $Backdrop/Panel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Backdrop/Panel/VBoxContainer/SubtitleLabel
@onready var report_label: RichTextLabel = $Backdrop/Panel/VBoxContainer/ReportLabel
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
	
	txt += "[b]2. Year-End Financial Literacy Report Card:[/b]\n"
	txt += "- Final Employment: " + StatManager.get_employment_display_text() + " | Remaining Pocket Cash: PHP " + str(last_eval_data["current_balance"]) + "\n"
	txt += "- Savings Compounding Interest Earned (+2%/mo): [color=#1c7033]+PHP " + str(StatManager.total_savings_interest_earned) + "[/color]\n"
	txt += "- Credit & Loan Interest Incurred: [color=#94520d]PHP " + str(StatManager.total_credit_interest_incurred + StatManager.total_loan_interest_incurred) + "[/color] | Net Investment P&L: [color=#1a4b7c]PHP " + str(StatManager.total_investment_gains) + "[/color]\n\n"
	
	txt += "[b]3. Narrative Outcome:[/b]\n" + str(last_eval_data["ending_summary"]) + "\n\n"
	txt += "[b][color=#94520d]Mensahe ni Baldo (Financial Coach):[/color][/b]\n[i]\"" + str(last_eval_data["baldo_verdict"]) + "\"[/i]"
	
	report_label.text = txt
	visible = true
	_animate_modal_in()
	return last_eval_data

func _on_play_again_button_pressed() -> void:
	visible = false
	play_again_requested.emit()

func _on_close_button_pressed() -> void:
	visible = false
	evaluation_closed.emit()
