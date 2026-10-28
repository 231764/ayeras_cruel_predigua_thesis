extends CanvasLayer

@onready var title = $Panel/VBoxContainer/Title
@onready var income_label = $Panel/VBoxContainer/IncomeLabel
@onready var expenses_label = $Panel/VBoxContainer/ExpensesLabel
@onready var net_label = $Panel/VBoxContainer/NetLabel
@onready var details_rtf = $Panel/VBoxContainer/DetailsRTF
@onready var weekend_header_label: Label = get_node_or_null("Panel/VBoxContainer/WeekendHeaderLabel")
@onready var rest_btn: Button = get_node_or_null("Panel/VBoxContainer/WeekendRow1/RestButton")
@onready var barkada_btn: Button = get_node_or_null("Panel/VBoxContainer/WeekendRow1/BarkadaButton")
@onready var family_btn: Button = get_node_or_null("Panel/VBoxContainer/WeekendRow2/FamilyButton")
@onready var raket_btn: Button = get_node_or_null("Panel/VBoxContainer/WeekendRow2/RaketButton")

var _current_snap: Dictionary = {}
var weekend_activity_chosen: bool = false
var last_weekend_result: Dictionary = {}

signal summary_closed
signal summary_action_requested(action_name: String)

func _ready() -> void:
	visible = false

func _format_delta(val: int, is_currency: bool = false, invert_color: bool = false) -> String:
	var prefix = "+" if val > 0 else ""
	var unit = "PHP " if is_currency else ""
	var text_val = prefix + (unit + str(val) if val >= 0 else "-" + unit + str(abs(val)))
	if val == 0:
		return "[color=gray](Walang pagbabago)[/color]"
	var is_good = (val < 0) if invert_color else (val > 0)
	var col = "green" if is_good else "red"
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

func _refresh_weekend_buttons() -> void:
	var libangan_bal := StatManager.get_envelope_amount("Entertainment")
	if weekend_header_label:
		if weekend_activity_chosen and not last_weekend_result.is_empty():
			weekend_header_label.text = "✅ " + str(last_weekend_result.get("summary_text", ""))
		else:
			weekend_header_label.text = "🌟 Weekend Activity (🎉 Libangan Envelope: PHP " + str(libangan_bal) + ") — Pumili ng Isa:"
	for btn in [rest_btn, barkada_btn, family_btn, raket_btn]:
		if btn:
			btn.disabled = weekend_activity_chosen

func _render_snapshot() -> void:
	var snap := _current_snap
	var week_num = int(snap.get("week_num", 1))
	var income_val = int(snap.get("income", 0))
	var expenses_val = int(snap.get("expenses", 0))
	var net = int(snap.get("net", income_val - expenses_val))
	
	title.text = "Katapusan ng Week " + str(week_num) + " — Weekly Summary & Weekend Choice"
	income_label.text = "Pumasok na Pera: + PHP " + str(income_val)
	expenses_label.text = "Mga Nagastos: - PHP " + str(expenses_val)
	
	if net >= 0:
		net_label.text = "Natira sa Pera (Net): + PHP " + str(net)
		net_label.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		net_label.text = "Natira sa Pera (Net): - PHP " + str(abs(net))
		net_label.add_theme_color_override("font_color", Color(1, 0, 0))
		
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
		details += "[color=lime][b]🏅 Disiplinadong Budgeter Bonus (" + str(strk) + "-Week Streak!):[/b] 100% Covered ang Pagkain & Byahe Envelopes (+2 Happy, +1 Credit Score)![/color]\n"
	else:
		var cov_d: int = int(snap.get("discipline_covered_days", 0))
		var tot_d: int = max(7, int(snap.get("discipline_total_days", 7)))
		details += "[color=orange][b]📂 Envelope Discipline:[/b] " + str(cov_d) + "/" + str(tot_d) + " days covered (Pondohan ang Pagkain & Byahe Envelopes para sa +2 Happy & +1 CS Bonus!)[/color]\n"
	details += "[b]Character Well-Being:[/b]\n"
	details += "Happiness: [b]" + str(hap) + "/100[/b] " + _format_delta(hap_delta, false, false) + " | "
	details += "Social: [b]" + str(soc) + "/100[/b] " + _format_delta(soc_delta, false, false) + "\n"
	details += "[i][color=yellow]Tip: Maglaan ng pera sa 🎉 Libangan Envelope para sa Weekend Barkada/Pamilya bonding![/color][/i][/center]"
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
