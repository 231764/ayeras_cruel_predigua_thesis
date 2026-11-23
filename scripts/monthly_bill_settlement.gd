extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

signal settlement_completed

@onready var title_label: Label = $Backdrop/Panel/VBoxContainer/TitleLabel
@onready var details_label: RichTextLabel = $Backdrop/Panel/VBoxContainer/DetailsLabel
@onready var pay_cash_btn: Button = $Backdrop/Panel/VBoxContainer/ButtonsContainer/PayCashButton
@onready var pay_savings_btn: Button = $Backdrop/Panel/VBoxContainer/ButtonsContainer/PaySavingsButton
@onready var incur_debt_btn: Button = $Backdrop/Panel/VBoxContainer/ButtonsContainer/IncurDebtButton

var _month_idx: int = 0
var _day_num: int = 31
var _rent_due: int = 6000
var _util_due: int = 2000
var _rent_covered: int = 0
var _util_covered: int = 0
var _total_shortfall: int = 0
var _savings_interest: int = 0
var _debt_interest: int = 0

func _ready() -> void:
	visible = false
	_apply_visual_styles()

func _style_btn(btn: Button, bg: Color, radius: int = 8) -> void:
	UITheme.style_Button(btn, bg, radius, 4)

func _apply_visual_styles() -> void:
	UITheme.style_header_banner(title_label, UITheme.BTN_CORAL, 8, 6.0)
	_style_btn(pay_cash_btn, UITheme.BTN_SAGE, 8)
	_style_btn(pay_savings_btn, UITheme.BTN_GOLD, 8)
	_style_btn(incur_debt_btn, UITheme.BTN_CORAL, 8)

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

func setup_settlement(month_idx: int, day_num: int, rent_due: int, util_due: int, savings_interest_earned: int, debt_interest_added: int) -> void:
	_month_idx = month_idx
	_day_num = day_num
	_rent_due = rent_due
	_util_due = util_due
	_savings_interest = savings_interest_earned
	_debt_interest = debt_interest_added
	
	var rent_env: int = StatManager.get_envelope_amount("Rent")
	var util_env: int = StatManager.get_envelope_amount("Utilities")
	_rent_covered = min(rent_due, rent_env)
	_util_covered = min(util_due, util_env)
	var rent_shortfall: int = max(0, rent_due - rent_env)
	var util_shortfall: int = max(0, util_due - util_env)
	_total_shortfall = rent_shortfall + util_shortfall
	
	var month_name := str(StatManager.year[clamp(month_idx, 0, StatManager.year.size() - 1)].month)
	title_label.text = "Katapusan ng " + month_name + " — Bill Settlement"
	
	var txt := "[b]Kulang ang pondo sa iyong Cash Envelopes:[/b]\n"
	txt += "Piliin kung paano babayaran ang kulang sa bills ngayong buwan:\n\n"
	txt += "- [b]Upa (Rent):[/b] Due ₱" + UITheme.format_num(rent_due) + " | Nasa Envelope: ₱" + UITheme.format_num(rent_env) + " | [color=#a8261f]Kulang: ₱" + UITheme.format_num(rent_shortfall) + "[/color]\n"
	txt += "- [b]Kuryente at Tubig:[/b] Due ₱" + UITheme.format_num(util_due) + " | Nasa Envelope: ₱" + UITheme.format_num(util_env) + " | [color=#a8261f]Kulang: ₱" + UITheme.format_num(util_shortfall) + "[/color]\n"
	txt += "- [b]Kabuuang Kulang:[/b] [color=#94520d][b]₱" + UITheme.format_num(_total_shortfall) + "[/b][/color]\n\n"
	txt += "Hawak na Cash: [color=#1c7033][b]₱" + UITheme.format_num(StatManager.current_balance) + "[/b][/color]  |  Ipon sa Bangko: [color=#1a4b7c][b]₱" + UITheme.format_num(StatManager.savings) + "[/b][/color]"
	if _savings_interest > 0:
		txt += "\n[color=#1c7033][b]Tubo sa Ipon:[/b] +₱" + UITheme.format_num(_savings_interest) + " mula sa 0.5%/buwan (6%/yr) Digital Bank Interest ngayong buwan.[/color]"
	if _debt_interest > 0:
		txt += "\n[color=#a8261f][b]Interest sa Utang:[/b] +₱" + UITheme.format_num(_debt_interest) + " mula sa 5% penalty sa natitirang balanse.[/color]"
	details_label.text = txt
	
	# Configure option buttons based on player funds
	pay_cash_btn.text = "1. Bayaran ang Kulang gamit ang Available Cash\n-₱" + UITheme.format_num(_total_shortfall) + " Cash  •  +1 Credit Score"
	pay_cash_btn.disabled = (StatManager.current_balance < _total_shortfall)
	
	var needed_from_savings: int = max(0, _total_shortfall - StatManager.current_balance)
	pay_savings_btn.text = "2. Gamitin ang Cash + Hugutin sa Ipon (Savings)\n-₱" + UITheme.format_num(needed_from_savings) + " mula sa Bangko  •  Iwas Utang"
	pay_savings_btn.disabled = (StatManager.current_balance >= _total_shortfall) or ((StatManager.current_balance + StatManager.savings) < _total_shortfall)
	
	var unpaid_if_debt: int = max(0, _total_shortfall - StatManager.current_balance)
	if unpaid_if_debt > 0:
		incur_debt_btn.text = "3. Gamitin ang Natitirang Cash + Ilista ang Kulang bilang Utang\n+₱" + UITheme.format_num(unpaid_if_debt) + " Utang (5%/buwan)  •  -5 Credit Score"
	else:
		incur_debt_btn.text = "3. Ilista ang Kulang bilang Utang\n+₱" + UITheme.format_num(_total_shortfall) + " Utang (5%/buwan)  •  -5 Credit Score"
		
	visible = true
	AudioManager.play_sfx("bill_due")
	_animate_modal_in()

