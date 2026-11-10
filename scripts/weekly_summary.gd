extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

@onready var title = $Panel/VBoxContainer/Title
@onready var income_label = get_node_or_null("Panel/VBoxContainer/StatsPanel/HBoxContainer/IncomeLabel")
@onready var expenses_label = get_node_or_null("Panel/VBoxContainer/StatsPanel/HBoxContainer/ExpensesLabel")
@onready var net_label = get_node_or_null("Panel/VBoxContainer/StatsPanel/HBoxContainer/NetLabel")
@onready var details_rtf = $Panel/VBoxContainer/DetailsRTF
@onready var weekend_header_label: Label = get_node_or_null("Panel/VBoxContainer/WeekendHeaderLabel")
@onready var rest_btn: Button = get_node_or_null("Panel/VBoxContainer/WeekendRow1/RestButton")
@onready var barkada_btn: Button = get_node_or_null("Panel/VBoxContainer/WeekendRow1/BarkadaButton")
@onready var family_btn: Button = get_node_or_null("Panel/VBoxContainer/WeekendRow2/FamilyButton")
@onready var raket_btn: Button = get_node_or_null("Panel/VBoxContainer/WeekendRow2/RaketButton")
@onready var budget_plan_btn: Button = get_node_or_null("Panel/VBoxContainer/ActionRow/BudgetPlanButton")
@onready var planner_plan_btn: Button = get_node_or_null("Panel/VBoxContainer/ActionRow/PlannerPlanButton")
@onready var continue_btn: Button = get_node_or_null("Panel/VBoxContainer/ContinueButton")

var _current_snap: Dictionary = {}
var weekend_activity_chosen: bool = false
var last_weekend_result: Dictionary = {}

signal summary_closed
signal summary_action_requested(action_name: String)

func _ready() -> void:
	visible = false
	_apply_visual_styles()

func _style_btn(btn: Button, bg: Color, radius: int = 8) -> void:
	UITheme.style_Button(btn, bg, radius, 4)

func _apply_visual_styles() -> void:
	UITheme.style_header_banner(title, UITheme.BTN_GOLD, 8, 6.0)
	_style_btn(rest_btn, UITheme.PAPER_CREAM, 8)
	_style_btn(barkada_btn, UITheme.PAPER_KRAFT, 8)
	_style_btn(family_btn, UITheme.PAPER_KRAFT, 8)
	_style_btn(raket_btn, UITheme.BTN_GOLD, 8)
	
	_style_btn(budget_plan_btn, UITheme.PAPER_CREAM, 8)
	_style_btn(planner_plan_btn, UITheme.PAPER_CREAM, 8)
	_style_btn(continue_btn, UITheme.BTN_SAGE, 8)

func _animate_modal_in() -> void:
	var panel_node: Control = get_node_or_null("Panel")
	if not panel_node:
		return
	panel_node.pivot_offset = panel_node.size * 0.5
	panel_node.scale = Vector2(0.96, 0.96)
	panel_node.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_node, "scale", Vector2.ONE, 0.16)
	tw.tween_property(panel_node, "modulate:a", 1.0, 0.16)

func _format_delta(val: int, is_currency: bool = false, invert_color: bool = false) -> String:
	var prefix = "+" if val > 0 else ""
	var unit = "PHP " if is_currency else ""
	var text_val = prefix + (unit + str(val) if val >= 0 else "-" + unit + str(abs(val)))
	if val == 0:
		return "[color=#5c4f45](Walang pagbabago)[/color]"
	var is_good = (val < 0) if invert_color else (val > 0)
	var col = "#1c7033" if is_good else "#a8261f"
	return "[color=" + col + "](" + text_val + " ngayong linggo)[/color]"

func show_summary(week_num: int) -> void:
	var snap = StatManager.snapshot_weekly_summary(week_num)
	show_summary_from_snapshot(snap)

func show_summary_with_values(week_num: int, income_val: int, expenses_val: int) -> void:
	var snap = StatManager.snapshot_weekly_summary(week_num)
	snap["income"] = income_val
	snap["expenses"] = expenses_val
	snap["net"] = income_val - expenses_val
	show_summary_from_snapshot(snap)

func show_summary_from_snapshot(snap: Dictionary) -> void:
	_current_snap = snap.duplicate(true)
	weekend_activity_chosen = false
	last_weekend_result = {}
	_render_snapshot()
	_refresh_weekend_buttons()
	visible = true
	_animate_modal_in()

func _refresh_weekend_buttons() -> void:
	var libangan_bal: int = StatManager.get_envelope_amount("Entertainment")
	if weekend_header_label:
		if weekend_activity_chosen and not last_weekend_result.is_empty():
			weekend_header_label.text = "[NAPILI NA] " + str(last_weekend_result.get("summary_text", ""))
		else:
			weekend_header_label.text = "Weekend Activity (Libangan Envelope: PHP " + str(libangan_bal) + ") — Pumili ng Isa:"
	for btn in [rest_btn, barkada_btn, family_btn, raket_btn]:
		if btn:
			btn.disabled = weekend_activity_chosen

