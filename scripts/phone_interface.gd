extends Control

@onready var header_title: Label = $Header/Title
@onready var notifications_container = $ScrollContainer/VBoxContainer/NotificationsContainer
@onready var event_detail_panel = $EventDetailPanel
@onready var event_title = $EventDetailPanel/VBoxContainer/EventTitle
@onready var event_desc = $EventDetailPanel/VBoxContainer/EventDescription
@onready var options_container = $EventDetailPanel/VBoxContainer/OptionsContainer

@onready var chat_panel = $ChatPanel
@onready var chat_history = $ChatPanel/VBoxContainer/ChatHistory
@onready var chat_input = $ChatPanel/VBoxContainer/HBoxContainer/ChatInput
@onready var send_button = $ChatPanel/VBoxContainer/HBoxContainer/SendButton
@onready var ai_http_request = $AIHTTPRequest

@onready var loans_panel: Panel = $LoansPanel
@onready var loans_info_label: RichTextLabel = $LoansPanel/VBoxContainer/LoansInfoLabel
@onready var borrow_5k_btn: Button = $LoansPanel/VBoxContainer/Borrow5kButton
@onready var borrow_10k_btn: Button = $LoansPanel/VBoxContainer/Borrow10kButton
@onready var pay_loan_inst_btn: Button = $LoansPanel/VBoxContainer/PayLoanInstallmentButton
@onready var pay_loan_full_btn: Button = $LoansPanel/VBoxContainer/PayLoanFullButton
@onready var pay_overdue_debt_btn: Button = $LoansPanel/VBoxContainer/PayOverdueDebtButton

@onready var invest_panel: Panel = $InvestPanel
@onready var invest_info_label: RichTextLabel = $InvestPanel/VBoxContainer/InvestInfoLabel
@onready var invest_low_btn: Button = $InvestPanel/VBoxContainer/InvestLowRiskButton
@onready var invest_high_btn: Button = $InvestPanel/VBoxContainer/InvestHighRiskButton
@onready var withdraw_cash_btn: Button = $InvestPanel/VBoxContainer/WithdrawCashButton
@onready var transfer_savings_btn: Button = $InvestPanel/VBoxContainer/TransferSavingsButton

var current_viewing_event_id: String = ""
var chat_messages: Array = []
var is_request_pending: bool = false
var is_lag_waiting: bool = false

func _ready() -> void:
	EventManager.on_indirect_event_triggered.connect(_on_event_triggered)
	EventManager.on_event_resolved.connect(_on_event_resolved)
	StatManager.on_stats_changed.connect(_on_stats_updated)
	ai_http_request.request_completed.connect(_on_ai_request_completed)
	
	if chat_input and not chat_input.text_submitted.is_connected(_on_chat_input_submitted):
		chat_input.text_submitted.connect(_on_chat_input_submitted)
	
	# Initialize system prompt slot (dynamically refreshed with live context before every message)
	chat_messages.append({
		"role": "system",
		"content": _build_system_prompt()
	})
	
	add_chat_bubble("Baldo", "Yow par! Ako si Baldo, ang financial buddy mo. Tanong ka lang kung paano i-budget ang sahod mo, ano gagawin sa bills, o kung may gumugulo sa isip mo!")
	_on_stats_updated()
	refresh_notifications()

func _on_stats_updated() -> void:
	_update_header_status()
	_refresh_loans_panel()
	_refresh_invest_panel()

func _update_header_status() -> void:
	if not header_title or is_lag_waiting:
		return
	if StatManager.phone_is_slow:
		header_title.text = "Mga Text (🐢 Slow Phone - 2s Lag)"
	elif StatManager.phone_upgraded:
		header_title.text = "Mga Text (⚡ Upgraded 5G)"
	else:
		header_title.text = "Mga Text"

func _apply_phone_lag_if_needed() -> void:
	if StatManager.phone_is_slow and StatManager.phone_lag_seconds > 0.0:
		is_lag_waiting = true
		if header_title:
			header_title.text = "⏳ Loading... (Slow Phone 2s)"
		await get_tree().create_timer(StatManager.phone_lag_seconds).timeout
		is_lag_waiting = false
		_update_header_status()