func _deduct_covered_envelopes() -> void:
	var rent_env := StatManager.get_envelope_amount("Rent")
	var util_env := StatManager.get_envelope_amount("Utilities")
	StatManager.set_envelope_amount("Rent", max(0, rent_env - _rent_covered))
	StatManager.set_envelope_amount("Utilities", max(0, util_env - _util_covered))
	StatManager.weekly_expenses += (_rent_due + _util_due)

func _on_pay_cash_pressed() -> void:
	if StatManager.current_balance < _total_shortfall:
		return
	AudioManager.play_sfx("cash_register")
	var before := LedgerManager.capture_state_snapshot()
	LedgerManager.begin_composite()
	_deduct_covered_envelopes()
	StatManager.current_balance -= _total_shortfall
	StatManager.modify_credit_score(1)
	LedgerManager.end_composite()
	
	var total_bills := _rent_due + _util_due
	LedgerManager.totals["bills_shortfall_count"] = int(LedgerManager.totals.get("bills_shortfall_count", 0)) + 1
	LedgerManager.record_decision(
		"Bills",
		"monthly_settlement",
		"Manual Bill Settlement (Paid via Cash)",
		"Covered PHP " + str(_total_shortfall) + " shortfall using Pocket Cash (Total Bills: PHP " + str(total_bills) + ", +1 CS).",
		"Pay shortfall via Available Cash (-PHP " + str(_total_shortfall) + ", +1 CS)",
		["Pull shortfall from Bank Savings", "Roll shortfall into Overdue Debt (-5 CS, 5%/mo interest)"],
		"Protected Savings (6%/yr) and Credit Score (+1 CS) by using liquid Pocket Cash to cover envelope shortfall.",
		-total_bills,
		LedgerManager.compute_deltas(before, LedgerManager.capture_state_snapshot()),
		{"settlement_mode": "cash", "shortfall": _total_shortfall, "total_bills": total_bills}
	)
	LedgerManager.autosave_ledger()
	var log_text := "Monthly Bills Settled via Cash [- PHP " + str(total_bills) + "] (+1 Credit Score)"
	if _savings_interest > 0:
		log_text += "\n[font_size=12][color=green]Savings Compounding Interest +" + str(_savings_interest) + " PHP[/color][/font_size]"
	PlannerManager.record_event(_month_idx, _day_num, log_text)
	StatManager.on_stats_changed.emit()
	visible = false
	settlement_completed.emit()