func _render_snapshot() -> void:
	var snap := _current_snap
	var week_num = int(snap.get("week_num", 1))
	var income_val = int(snap.get("income", 0))
	var expenses_val = int(snap.get("expenses", 0))
	var net = int(snap.get("net", income_val - expenses_val))
	
	title.text = "KATAPUSAN NG WEEK " + str(week_num) + " — WEEKLY SUMMARY"
	if income_label:
		income_label.text = "Pumasok: + PHP " + str(income_val)
	if expenses_label:
		expenses_label.text = "Nagastos: - PHP " + str(expenses_val)
	
	if net_label:
		if net >= 0:
			net_label.text = "Natira (Net): + PHP " + str(net)
			net_label.add_theme_color_override("font_color", Color(0.11, 0.44, 0.20))
		else:
			net_label.text = "Natira (Net): - PHP " + str(abs(net))
			net_label.add_theme_color_override("font_color", Color(0.66, 0.15, 0.12))
		
	var sav = StatManager.savings
	var sav_delta = int(snap.get("savings_delta", 0))
	var goal_title = str(snap.get("goal_title", StatManager.get_current_goal()["title"]))
	var goal_target = int(snap.get("goal_target", StatManager.get_goal_target()))
	var goal_pct = StatManager.get_goal_progress_percent()
	var debt = StatManager.get_total_debt_and_loans()
	var debt_delta = int(snap.get("debt_delta", 0))
	var hap = StatManager.happy
	var hap_delta = int(snap.get("happy_delta", 0)) + int(last_weekend_result.get("happy_delta", 0))
	var soc = StatManager.social
	var soc_delta = int(snap.get("social_delta", 0)) + int(last_weekend_result.get("social_delta", 0))
	
	var details = "[center][b]Ipon & Life Goal (" + goal_title + "):[/b]\n"
	details += "PHP " + str(sav) + " / PHP " + str(goal_target) + " (" + str(goal_pct) + "%) " + _format_delta(sav_delta, true, false) + "\n"
	details += "[b]Kabuuang Utang (Debt):[/b] PHP " + str(debt) + " " + _format_delta(debt_delta, true, true) + "\n"
	if bool(snap.get("discipline_bonus_earned", false)):
		var strk: int = max(1, int(snap.get("discipline_streak", StatManager.envelope_discipline_streak)))
		details += "[color=#1c7033][b][DISIPLINADO BONUS - " + str(strk) + "-Week Streak]:[/b] 100% Covered ang Pagkain & Byahe Envelopes (+2 Happy, +1 Credit Score)[/color]\n"
	else:
		var cov_d: int = int(snap.get("discipline_covered_days", 0))
		var tot_d: int = max(7, int(snap.get("discipline_total_days", 7)))
		details += "[color=#94520d][b]Envelope Discipline:[/b] " + str(cov_d) + "/" + str(tot_d) + " days covered (Pondohan ang Pagkain & Byahe Envelopes para sa +2 Happy & +1 CS Bonus)[/color]\n"
	details += "[b]Character Well-Being:[/b]\n"
	details += "Happiness: [b]" + str(hap) + "/100[/b] " + _format_delta(hap_delta, false, false) + " | "
	details += "Social: [b]" + str(soc) + "/100[/b] " + _format_delta(soc_delta, false, false) + "\n"
	details += "[i][color=#5c4f45]Tip: Maglaan ng pera sa Libangan Envelope para sa Weekend Barkada o Pamilya bonding.[/color][/i][/center]"
	details_rtf.text = details

func _choose_weekend_activity(activity_id: String) -> void:
	if weekend_activity_chosen:
		return
	weekend_activity_chosen = true
	last_weekend_result = StatManager.perform_weekend_activity(activity_id)
	var cost_val := int(last_weekend_result.get("cost", 0))
	if cost_val > 0:
		_current_snap["expenses"] = int(_current_snap.get("expenses", 0)) + cost_val
	elif cost_val < 0:
		_current_snap["income"] = int(_current_snap.get("income", 0)) + abs(cost_val)
	_current_snap["net"] = int(_current_snap.get("income", 0)) - int(_current_snap.get("expenses", 0))
	_render_snapshot()
	_refresh_weekend_buttons()

func _on_weekend_rest_pressed() -> void:
	_choose_weekend_activity("rest")

func _on_weekend_barkada_pressed() -> void:
	_choose_weekend_activity("barkada")

func _on_weekend_family_pressed() -> void:
	_choose_weekend_activity("family")

func _on_weekend_raket_pressed() -> void:
	_choose_weekend_activity("raket")

func _on_budget_plan_pressed() -> void:
	visible = false
	summary_action_requested.emit("budget")
	summary_closed.emit()

func _on_planner_plan_pressed() -> void:
	visible = false
	summary_action_requested.emit("planner")
	summary_closed.emit()

func _on_continue_pressed() -> void:
	visible = false
	summary_closed.emit()