func _build_system_prompt() -> String:
	var prompt = "You are Baldo, a wise, supportive, and trustworthy Filipino friend who acts as a personal financial coach for a young breadwinner working their first job in the city.\n"
	prompt += "IMPORTANT TONE RULES:\n"
	prompt += "- ALWAYS speak in a casual, warm, relatable Gen-Z Filipino 'Taglish' tone (use slang naturally like 'omsim', 'paldo', 'petsa de peligro', 'hustle', 'dasurv', 'par', 'lods').\n"
	prompt += "- Keep responses concise (3 to 5 sentences max) and actionable.\n"
	prompt += "- CRITICAL: You have LIVE access to the player's current financial stats, cash envelopes, active notifications, and past decisions below. ALWAYS tailor your advice specifically to their exact numbers, past choices, envelope shortfalls, and current situation!\n\n"
	prompt += StatManager.get_live_summary_for_ai() + "\n"
	prompt += EventManager.get_events_context_for_ai()
	return prompt

func _load_api_key() -> String:
	var env_key = OS.get_environment("OPENAI_API_KEY").strip_edges()
	if env_key != "":
		return env_key
		
	var candidate_paths = ["res://.env", "user://.env", "user://api_config.cfg"]
	for path in candidate_paths:
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				while not file.eof_reached():
					var line = file.get_line().strip_edges()
					if line.begins_with("OPENAI_API_KEY="):
						return line.substr("OPENAI_API_KEY=".length()).strip_edges().trim_prefix("\"").trim_suffix("\"")
					elif line.begins_with("sk-"):
						return line
	return ""

func _on_event_triggered(_event_data: Dictionary) -> void:
	refresh_notifications()

func _on_event_resolved(_event_id: String) -> void:
	refresh_notifications()
	event_detail_panel.hide()

func refresh_notifications() -> void:
	for child in notifications_container.get_children():
		notifications_container.remove_child(child)
		child.queue_free()
		
	for event in EventManager.active_events:
		var btn = Button.new()
		btn.text = "New Message: " + event["title"]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.pressed.connect(func(): _on_notification_clicked(event))
		notifications_container.add_child(btn)

func _on_notification_clicked(event: Dictionary) -> void:
	if is_lag_waiting:
		return
	await _apply_phone_lag_if_needed()
	open_event_detail(event)

func open_event_detail(event: Dictionary) -> void:
	current_viewing_event_id = event["id"]
	event_title.text = event["title"]
	event_desc.text = event["description"]
	
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
		
	var i = 0
	for option in event["options"]:
		var btn = Button.new()
		var choice_text = option["choice_text"]
		var can_select = EventManager.is_option_selectable(option)
		btn.custom_minimum_size = Vector2(0, 62)
		btn.disabled = not can_select
		
		var rtf = RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtf.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		var stats_text = EventManager.format_option_Preview_bbcode(option)
		rtf.text = "[center]" + choice_text + "\n[font_size=14]" + stats_text + "[/font_size][/center]"
		btn.add_child(rtf)
		btn.pressed.connect(func(idx = i): resolve_current_event(idx))
		options_container.add_child(btn)
		i += 1
		
	event_detail_panel.show()

func resolve_current_event(option_index: int) -> void:
	if current_viewing_event_id != "":
		EventManager.resolve_event(current_viewing_event_id, option_index)

func _on_event_back_button_pressed() -> void:
	event_detail_panel.hide()

func _on_baldo_button_pressed() -> void:
	if is_lag_waiting:
		return
	await _apply_phone_lag_if_needed()
	chat_panel.show()

func open_baldo_chat_direct() -> void:
	event_detail_panel.hide()
	if loans_panel:
		loans_panel.hide()
	if invest_panel:
		invest_panel.hide()
	chat_panel.show()

func _on_close_chat_button_pressed() -> void:
	chat_panel.hide()

func _on_loans_app_button_pressed() -> void:
	if is_lag_waiting:
		return
	await _apply_phone_lag_if_needed()
	_refresh_loans_panel()
	loans_panel.show()

func _on_close_loans_button_pressed() -> void:
	loans_panel.hide()

func _on_invest_app_button_pressed() -> void:
	if is_lag_waiting:
		return
	await _apply_phone_lag_if_needed()
	_refresh_invest_panel()
	invest_panel.show()