func _on_pay_savings_pressed() -> void:
	if (StatManager.current_balance + StatManager.savings) < _total_shortfall:
		return
	AudioManager.play_sfx("spend")
	var before := LedgerManager.capture_state_snapshot()
	LedgerManager.begin_composite()
	_deduct_covered_envelopes()
	var needed_from_savings: int = max(0, _total_shortfall - StatManager.current_balance)
	StatManager.current_balance = 0
	StatManager.savings = max(0, StatManager.savings - needed_from_savings)
	StatManager.sync_savings_envelope()
	LedgerManager.end_composite()
	
	var total_bills := _rent_due + _util_due
	LedgerManager.totals["bills_shortfall_count"] = int(LedgerManager.totals.get("bills_shortfall_count", 0)) + 1
	LedgerManager.record_decision(
		"Bills",
		"monthly_settlement",
		"Manual Bill Settlement (Cash + Savings)",
		"Covered PHP " + str(_total_shortfall) + " shortfall using Cash + PHP " + str(needed_from_savings) + " from Ipon/Savings.",
		"Use Cash + Withdraw PHP " + str(needed_from_savings) + " from Savings",
		["Roll shortfall into Overdue Debt (-5 CS, 5%/mo interest)"],
		"Tapped Emergency Savings to avoid 5%/mo overdue debt penalty and -5 Credit Score drop.",
		-total_bills,
		LedgerManager.compute_deltas(before, LedgerManager.capture_state_snapshot()),
		{"settlement_mode": "savings", "shortfall": _total_shortfall, "from_savings": needed_from_savings, "total_bills": total_bills}
	)
	LedgerManager.autosave_ledger()
	var log_text := "Monthly Bills Settled via Cash + Savings [- PHP " + str(total_bills) + ", Hinugot sa Ipon: PHP " + str(needed_from_savings) + "]"
	if _savings_interest > 0:
		log_text += "\n[font_size=12][color=green]Savings Compounding Interest +" + str(_savings_interest) + " PHP[/color][/font_size]"
	PlannerManager.record_event(_month_idx, _day_num, log_text)
	StatManager.on_stats_changed.emit()
	visible = false
	settlement_completed.emit()

func _on_incur_debt_pressed() -> void:
	AudioManager.play_sfx("alert")
	var before := LedgerManager.capture_state_snapshot()
	LedgerManager.begin_composite()
	_deduct_covered_envelopes()
	var cash_used: int = min(StatManager.current_balance, _total_shortfall)
	var new_debt: int = _total_shortfall - cash_used
	StatManager.current_balance -= cash_used
	StatManager.debt_balance += new_debt
	StatManager.modify_credit_score(-5)
	LedgerManager.end_composite()
	
	var total_bills := _rent_due + _util_due
	LedgerManager.totals["bills_shortfall_count"] = int(LedgerManager.totals.get("bills_shortfall_count", 0)) + 1
	LedgerManager.record_decision(
		"Bills",
		"monthly_settlement",
		"Manual Bill Settlement (Incurred Overdue Debt)",
		"Shortfall of PHP " + str(new_debt) + " rolled into Overdue Debt (-5 Credit Score, 5%/mo penalty).",
		"Roll PHP " + str(new_debt) + " into Overdue Debt (-5 CS)",
		["Pay via Cash or Savings to stay debt-free"],
		"Incurred PHP " + str(new_debt) + " overdue debt (5%/mo interest + salary garnishment risk) and -5 CS.",
		-(_rent_covered + _util_covered + cash_used),
		LedgerManager.compute_deltas(before, LedgerManager.capture_state_snapshot()),
		{"settlement_mode": "debt", "shortfall": _total_shortfall, "new_debt": new_debt, "total_bills": total_bills}
	)
	LedgerManager.autosave_ledger()
	var log_text := "Monthly Bills [- PHP " + str(total_bills) + "] (Kulang pondo, Utang +" + str(new_debt) + " PHP, -5 Credit Score)"
	if _debt_interest > 0:
		log_text += "\n[font_size=12][color=red]Debt Interest Penalty -" + str(_debt_interest) + " PHP[/color][/font_size]"
	if _savings_interest > 0:
		log_text += "\n[font_size=12][color=green]Savings Compounding Interest +" + str(_savings_interest) + " PHP[/color][/font_size]"
	PlannerManager.record_event(_month_idx, _day_num, log_text)
	StatManager.on_stats_changed.emit()
	visible = false
	settlement_completed.emit()
