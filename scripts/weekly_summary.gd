extends CanvasLayer

@onready var title = $Panel/VBoxContainer/Title
@onready var income_label = $Panel/VBoxContainer/IncomeLabel
@onready var expenses_label = $Panel/VBoxContainer/ExpensesLabel
@onready var net_label = $Panel/VBoxContainer/NetLabel
@onready var details_rtf = $Panel/VBoxContainer/DetailsRTF

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
	var week_num = int(snap.get("week_num", 1))
	var income_val = int(snap.get("income", 0))
	var expenses_val = int(snap.get("expenses", 0))
	var net = int(snap.get("net", income_val - expenses_val))
	
	title.text = "Katapusan ng Week " + str(week_num) + " — Weekly Summary & Planning"
	income_label.text = "Pumasok na Pera: + PHP " + str(income_val)
	expenses_label.text = "Mga Nagastos: - PHP " + str(expenses_val)
	
	if net >= 0:
		net_label.text = "Natira sa Pera (Net): + PHP " + str(net)
		net_label.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		net_label.text = "Natira sa Pera (Net): - PHP " + str(abs(net))
		net_label.add_theme_color_override("font_color", Color(1, 0, 0))
		
	var sav = int(snap.get("total_savings", StatManager.savings))
	var sav_delta = int(snap.get("savings_delta", 0))
	var goal_title = str(snap.get("goal_title", StatManager.get_current_goal()["title"]))
	var goal_target = int(snap.get("goal_target", StatManager.get_goal_target()))
	var goal_pct = int(snap.get("goal_percent", StatManager.get_goal_progress_percent()))
	var debt = int(snap.get("total_debt", StatManager.debt_balance))
	var debt_delta = int(snap.get("debt_delta", 0))
	var hap = int(snap.get("happy", StatManager.happy))
	var hap_delta = int(snap.get("happy_delta", 0))
	var soc = int(snap.get("social", StatManager.social))
	var soc_delta = int(snap.get("social_delta", 0))
	
	var details = "[center][b]Ipon & Life Goal (" + goal_title + "):[/b]\n"
	details += "PHP " + str(sav) + " / PHP " + str(goal_target) + " (" + str(goal_pct) + "%) " + _format_delta(sav_delta, true, false) + "\n"
	details += "[b]Kabuuang Utang (Debt):[/b] PHP " + str(debt) + " " + _format_delta(debt_delta, true, true) + "\n\n"
	details += "[b]Character Well-Being:[/b]\n"
	details += "Happiness: [b]" + str(hap) + "/100[/b] " + _format_delta(hap_delta, false, false) + " | "
	details += "Social: [b]" + str(soc) + "/100[/b] " + _format_delta(soc_delta, false, false) + "\n"
	details += "[i][color=yellow]Tip: Bago magsimula ang bagong linggo, mag-plano sa Planner o mag-allocate ng sahod sa Cash Envelopes![/color][/i][/center]"
	details_rtf.text = details
		
	visible = true

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