func _on_close_invest_button_pressed() -> void:
	invest_panel.hide()

func _refresh_loans_panel() -> void:
	if not loans_info_label:
		return
	var rate := StatManager.get_personal_loan_monthly_rate()
	var rate_pct := int(round(rate * 100.0))
	var can_borrow := StatManager.can_take_formal_loan()
	
	# 5k 2-month Simple Interest calculation (I = P * r * t)
	var int_5k := StatManager.calculate_simple_interest(5000, rate, 2)
	var tot_5k := 5000 + int_5k
	var mo_5k := int(ceil(float(tot_5k) / 2.0))
	var mat_5k := str(StatManager.year[(StatManager.current_month + 2) % StatManager.year.size()].month)
	
	# 10k 3-month Simple Interest calculation (I = P * r * t)
	var int_10k := StatManager.calculate_simple_interest(10000, rate, 3)
	var tot_10k := 10000 + int_10k
	var mo_10k := int(ceil(float(tot_10k) / 3.0))
	var mat_10k := str(StatManager.year[(StatManager.current_month + 3) % StatManager.year.size()].month)
	
	var txt := "[b]Credit Score:[/b] " + str(StatManager.credit_score) + "/100 | [b]Cash:[/b] PHP " + str(StatManager.current_balance) + "\n"
	txt += "[b]Simple Interest Formula (I = P × r × t):[/b] Rate = [color=yellow]" + str(rate_pct) + "%/mo[/color]\n\n"
	txt += "[b]1. QuickCash Loan:[/b] Principal: PHP 5,000 | Term: 2 Mos | Simple Interest: PHP " + str(int_5k) + " | Total: PHP " + str(tot_5k) + " | Due: PHP " + str(mo_5k) + "/mo | Maturity: " + mat_5k + "\n"
	txt += "[b]2. FlexiLoan:[/b] Principal: PHP 10,000 | Term: 3 Mos | Simple Interest: PHP " + str(int_10k) + " | Total: PHP " + str(tot_10k) + " | Due: PHP " + str(mo_10k) + "/mo | Maturity: " + mat_10k + "\n\n"
	txt += "[b]Active Loans (" + str(StatManager.active_loans.size()) + "):[/b] " + StatManager.get_loans_summary_text() + "\n"
	txt += "[b]Overdue Debt (5% Penalty/mo):[/b] [color=red]PHP " + str(StatManager.debt_balance) + "[/color]"
	loans_info_label.text = txt
	
	if borrow_5k_btn:
		borrow_5k_btn.text = "Hiram PHP 5,000 (Repay PHP " + str(tot_5k) + ", " + str(mo_5k) + "/mo)" if StatManager.credit_score >= 55 else "Locked (Need Credit Score >= 55)"
		borrow_5k_btn.disabled = not can_borrow
	if borrow_10k_btn:
		borrow_10k_btn.text = "Hiram PHP 10,000 (Repay PHP " + str(tot_10k) + ", " + str(mo_10k) + "/mo)" if StatManager.credit_score >= 55 else "Locked (Need Credit Score >= 55)"
		borrow_10k_btn.disabled = not can_borrow
		
	if StatManager.active_loans.size() > 0:
		var first_loan: Dictionary = StatManager.active_loans[0]
		var rem: int = int(first_loan.get("remaining_balance", 0))
		var due: int = min(rem, int(first_loan.get("monthly_payment", rem)))
		if pay_loan_inst_btn:
			pay_loan_inst_btn.text = "Bayaran Monthly Due: " + str(first_loan["name"]) + " (-PHP " + str(due) + ")"
			pay_loan_inst_btn.disabled = (StatManager.current_balance < due or due <= 0)
		if pay_loan_full_btn:
			pay_loan_full_btn.text = "Bayaran Buo: " + str(first_loan["name"]) + " (-PHP " + str(rem) + ", +2 CS)"
			pay_loan_full_btn.disabled = (StatManager.current_balance < rem or rem <= 0)
	else:
		if pay_loan_inst_btn:
			pay_loan_inst_btn.text = "Walang Active Loan Monthly Due"
			pay_loan_inst_btn.disabled = true
		if pay_loan_full_btn:
			pay_loan_full_btn.text = "Walang Active Loan na Babayaran"
			pay_loan_full_btn.disabled = true
			
	if pay_overdue_debt_btn:
		if StatManager.debt_balance > 0:
			var pay_amt: int = min(StatManager.current_balance, StatManager.debt_balance)
			pay_overdue_debt_btn.text = "Bayaran Overdue Debt (-PHP " + str(pay_amt) + " / PHP " + str(StatManager.debt_balance) + ")"
			pay_overdue_debt_btn.disabled = (pay_amt <= 0)
		else:
			pay_overdue_debt_btn.text = "Walang Overdue Debt (PHP 0)"
			pay_overdue_debt_btn.disabled = true

