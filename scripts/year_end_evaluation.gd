extends CanvasLayer

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

func show_year_end_evaluation() -> Dictionary:
	last_eval_data = StatManager.evaluate_year_end()
	
	title_label.text = str(last_eval_data["ending_title"])
	subtitle_label.text = "Year-End Victory Conditions Met: " + str(last_eval_data["conditions_met_count"]) + " / 4"
	
	var c1_badge := "[color=green]✅ PASSED[/color]" if bool(last_eval_data["goal_reached"]) else "[color=red]❌ FAILED[/color]"
	var c2_badge := "[color=green]✅ PASSED[/color]" if bool(last_eval_data["wellbeing_maintained"]) else "[color=red]❌ FAILED[/color]"
	var c3_badge := "[color=green]✅ PASSED[/color]" if bool(last_eval_data["good_credit"]) else "[color=red]❌ FAILED[/color]"
	var c4_badge := "[color=green]✅ PASSED[/color]" if bool(last_eval_data["debt_free"]) else "[color=red]❌ FAILED[/color]"
	
	var txt := "[b]1. GDD Year-End Victory Conditions Checklist:[/b]\n"
	txt += "• [b]Life Goal (\"" + str(last_eval_data["goal_title"]) + "\"):[/b] " + c1_badge + " — Ipon: PHP " + str(last_eval_data["savings"]) + " / PHP " + str(last_eval_data["goal_target"]) + "\n"
	txt += "• [b]Well-Being & Relationships (Need >=50):[/b] " + c2_badge + " — Happiness: " + str(last_eval_data["happy"]) + "/100 | Social: " + str(last_eval_data["social"]) + "/100\n"
	txt += "• [b]Good Credit Standing (Need >=70):[/b] " + c3_badge + " — Credit Score: " + str(last_eval_data["credit_score"]) + "/100\n"
	txt += "• [b]Completely Debt-Free (Need PHP 0):[/b] " + c4_badge + " — Unpaid Debt/Loans/Credit: PHP " + str(last_eval_data["total_obligations"]) + "\n\n"
	
	txt += "[b]2. Year-End Financial Literacy Report Card:[/b]\n"
	txt += "• Final Employment: " + StatManager.get_employment_display_text() + " | Remaining Pocket Cash: PHP " + str(last_eval_data["current_balance"]) + "\n"
	txt += "• Savings Compounding Interest Earned (+2%/mo): [color=green]+PHP " + str(StatManager.total_savings_interest_earned) + "[/color]\n"
	txt += "• Credit & Loan Interest Incurred: [color=orange]PHP " + str(StatManager.total_credit_interest_incurred + StatManager.total_loan_interest_incurred) + "[/color] | Net Investment P&L: [color=aqua]PHP " + str(StatManager.total_investment_gains) + "[/color]\n\n"
	
	txt += "[b]3. Narrative Outcome:[/b]\n" + str(last_eval_data["ending_summary"]) + "\n\n"
	txt += "[b][color=lightblue]💬 Mensahe ni Baldo (Financial Coach):[/color][/b]\n[i]\"" + str(last_eval_data["baldo_verdict"]) + "\"[/i]"
	
	report_label.text = txt
	visible = true
	return last_eval_data

func _on_play_again_button_pressed() -> void:
	visible = false
	play_again_requested.emit()

func _on_close_button_pressed() -> void:
	visible = false
	evaluation_closed.emit()
