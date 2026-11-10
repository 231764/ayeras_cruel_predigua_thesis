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
	title_label.text = "KATAPUSAN NG " + month_name.to_upper() + " — BILL SETTLEMENT"
	
	var txt := "[b]Kulang ang pondo sa iyong Cash Envelopes (Cost Mismatch / Unallocated Budget):[/b]\n"
	txt += "Kailangan mong piliin kung paano babayaran ang kulang sa bills ngayong buwan:\n\n"
	txt += "- [b]Upa (Rent):[/b] Due: PHP " + str(rent_due) + " | Nasa Envelope: PHP " + str(rent_env) + " | [color=#a8261f]Kulang: PHP " + str(rent_shortfall) + "[/color]\n"
	txt += "- [b]Kuryente/Tubig (Utilities):[/b] Due: PHP " + str(util_due) + " | Nasa Envelope: PHP " + str(util_env) + " | [color=#a8261f]Kulang: PHP " + str(util_shortfall) + "[/color]\n"
	txt += "- [b]Kabuuang Kulang na Babayaran (Shortfall):[/b] [color=#94520d][b]PHP " + str(_total_shortfall) + "[/b][/color]\n\n"
	txt += "Hawak na Available Cash: [color=#1c7033][b]PHP " + str(StatManager.current_balance) + "[/b][/color] | Ipon sa Bangko: [color=#1a4b7c][b]PHP " + str(StatManager.savings) + "[/b][/color]"
	if _savings_interest > 0:
		txt += "\n[color=#1c7033][INTEREST] Kumita ang Ipon mo ng +PHP " + str(_savings_interest) + " (2% Compounding Interest) ngayong buwan.[/color]"
	if _debt_interest > 0:
		txt += "\n[color=#a8261f][BABALA] Nadagdagan ng +PHP " + str(_debt_interest) + " (5% Interest) ang dati mong utang.[/color]"
	details_label.text = txt
	
	# Configure option buttons based on player funds
	pay_cash_btn.text = "1. Bayaran ang Kulang gamit ang Available Cash (-PHP " + str(_total_shortfall) + ", +1 Credit Score)"
	pay_cash_btn.disabled = (StatManager.current_balance < _total_shortfall)
	
	var needed_from_savings: int = max(0, _total_shortfall - StatManager.current_balance)
	pay_savings_btn.text = "2. Gamitin ang Cash + Hugutin sa Ipon (-PHP " + str(needed_from_savings) + " mula sa Savings)"
	pay_savings_btn.disabled = (StatManager.current_balance >= _total_shortfall) or ((StatManager.current_balance + StatManager.savings) < _total_shortfall)
	
	var unpaid_if_debt: int = max(0, _total_shortfall - StatManager.current_balance)
	if unpaid_if_debt > 0:
		incur_debt_btn.text = "3. Gamitin ang natitirang Cash at ilista ang kulang na PHP " + str(unpaid_if_debt) + " bilang Utang (-5 Credit Score)"
	else:
		incur_debt_btn.text = "3. Ilista ang kulang na PHP " + str(_total_shortfall) + " bilang Utang (-5 Credit Score)"
		
	visible = true
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
	_deduct_covered_envelopes()
	StatManager.current_balance -= _total_shortfall
	StatManager.modify_credit_score(1)
	
	var total_bills := _rent_due + _util_due
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
	_deduct_covered_envelopes()
	var needed_from_savings: int = max(0, _total_shortfall - StatManager.current_balance)
	StatManager.current_balance = 0
	StatManager.savings = max(0, StatManager.savings - needed_from_savings)
	StatManager.sync_savings_envelope()
	
	var total_bills := _rent_due + _util_due
	var log_text := "Monthly Bills Settled via Cash + Savings [- PHP " + str(total_bills) + ", Hinugot sa Ipon: PHP " + str(needed_from_savings) + "]"
	if _savings_interest > 0:
		log_text += "\n[font_size=12][color=green]Savings Compounding Interest +" + str(_savings_interest) + " PHP[/color][/font_size]"
	PlannerManager.record_event(_month_idx, _day_num, log_text)
	StatManager.on_stats_changed.emit()
	visible = false
	settlement_completed.emit()

func _on_incur_debt_pressed() -> void:
	_deduct_covered_envelopes()
	var cash_used: int = min(StatManager.current_balance, _total_shortfall)
	var new_debt: int = _total_shortfall - cash_used
	StatManager.current_balance -= cash_used
	StatManager.debt_balance += new_debt
	StatManager.modify_credit_score(-5)
	
	var total_bills := _rent_due + _util_due
	var log_text := "Monthly Bills [- PHP " + str(total_bills) + "] (Kulang pondo, Utang +" + str(new_debt) + " PHP, -5 Credit Score)"
	if _debt_interest > 0:
		log_text += "\n[font_size=12][color=red]Debt Interest Penalty -" + str(_debt_interest) + " PHP[/color][/font_size]"
	if _savings_interest > 0:
		log_text += "\n[font_size=12][color=green]Savings Compounding Interest +" + str(_savings_interest) + " PHP[/color][/font_size]"
	PlannerManager.record_event(_month_idx, _day_num, log_text)
	StatManager.on_stats_changed.emit()
	visible = false
	settlement_completed.emit()