func _on_borrow_5k_pressed() -> void:
	if not StatManager.can_take_formal_loan():
		return
	var rate := StatManager.get_personal_loan_monthly_rate()
	var ln := StatManager.take_simple_interest_loan("quickcash_5k", "QuickCash 5k Loan", 5000, rate, 2)
	PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Borrowed QuickCash Loan (+PHP 5,000 Cash, Repay PHP " + str(ln["total_repayment"]) + ")")
	_refresh_loans_panel()

func _on_borrow_10k_pressed() -> void:
	if not StatManager.can_take_formal_loan():
		return
	var rate := StatManager.get_personal_loan_monthly_rate()
	var ln := StatManager.take_simple_interest_loan("flexiloan_10k", "FlexiLoan 10k", 10000, rate, 3)
	PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Borrowed FlexiLoan (+PHP 10,000 Cash, Repay PHP " + str(ln["total_repayment"]) + ")")
	_refresh_loans_panel()

func _on_pay_loan_installment_pressed() -> void:
	if StatManager.active_loans.is_empty():
		return
	var first_loan: Dictionary = StatManager.active_loans[0]
	var due: int = min(int(first_loan.get("remaining_balance", 0)), int(first_loan.get("monthly_payment", 0)))
	var paid := StatManager.pay_active_loan(0, due)
	if paid > 0:
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Paid Loan Installment (-PHP " + str(paid) + ")")
	_refresh_loans_panel()

func _on_pay_loan_full_pressed() -> void:
	if StatManager.active_loans.is_empty():
		return
	var first_loan: Dictionary = StatManager.active_loans[0]
	var rem: int = int(first_loan.get("remaining_balance", 0))
	var paid := StatManager.pay_active_loan(0, rem)
	if paid > 0:
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Paid Full Loan Balance (-PHP " + str(paid) + ", +2 Credit Score)")
	_refresh_loans_panel()

func _on_pay_overdue_debt_pressed() -> void:
	var paid := StatManager.pay_overdue_debt(StatManager.debt_balance)
	if paid > 0:
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Paid Overdue Debt (-PHP " + str(paid) + ")")
	_refresh_loans_panel()

func _refresh_invest_panel() -> void:
	if not invest_info_label:
		return
	var total_inv := StatManager.get_total_investments()
	var pnl := StatManager.total_investment_gains
	var pnl_sign := "+" if pnl >= 0 else ""
	var pnl_color := "green" if pnl >= 0 else "red"
	
	var txt := "[b]Available Cash:[/b] [color=green]PHP " + str(StatManager.current_balance) + "[/color] | [b]Ipon (Savings):[/b] [color=lightblue]PHP " + str(StatManager.savings) + "[/color]\n\n"
	txt += "[b]1. Low-Risk Mutual Fund (Steady +3% to +5%/mo):[/b]\n   Current Value: [color=aqua]PHP " + str(StatManager.low_risk_investment) + "[/color]\n"
	txt += "[b]2. High-Risk Stock Market (Volatile -15% to +25%):[/b]\n   Current Value: [color=yellow]PHP " + str(StatManager.high_risk_investment) + "[/color]\n\n"
	txt += "[b]Total Portfolio Value:[/b] PHP " + str(total_inv) + " | [b]Net P&L:[/b] [color=" + pnl_color + "]" + pnl_sign + "PHP " + str(pnl) + "[/color]\n"
	txt += "[b]Side Hustle Status:[/b] " + ("[color=green]Active (+PHP 5,000/mo)[/color]" if StatManager.has_side_income else "Inactive")
	invest_info_label.text = txt
	
	if invest_low_btn:
		invest_low_btn.disabled = (StatManager.current_balance < 3000)
	if invest_high_btn:
		invest_high_btn.disabled = (StatManager.current_balance < 3000)
	if withdraw_cash_btn:
		withdraw_cash_btn.text = "Withdraw Investments to Cash (+PHP " + str(total_inv) + ")"
		withdraw_cash_btn.disabled = (total_inv <= 0)
	if transfer_savings_btn:
		transfer_savings_btn.text = "Transfer Investments to Ipon (+PHP " + str(total_inv) + ")"
		transfer_savings_btn.disabled = (total_inv <= 0)

func _on_invest_low_risk_pressed() -> void:
	if StatManager.invest_low_risk(3000):
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Invested PHP 3,000 in Low-Risk Mutual Fund")
		_refresh_invest_panel()

func _on_invest_high_risk_pressed() -> void:
	if StatManager.invest_high_risk(3000):
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Invested PHP 3,000 in High-Risk Stock")
		_refresh_invest_panel()

func _on_withdraw_cash_pressed() -> void:
	var amt := StatManager.withdraw_investments_to_cash()
	if amt > 0:
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Withdrew Investments to Cash (+PHP " + str(amt) + ")")
		_refresh_invest_panel()

func _on_transfer_savings_pressed() -> void:
	var amt := StatManager.withdraw_investments_to_savings()
	if amt > 0:
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Transferred Investments to Savings (+PHP " + str(amt) + ")")
		_refresh_invest_panel()

func _on_chat_input_submitted(_submitted_text: String) -> void:
	_on_send_chat_button_pressed()

func _on_send_chat_button_pressed() -> void:
	if is_request_pending:
		return
	var text = chat_input.text.strip_edges()
	if text == "":
		return
		
	chat_input.text = ""
	add_chat_bubble("You", text)
	
	chat_messages.append({
		"role": "user",
		"content": text
	})
	
	send_ai_request(text)

func add_chat_bubble(sender: String, text: String) -> void:
	var color = "white"
	if sender == "Baldo":
		color = "lightblue"
	elif sender == "System":
		color = "gray"
		
	if chat_history.text != "":
		chat_history.text += "\n"
	chat_history.text += "[color=" + color + "]" + sender + ":[/color] " + text

func send_ai_request(latest_user_text: String = "") -> void:
	# Always refresh the system prompt at index 0 with the latest live StatManager & EventManager context
	if chat_messages.size() > 0:
		chat_messages[0] = {
			"role": "system",
			"content": _build_system_prompt()
		}
	
	# Keep system prompt + last 10 messages to stay well within token limits
	while chat_messages.size() > 11:
		chat_messages.remove_at(1)

	var api_key = _load_api_key()
	if api_key == "":
		var reply = _generate_offline_baldo_reply(latest_user_text)
		add_chat_bubble("Baldo", reply)
		chat_messages.append({"role": "assistant", "content": reply})
		return
		
	var url = "https://api.openai.com/v1/chat/completions"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var body = {
		"model": "gpt-4o-mini",
		"messages": chat_messages,
		"max_tokens": 250
	}
	
	is_request_pending = true
	if send_button:
		send_button.disabled = true
		
	var error = ai_http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		is_request_pending = false
		if send_button:
			send_button.disabled = false
		var fallback = _generate_offline_baldo_reply(latest_user_text)
		add_chat_bubble("Baldo", fallback)
		chat_messages.append({"role": "assistant", "content": fallback})

func _on_ai_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_request_pending = false
	if send_button:
		send_button.disabled = false
		
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response = json.get_data()
			if response is Dictionary and response.has("choices") and response["choices"].size() > 0:
				var reply = response["choices"][0]["message"]["content"]
				add_chat_bubble("Baldo", reply)
				chat_messages.append({
					"role": "assistant",
					"content": reply
				})
				return
				
	# If API call fails (offline, rate limit, or key issue), seamlessly use context-aware coaching fallback
	var last_user_msg = ""
	for i in range(chat_messages.size() - 1, -1, -1):
		if chat_messages[i].get("role") == "user":
			last_user_msg = str(chat_messages[i].get("content", ""))
			break
	var fallback_reply = _generate_offline_baldo_reply(last_user_msg)
	add_chat_bubble("Baldo", fallback_reply)
	chat_messages.append({"role": "assistant", "content": fallback_reply})

func _generate_offline_baldo_reply(_user_text: String) -> String:
	var rent_env = StatManager.get_envelope_amount("Rent")
	var util_env = StatManager.get_envelope_amount("Utilities")
	var total_util_due = StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
	var rent_short = max(0, StatManager.monthly_rent - rent_env)
	var util_short = max(0, total_util_due - util_env)
	var tips: Array[String] = []
	
	# 1. Check active unread phone events
	if EventManager.active_events.size() > 0:
		var active_ev = EventManager.active_events[0]
		tips.append("May unread message ka pa tungkol sa \"" + str(active_ev["title"]) + "\"! I-settle mo muna 'yan bago mag-Evening.")
		
	# 2. Check past decisions context & employment state
	if StatManager.employment_status == "laid_off":
		tips.append("Kapit lang par habang Laid Off (PHP 0/mo sahod)! I-prioritize mo muna ang essentials at Emergency Fund habang naghahanap ng bagong trabaho.")
	elif StatManager.employment_status == "new_stable_job":
		tips.append("Solid yung bago mong Stable Job na PHP 30,000/buwan! I-todo na natin ang pag-ipon bago matapos ang taon.")
	elif EventManager.event_history.size() > 0:
		var last_ev = EventManager.event_history[EventManager.event_history.size() - 1]
		tips.append("Naalala ko pinili mo yung \"" + str(last_ev["choice_text"]) + "\" sa \"" + str(last_ev["title"]) + "\".")
		
	# 3. Check debt, active loans, credit card, envelopes, investments, and Life Goal savings progress
	var goal = StatManager.get_current_goal()
	if StatManager.debt_balance > 0:
		tips.append("Naku par, may PHP " + str(StatManager.debt_balance) + " kang overdue utang na may 5% monthly interest at kaltas sa sahod, kaya bayaran mo na sa Utang App!")
	elif StatManager.get_total_active_loan_balance() > 0:
		tips.append("May active loan ka pa na PHP " + str(StatManager.get_total_active_loan_balance()) + " (" + StatManager.get_loans_summary_text() + "). Pwede mo 'yang bayaran sa Utang App para tumaas ang Credit Score mo!")
	elif StatManager.credit_balance > 0:
		tips.append("May PHP " + str(StatManager.credit_balance) + " kang Credit Card balance! Ihanda mo ang pambayad nang buo sa Credit Card envelope para iwas sa 5% compounding interest.")
	elif rent_short > 0 or util_short > 0:
		tips.append("Sa PHP " + str(StatManager.current_balance) + " mong hawak ngayon, magtabi ka na sa Cash Envelopes: kulang ka pa ng PHP " + str(rent_short) + " sa Upa at PHP " + str(util_short) + " sa Kuryente/Tubig/Installments/Padala bago mag-katapusan.")
	elif StatManager.get_total_investments() > 0:
		tips.append("Solid par, may PHP " + str(StatManager.get_total_investments()) + " kang Investments (Net P&L: PHP " + str(StatManager.total_investment_gains) + ") at PHP " + str(StatManager.savings) + " sa Ipon para sa \"" + str(goal["title"]) + "\"!")
	else:
		tips.append("Solid par, kumpleto na ang pambayad mo sa Upa at Utilities envelopes! Maghulog ka na sa Ipon / Savings (nasa PHP " + str(StatManager.savings) + " / PHP " + str(goal["cost"]) + " ka na para sa \"" + str(goal["title"]) + "\") o subukan ang Invest App!")
		
	# 4. Check well-being meters
	if StatManager.happy < 40 or StatManager.social < 40:
		tips.append("Pero bantayan mo rin sarili mo ha—Happiness mo ay " + str(StatManager.happy) + "/100 at Social ay " + str(StatManager.social) + "/100. 'Wag puro tipid kung ma-buburnout ka naman!")
	else:
		tips.append("Goods pa naman ang Happiness (" + str(StatManager.happy) + "/100) at Social (" + str(StatManager.social) + "/100) mo, tuloy lang ang hustle para pumaldo!")
		
	return " ".join(tips)
