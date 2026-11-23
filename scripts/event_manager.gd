extends Node

const UITheme = preload("res://scripts/ui_theme.gd")

signal on_direct_event_triggered(event_data)
signal on_indirect_event_triggered(event_data)
signal on_event_resolved(event_id)

var event_pool = {}
var active_events = []
var current_direct_event: Dictionary = {}
var event_history: Array = []
var current_stage = 1
var is_direct_event_active: bool = false
var last_evaluated_phase_key: String = ""
var _event_texture_cache: Dictionary = {}

func _ready() -> void:
	load_events_from_json("res://data/events.json")

func reset_events() -> void:
	event_pool.clear()
	active_events.clear()
	current_direct_event = {}
	event_history.clear()
	current_stage = 1
	is_direct_event_active = false
	last_evaluated_phase_key = ""
	load_events_from_json("res://data/events.json")

func load_events_from_json(path: String) -> void:
	if not FileAccess.file_exists(path):
		print("Events JSON file not found at: ", path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK:
		var data = json.data
		if data.has("events"):
			for event in data["events"]:
				event_pool[event["id"]] = event
			print("Loaded ", event_pool.size(), " events.")
	else:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())

func trigger_event(event_id: String) -> void:
	if not event_pool.has(event_id):
		print("Event not found: ", event_id)
		return
		
	var event = event_pool[event_id]
	
	# Dynamically format credit_card_statement with live balance and minimum due
	if event_id == "credit_card_statement":
		var bal = StatManager.credit_balance
		var min_due = StatManager.get_credit_minimum_due()
		event["description"] = "Narito na ang iyong monthly Credit Card Statement!\nTotal Balance: ₱" + UITheme.format_num(bal) + "  |  Minimum Due (10%): ₱" + UITheme.format_num(min_due) + "\nKung Minimum Due lang ang babayaran mo, papatungan ng 3% interest (BSP cap) ang natitirang balanse sa katapusan."
		if event["options"].size() >= 2:
			event["options"][0]["choice_text"] = "Bayaran nang Buo (₱" + UITheme.format_num(bal) + " — 0 Interest, +3 Credit Score)"
			event["options"][1]["choice_text"] = "Bayaran lang ang Minimum Due (₱" + UITheme.format_num(min_due) + " — -2 Credit Score)"
	elif event_id == "interest_applied":
		var unpaid_base: int = StatManager.credit_balance + StatManager.debt_balance + StatManager.get_total_active_loan_balance()
		var interest_amt: int = clamp(int(round(float(max(5000, unpaid_base)) * 0.10)), 500, 1500)
		event["description"] = "Pumatong na ang interest na +₱" + UITheme.format_num(interest_amt) + " sa iyong hindi pa bayad na Credit o Utang (Balance: ₱" + UITheme.format_num(unpaid_base) + "). Lumalaki ang utang bawat buwan kapag hindi agad binabayaran."
		if event["options"].size() >= 2:
			event["options"][0]["cost"] = interest_amt
			event["options"][0]["choice_text"] = "Bayaran agad ang Interest sa Cash (₱" + UITheme.format_num(interest_amt) + " — +1 Credit Score)"
			event["options"][1]["add_interest_to_balance"] = interest_amt
			event["options"][1]["choice_text"] = "Idagdag sa utang/credit balance (+₱" + UITheme.format_num(interest_amt) + " Obligation, -3 Credit Score)"
	elif event_id == "investment_fluctuation":
		var low_bal: int = StatManager.low_risk_investment
		var high_bal: int = StatManager.high_risk_investment
		var hold_delta: int = int(round(float(low_bal) * 0.03)) + int(round(float(high_bal) * -0.10))
		var panic_delta: int = int(round(float(low_bal) * 0.02)) + int(round(float(high_bal) * -0.14))
		var h_sign: String = "+" if hold_delta >= 0 else "-"
		var p_sign: String = "+" if panic_delta >= 0 else "-"
		event["description"] = "Bumaba pansamantala ang merkado ngayong Agosto!\nPortfolio mo: Low-Risk ₱" + UITheme.format_num(low_bal) + "  •  High-Risk ₱" + UITheme.format_num(high_bal) + "\n• Kung mananatiling naka-invest: " + h_sign + "₱" + UITheme.format_num(abs(hold_delta)) + "\n• Kung mag-panic sell ngayon: " + p_sign + "₱" + UITheme.format_num(abs(panic_delta))
	elif event_id == "debt_collector_pressure":
		var total_owed: int = StatManager.get_total_debt_and_loans() + StatManager.credit_balance
		var demand_pay: int = min(5000, max(1000, total_owed))
		event["description"] = "Tumatawag na ang pinagkakautangan mo! Kabuuang Utang at Credit: ₱" + UITheme.format_num(total_owed) + ".\nMagbayad ng ₱" + UITheme.format_num(demand_pay) + " ngayon upang maiwasan ang stress at pagbagsak ng Credit Score."
		if event["options"].size() >= 1:
			event["options"][0]["pay_debt_collector"] = demand_pay
			event["options"][0]["choice_text"] = "Bayaran agad ang ₱" + UITheme.format_num(demand_pay) + " sa utang at credit"
	elif event_id == "final_goal_opportunity":
		var g := StatManager.get_current_goal()
		var rem_goal: int = max(0, StatManager.get_goal_target() - StatManager.savings)
		var inv_tot: int = StatManager.get_total_investments()
		var ob_tot: int = StatManager.get_total_debt_and_loans() + StatManager.credit_balance
		event["description"] = "Disyembre na — huling buwan na ng taon!\n• " + str(g["title"]) + ": ₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(int(g["cost"])) + " — Kulang: ₱" + UITheme.format_num(rem_goal) + "\n• Investments: ₱" + UITheme.format_num(inv_tot) + "  •  Utang at Credit: ₱" + UITheme.format_num(ob_tot) + "\nI-consolidate na ang pera mo bago mag-December 31!"
	
	# If it's an indirect event, add it to active events
	if not event["is_direct"]:
		if not active_events.has(event):
			active_events.append(event)
		emit_signal("on_indirect_event_triggered", event)
	else:
		# Direct events pause progression and force an immediate choice
		is_direct_event_active = true
		current_direct_event = event
		emit_signal("on_direct_event_triggered", event)

func get_event_image_path(event_id: String) -> String:
	return "res://assets/event_images/" + event_id + ".png"

func get_event_texture(event_id: String) -> Texture2D:
	if event_id == "":
		return null
	if _event_texture_cache.has(event_id):
		return _event_texture_cache[event_id] as Texture2D
	var res_path := get_event_image_path(event_id)
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = ResourceLoader.load(res_path) as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	if tex != null:
		_event_texture_cache[event_id] = tex
	return tex

func get_event_category_meta(event_data: Dictionary) -> Dictionary:
	var eid := str(event_data.get("id", "")).to_lower()
	var title_low := str(event_data.get("title", "")).to_lower()
	if "credit" in eid or "loan" in eid or "debt" in eid or "interest" in eid or "emergency_fund" in eid:
		return {"label": "Bangko at Credit", "color": UITheme.BTN_BLUE, "icon_path": "res://assets/creditcard.png"}
	if "health" in eid or "medical" in eid or "hospitalized" in eid or "condition_worsens" in eid or "ospital" in title_low or "operasyon" in title_low:
		return {"label": "Kalusugan", "color": UITheme.BTN_CORAL, "icon_path": "res://assets/sad40.png"}
	if "family" in eid or "sibling" in eid or "housing" in eid or "refrigerator" in eid or "social" in eid or "pamilya" in title_low:
		return {"label": "Pamilya at Bahay", "color": UITheme.BTN_GOLD, "icon_path": "res://assets/social.png"}
	if "salary" in eid or "job" in eid or "side_income" in eid or "sideline" in eid or "layoff" in eid or "lifestyle_adjustment" in eid:
		return {"label": "Trabaho at Kita", "color": UITheme.BTN_SAGE, "icon_path": "res://assets/cashonhand.png"}
	if "invest" in eid or "market" in eid or "final_goal" in eid:
		return {"label": "Investment at Goal", "color": UITheme.BTN_BLUE, "icon_path": "res://assets/bank.png"}
	return {"label": "Gastos at Routine", "color": UITheme.PAPER_KRAFT, "icon_path": "res://assets/budget.png"}

func format_option_Preview_bbcode(opt: Dictionary) -> String:
	var stats_text := ""
	var cost: int = int(opt.get("cost", 0))
	var credit_cost: int = int(opt.get("credit_cost", 0))
	
	if cost > 0:
		stats_text += "[color=#a8261f]-₱" + UITheme.format_num(cost) + "[/color] "
	elif cost < 0:
		stats_text += "[color=#1c7033]+₱" + UITheme.format_num(abs(cost)) + "[/color] "
		
	if credit_cost > 0:
		var can_use_cc := StatManager.can_use_credit_card(credit_cost)
		if opt.get("unlock_credit_card", false):
			var new_lim: int = max(StatManager.credit_limit, int(opt.get("credit_limit", 20000)))
			can_use_cc = (StatManager.credit_balance + credit_cost) <= new_lim
		if can_use_cc:
			stats_text += "[color=#1a4b7c]+₱" + UITheme.format_num(credit_cost) + " Credit[/color] "
		else:
			stats_text += "[color=#5c4f45]₱" + UITheme.format_num(credit_cost) + " (No Credit/Limit)[/color] "
	if opt.has("debt_change") and int(opt["debt_change"]) > 0:
		stats_text += "[color=#a8261f]+₱" + UITheme.format_num(int(opt["debt_change"])) + " Utang[/color] "
			
	if opt.get("pay_credit_full", false):
		stats_text += "[color=#a8261f]-₱" + UITheme.format_num(StatManager.credit_balance) + " (Full Bill)[/color] "
	elif opt.get("pay_credit_minimum", false):
		stats_text += "[color=#94520d]-₱" + UITheme.format_num(StatManager.get_credit_minimum_due()) + " (Min Due)[/color] "
		
	if opt.has("add_interest_to_balance") and int(opt["add_interest_to_balance"]) > 0:
		stats_text += "[color=#a8261f]+₱" + UITheme.format_num(int(opt["add_interest_to_balance"])) + " Obligation[/color] "
		
	if opt.has("take_loan") and opt["take_loan"] is Dictionary:
		var ln: Dictionary = opt["take_loan"]
		var p: int = int(ln.get("principal", 5000))
		var r: float = float(ln.get("monthly_rate", 0.20))
		var t: int = int(ln.get("term_months", 2))
		var tot_due: int = p + StatManager.calculate_simple_interest(p, r, t)
		stats_text += "[color=#94520d]+₱" + UITheme.format_num(p) + " Cash (Repay ₱" + UITheme.format_num(tot_due) + ")[/color] "
		
	if opt.has("invest_low_risk") and int(opt["invest_low_risk"]) > 0:
		stats_text += "[color=#1a4b7c]Invest ₱" + UITheme.format_num(int(opt["invest_low_risk"])) + " (Low-Risk)[/color] "
	if opt.has("invest_high_risk") and int(opt["invest_high_risk"]) > 0:
		stats_text += "[color=#94520d]Invest ₱" + UITheme.format_num(int(opt["invest_high_risk"])) + " (High-Risk)[/color] "
	if opt.has("deposit_to_savings") and int(opt["deposit_to_savings"]) > 0:
		stats_text += "[color=#1c7033]+₱" + UITheme.format_num(int(opt["deposit_to_savings"])) + " Savings[/color] "
	if opt.has("savings_bonus") and int(opt["savings_bonus"]) > 0:
		stats_text += "[color=#1c7033]+₱" + UITheme.format_num(int(opt["savings_bonus"])) + " Cashback sa Ipon[/color] "
	if opt.get("set_side_income", false):
		stats_text += "[color=#1c7033]+₱5,000/mo Side Hustle[/color] "
	if opt.has("monthly_family_support_mod") and int(opt["monthly_family_support_mod"]) > 0:
		stats_text += "[color=#94520d]+₱" + UITheme.format_num(int(opt["monthly_family_support_mod"])) + "/mo Family Bill[/color] "
	if opt.has("apply_investment_rates") and opt["apply_investment_rates"] is Dictionary:
		var rates: Dictionary = opt["apply_investment_rates"]
		var lr: int = int(round(float(rates.get("low_rate", 0.0)) * 100.0))
		var hr: int = int(round(float(rates.get("high_rate", 0.0)) * 100.0))
		var hr_sign: String = "+" if hr >= 0 else ""
		stats_text += "[color=#1a4b7c]Low-Risk +" + str(lr) + "% / High-Risk " + hr_sign + str(hr) + "%[/color] "
	if opt.get("liquidate_investments_to_cash", false):
		stats_text += "[color=#94520d]Withdraw to Cash[/color] "
	elif opt.get("liquidate_investments_to_savings", false):
		stats_text += "[color=#1c7033]Lock Gains to Ipon[/color] "
		
	if opt.has("set_employment_status"):
		var emp_st := str(opt["set_employment_status"])
		if emp_st == "laid_off":
			stats_text += "[color=#a8261f]Laid Off (₱0/mo)[/color] "
		elif emp_st == "temporary_job":
			stats_text += "[color=#94520d]Temp Job (₱15,000/mo)[/color] "
		elif emp_st == "new_stable_job":
			stats_text += "[color=#1c7033]Stable Job (₱30,000/mo)[/color] "
	if opt.has("withdraw_from_savings_for_event") and int(opt["withdraw_from_savings_for_event"]) > 0:
		stats_text += "[color=#94520d]-₱" + UITheme.format_num(int(opt["withdraw_from_savings_for_event"])) + " from Savings[/color] "
	if opt.has("pay_debt_collector") and int(opt["pay_debt_collector"]) > 0:
		stats_text += "[color=#1c7033]-₱" + UITheme.format_num(int(opt["pay_debt_collector"])) + " Debt/Credit[/color] "
	if opt.has("set_monthly_rent") and int(opt["set_monthly_rent"]) > 0:
		stats_text += "[color=#1a4b7c]Rent = ₱" + UITheme.format_num(int(opt["set_monthly_rent"])) + "/mo[/color] "
	if opt.has("final_goal_consolidate") and int(opt["final_goal_consolidate"]) > 0:
		stats_text += "[color=#1c7033]Consolidate + Save ₱" + UITheme.format_num(int(opt["final_goal_consolidate"])) + "[/color] "
		
	if opt.has("installment") and opt["installment"] is Dictionary:
		var inst: Dictionary = opt["installment"]
		stats_text += "[color=#94520d]₱" + UITheme.format_num(int(inst.get("monthly_cost", 0))) + "/mo x " + str(int(inst.get("months_left", 0))) + " mos[/color] "
		
	if opt.has("extra_utilities") and int(opt["extra_utilities"]) != 0:
		var eu_val := int(opt["extra_utilities"])
		if eu_val > 0:
			stats_text += "[color=#94520d]+₱" + UITheme.format_num(eu_val) + " Bill[/color] "
		else:
			stats_text += "[color=#1c7033]-₱" + UITheme.format_num(abs(eu_val)) + " Bill Rebate[/color] "
	if opt.has("daily_commute_mod") and int(opt["daily_commute_mod"]) != 0:
		var dc_val := int(opt["daily_commute_mod"])
		var dc_sign := "-" if dc_val < 0 else "+"
		stats_text += "[color=#94520d]" + dc_sign + "₱" + UITheme.format_num(abs(dc_val)) + "/day Commute[/color] "
	if opt.has("daily_food_mod") and int(opt["daily_food_mod"]) != 0:
		var df_val := int(opt["daily_food_mod"])
		var df_sign := "-" if df_val < 0 else "+"
		stats_text += "[color=#94520d]" + df_sign + "₱" + UITheme.format_num(abs(df_val)) + "/day Food[/color] "
		
	var happy_val: int = int(opt.get("happy_change", 0))
	if happy_val != 0:
		var sign_str = "+" if happy_val > 0 else ""
		var color = "#1c7033" if happy_val > 0 else "#a8261f"
		stats_text += "[color=" + color + "]" + sign_str + str(happy_val) + " Happy[/color] "
		
	var social_val: int = int(opt.get("social_change", 0))
	if social_val != 0:
		var sign_str = "+" if social_val > 0 else ""
		var color = "#1c7033" if social_val > 0 else "#a8261f"
		stats_text += "[color=" + color + "]" + sign_str + str(social_val) + " Social[/color] "
		
	var cs_val: int = int(opt.get("credit_score_change", 0))
	if cs_val != 0:
		var sign_str = "+" if cs_val > 0 else ""
		var color = "#1c7033" if cs_val > 0 else "#a8261f"
		stats_text += "[color=" + color + "]" + sign_str + str(cs_val) + " Credit Score[/color] "
		
	if not is_option_selectable(opt) and not ("No Credit/Limit" in stats_text):
		if opt.has("withdraw_from_savings_for_event") and StatManager.savings < int(opt["withdraw_from_savings_for_event"]):
			stats_text += "[color=#a8261f](Kulang Ipon)[/color] "
		else:
			stats_text += "[color=#a8261f](Kulang Cash)[/color] "
		
	return stats_text

func is_option_selectable(opt: Dictionary) -> bool:
	if opt.has("credit_cost") and int(opt["credit_cost"]) > 0:
		if opt.get("unlock_credit_card", false):
			var new_lim: int = max(StatManager.credit_limit, int(opt.get("credit_limit", 20000)))
			if (StatManager.credit_balance + int(opt["credit_cost"])) > new_lim:
				return false
		elif not StatManager.can_use_credit_card(int(opt["credit_cost"])):
			return false
	var cost_val: int = int(opt.get("cost", 0))
	if opt.has("deposit_to_savings") and int(opt["deposit_to_savings"]) > 0:
		if (StatManager.current_balance - cost_val) < int(opt["deposit_to_savings"]):
			return false
	if opt.has("invest_low_risk") and int(opt["invest_low_risk"]) > 0:
		if StatManager.current_balance < int(opt["invest_low_risk"]):
			return false
	if opt.has("invest_high_risk") and int(opt["invest_high_risk"]) > 0:
		if StatManager.current_balance < int(opt["invest_high_risk"]):
			return false
	if opt.has("withdraw_from_savings_for_event") and int(opt["withdraw_from_savings_for_event"]) > 0:
		if StatManager.savings < int(opt["withdraw_from_savings_for_event"]):
			return false
	if opt.has("pay_debt_collector") and int(opt["pay_debt_collector"]) > 0:
		if StatManager.current_balance < int(opt["pay_debt_collector"]):
			return false
	if opt.get("pay_credit_full", false):
		if (StatManager.current_balance + StatManager.get_envelope_amount("Credit Card")) < StatManager.credit_balance:
			return false
	if opt.get("pay_credit_minimum", false):
		if (StatManager.current_balance + StatManager.get_envelope_amount("Credit Card")) < StatManager.get_credit_minimum_due():
			return false
	return true

func resolve_event(event_id: String, option_index: int) -> void:
	if not event_pool.has(event_id):
		return
		
	var event = event_pool[event_id]
	var options = event["options"]
	
	if option_index < 0 or option_index >= options.size():
		return
		
	var chosen_option = options[option_index]
	if not is_option_selectable(chosen_option):
		print("Option requires unlocked Credit Card and available credit limit!")
		return
		
	var before_snap := LedgerManager.capture_state_snapshot()
	LedgerManager.begin_composite()
	
	var cost: int = int(chosen_option.get("cost", 0))
	var credit_cost: int = int(chosen_option.get("credit_cost", 0))
	var happy_delta: int = int(chosen_option.get("happy_change", 0))
	var social_delta: int = int(chosen_option.get("social_change", 0))
	var cs_delta: int = int(chosen_option.get("credit_score_change", 0))
	var paid_credit_amount: int = 0
	
	# 1. Apply Credit Card unlock/upgrade FIRST (in case option also charges credit_cost)
	if chosen_option.has("unlock_credit_card"):
		if bool(chosen_option["unlock_credit_card"]):
			StatManager.unlock_credit_card(int(chosen_option.get("credit_limit", 20000)))
			
	# 2. Apply cash/category cost
	if cost != 0:
		var cat: String = str(chosen_option.get("category", ""))
		if cat != "" and cost > 0:
			StatManager.spend_from_category(cat, cost)
		else:
			StatManager.spend_direct(cost)
			
	# 3. Apply Credit Card purchase or Hospital/Emergency Promissory debt
	if credit_cost > 0:
		StatManager.charge_credit_card(credit_cost)
	if chosen_option.has("debt_change") and int(chosen_option["debt_change"]) != 0:
		StatManager.debt_balance = max(0, StatManager.debt_balance + int(chosen_option["debt_change"]))
		
	# 4. Apply Credit Card statement payments
	if chosen_option.get("pay_credit_full", false):
		paid_credit_amount = StatManager.pay_credit_card_balance(StatManager.credit_balance)
	elif chosen_option.get("pay_credit_minimum", false):
		paid_credit_amount = StatManager.pay_credit_card_balance(StatManager.get_credit_minimum_due())
		
	# 5. Apply Stage 3 Interest & Delayed Health & Simple Interest Loan (5-6)
	if chosen_option.has("add_interest_to_balance") and int(chosen_option["add_interest_to_balance"]) > 0:
		var add_int: int = int(chosen_option["add_interest_to_balance"])
		if StatManager.has_credit_card and StatManager.credit_balance > 0:
			StatManager.credit_balance += add_int
			StatManager.total_credit_interest_incurred += add_int
		else:
			StatManager.debt_balance += add_int
			
	if chosen_option.has("set_health_delayed"):
		StatManager.health_issue_delayed = bool(chosen_option["set_health_delayed"])
		
	if chosen_option.has("take_loan") and chosen_option["take_loan"] is Dictionary:
		var ln: Dictionary = chosen_option["take_loan"]
		StatManager.take_simple_interest_loan(
			str(ln.get("id", event_id)),
			str(ln.get("name", event["title"])),
			int(ln.get("principal", 5000)),
			float(ln.get("monthly_rate", 0.20)),
			int(ln.get("term_months", 2))
		)
		
	# 6. Apply Stage 4 Side Hustle, Investments, Emergency Fund & Family Pressure
	if chosen_option.has("set_side_income"):
		StatManager.has_side_income = bool(chosen_option["set_side_income"])
		
	if chosen_option.has("invest_low_risk") and int(chosen_option["invest_low_risk"]) > 0:
		StatManager.invest_low_risk(int(chosen_option["invest_low_risk"]), true)
		cost += int(chosen_option["invest_low_risk"])
	if chosen_option.has("invest_high_risk") and int(chosen_option["invest_high_risk"]) > 0:
		StatManager.invest_high_risk(int(chosen_option["invest_high_risk"]), true)
		cost += int(chosen_option["invest_high_risk"])
		
	if chosen_option.has("deposit_to_savings") and int(chosen_option["deposit_to_savings"]) > 0:
		var save_amt: int = int(chosen_option["deposit_to_savings"])
		if not StatManager.deposit_savings(save_amt):
			StatManager.spend_direct(save_amt)
			StatManager.savings += save_amt
			StatManager.sync_savings_envelope()
		cost += save_amt
		
	if chosen_option.has("savings_bonus") and int(chosen_option["savings_bonus"]) > 0:
		var sb_amt: int = int(chosen_option["savings_bonus"])
		StatManager.savings += sb_amt
		StatManager.month_deposited_savings += sb_amt
		StatManager.sync_savings_envelope()
		
	if chosen_option.has("apply_investment_rates") and chosen_option["apply_investment_rates"] is Dictionary:
		var rates: Dictionary = chosen_option["apply_investment_rates"]
		StatManager.apply_investment_fluctuation(
			float(rates.get("low_rate", 0.04)),
			float(rates.get("high_rate", 0.15))
		)
	if chosen_option.get("liquidate_investments_to_cash", false):
		StatManager.withdraw_investments_to_cash()
	elif chosen_option.get("liquidate_investments_to_savings", false):
		StatManager.withdraw_investments_to_savings()
		
	if chosen_option.has("monthly_family_support_mod"):
		StatManager.monthly_family_support += int(chosen_option["monthly_family_support_mod"])
		
	# 6b. Apply Stage 5 Mastery Mechanics (Employment State, Emergency Savings Withdrawal, Debt Collector, Rent, Consolidation)
	if chosen_option.has("set_employment_status"):
		StatManager.set_employment_status(str(chosen_option["set_employment_status"]))
		
	if chosen_option.has("withdraw_from_savings_for_event") and int(chosen_option["withdraw_from_savings_for_event"]) > 0:
		var w_amt: int = int(chosen_option["withdraw_from_savings_for_event"])
		var from_sav: int = min(StatManager.savings, w_amt)
		StatManager.savings -= from_sav
		StatManager.sync_savings_envelope()
		var rem_after_sav: int = w_amt - from_sav
		if rem_after_sav > 0:
			StatManager.spend_direct(rem_after_sav)
		else:
			StatManager.weekly_expenses += from_sav
		cost += w_amt
		
	if chosen_option.has("pay_debt_collector") and int(chosen_option["pay_debt_collector"]) > 0:
		var pay_rem: int = int(chosen_option["pay_debt_collector"])
		StatManager.spend_direct(pay_rem)
		if StatManager.debt_balance > 0 and pay_rem > 0:
			var d_pay: int = min(StatManager.debt_balance, pay_rem)
			StatManager.debt_balance -= d_pay
			pay_rem -= d_pay
		while StatManager.active_loans.size() > 0 and pay_rem > 0:
			var l_rem: int = int(StatManager.active_loans[0].get("remaining_balance", 0))
			var l_pay: int = min(l_rem, pay_rem)
			StatManager.active_loans[0]["remaining_balance"] = l_rem - l_pay
			if int(StatManager.active_loans[0]["remaining_balance"]) <= 0:
				StatManager.active_loans.remove_at(0)
			pay_rem -= l_pay
		if StatManager.credit_balance > 0 and pay_rem > 0:
			var c_pay: int = min(StatManager.credit_balance, pay_rem)
			StatManager.credit_balance -= c_pay
			pay_rem -= c_pay
		cost += int(chosen_option["pay_debt_collector"])
		
	if chosen_option.has("set_monthly_rent") and int(chosen_option["set_monthly_rent"]) > 0:
		StatManager.monthly_rent = int(chosen_option["set_monthly_rent"])
		
	if chosen_option.has("final_goal_consolidate") and int(chosen_option["final_goal_consolidate"]) > 0:
		var target_save_add: int = int(chosen_option["final_goal_consolidate"])
		StatManager.withdraw_investments_to_savings()
		if StatManager.debt_balance > 0 and StatManager.current_balance > 0:
			StatManager.pay_overdue_debt(StatManager.debt_balance)
		while StatManager.active_loans.size() > 0 and StatManager.current_balance > 0:
			var paid_l := StatManager.pay_active_loan(0, StatManager.get_total_active_loan_balance())
			if paid_l <= 0:
				break
		if StatManager.credit_balance > 0 and StatManager.current_balance > 0:
			StatManager.pay_credit_card_balance(min(StatManager.current_balance, StatManager.credit_balance))
		var actual_save_add: int = min(target_save_add, StatManager.current_balance)
		if actual_save_add > 0:
			StatManager.deposit_savings(actual_save_add)
			cost += actual_save_add
			
	# 7. Apply Phone Slow / Upgraded flags
	if chosen_option.get("set_phone_slow", false):
		StatManager.phone_is_slow = true
		StatManager.phone_upgraded = false
	if chosen_option.get("set_phone_upgraded", false):
		StatManager.phone_is_slow = false
		StatManager.phone_upgraded = true
		
	# 8. Apply Installment plan if present
	if chosen_option.has("installment") and chosen_option["installment"] is Dictionary:
		var inst: Dictionary = chosen_option["installment"]
		StatManager.add_installment(
			str(inst.get("id", event_id)),
			str(inst.get("name", event["title"])),
			int(inst.get("monthly_cost", 0)),
			int(inst.get("months_left", 1))
		)
			
	# 9. Apply extra monthly bill & daily routine modifiers
	if chosen_option.has("extra_utilities"):
		StatManager.extra_utilities_this_month += int(chosen_option["extra_utilities"])
	if chosen_option.has("daily_commute_mod"):
		StatManager.daily_commute_modifier += int(chosen_option["daily_commute_mod"])
	if chosen_option.has("daily_food_mod"):
		StatManager.daily_food_modifier += int(chosen_option["daily_food_mod"])
	if chosen_option.has("set_daily_food"):
		StatManager.daily_food_choice = int(chosen_option["set_daily_food"])
	if chosen_option.has("set_daily_commute"):
		StatManager.daily_commute_choice = int(chosen_option["set_daily_commute"])
		
	# 10. Apply clamped stat changes
	if happy_delta != 0:
		StatManager.modify_happy(happy_delta)
	if social_delta != 0:
		StatManager.modify_social(social_delta)
	if cs_delta != 0:
		StatManager.modify_credit_score(cs_delta)
		
	LedgerManager.end_composite()
	StatManager.on_stats_changed.emit()
		
	# Check if it was an active indirect event and remove it
	if event in active_events:
		active_events.erase(event)
		
	if event["is_direct"]:
		is_direct_event_active = false
		current_direct_event = {}
		
	var month_name = StatManager.year[StatManager.current_month].month
	var phase_names = ["Morning", "Afternoon", "Evening"]
	var phase_name = phase_names[StatManager.current_phase]
	var title = event["title"]
	var choice_text = chosen_option["choice_text"]
	
	# Record structured Decision + Transaction + Tradeoff in Master Ledger
	var after_snap := LedgerManager.capture_state_snapshot()
	var exact_deltas := LedgerManager.compute_deltas(before_snap, after_snap)
	var alts: Array = []
	for opt_i in range(options.size()):
		if opt_i != option_index:
			alts.append(str(options[opt_i].get("choice_text", "")))
	if chosen_option.get("pay_credit_full", false):
		LedgerManager.totals["credit_paid_full_count"] = int(LedgerManager.totals.get("credit_paid_full_count", 0)) + 1
	elif chosen_option.get("pay_credit_minimum", false):
		LedgerManager.totals["credit_paid_min_count"] = int(LedgerManager.totals.get("credit_paid_min_count", 0)) + 1
	var net_cash_impact: int = -(cost + paid_credit_amount)
	if chosen_option.has("take_loan") and chosen_option["take_loan"] is Dictionary:
		net_cash_impact += int(chosen_option["take_loan"].get("principal", 0))
	var opp_parts: Array[String] = []
	if net_cash_impact != 0:
		opp_parts.append(("Gained +PHP " + str(net_cash_impact)) if net_cash_impact > 0 else ("Spent -PHP " + str(abs(net_cash_impact))))
	if credit_cost > 0:
		opp_parts.append("Charged +PHP " + str(credit_cost) + " Credit")
	if chosen_option.has("debt_change") and int(chosen_option["debt_change"]) > 0:
		opp_parts.append("+PHP " + str(int(chosen_option["debt_change"])) + " Utang")
	if happy_delta != 0:
		opp_parts.append((("+" if happy_delta > 0 else "") + str(happy_delta) + " Happy"))
	if social_delta != 0:
		opp_parts.append((("+" if social_delta > 0 else "") + str(social_delta) + " Social"))
	if cs_delta != 0:
		opp_parts.append((("+" if cs_delta > 0 else "") + str(cs_delta) + " CS"))
	var opp_note: String = "Chose \"" + choice_text + "\"" + (" (" + ", ".join(opp_parts) + ")" if not opp_parts.is_empty() else "")
	if not alts.is_empty():
		opp_note += " over " + str(alts.size()) + " alternative(s)."
	LedgerManager.record_decision(
		"Event",
		"event_manager",
		str(title),
		"Selected: " + str(choice_text),
		str(choice_text),
		alts,
		opp_note,
		net_cash_impact,
		exact_deltas,
		{
			"event_id": event_id,
			"is_direct": bool(event.get("is_direct", false)),
			"option_index": option_index,
			"credit_cost": credit_cost
		}
	)
	
	# Record structured history for Baldo AI context
	event_history.append({
		"month_index": StatManager.current_month,
		"month": month_name,
		"day": StatManager.current_day,
		"phase": phase_name,
		"event_id": event_id,
		"title": title,
		"choice_text": choice_text,
		"cost": cost + paid_credit_amount,
		"credit_cost": credit_cost,
		"happy_change": happy_delta,
		"social_change": social_delta,
		"credit_score_change": cs_delta
	})
	
	# Surface an immediate financial literacy micro-lesson on Baldo's desk card
	if chosen_option.get("pay_credit_full", false):
		StatManager.set_baldo_lesson("Credit Card", "Paid full! Umiwas ka sa 3% monthly interest (BSP cap) at tumaas ang Credit Score mo.")
	elif chosen_option.get("pay_credit_minimum", false):
		StatManager.set_baldo_lesson("Credit Trap", "Minimum payment only leaves the remaining balance earning 3%/mo interest.")
	elif chosen_option.has("take_loan"):
		StatManager.set_baldo_lesson("Loans (I = P*r*t)", "Instant cash carries simple interest -- mag-tabi agad para sa monthly due.")
	elif int(chosen_option.get("invest_high_risk", 0)) > 0:
		StatManager.set_baldo_lesson("High-Risk Investing", "Stocks swing -12% to +22%. Safe lang ito kung kumpleto ang Emergency Cash.")
	elif int(chosen_option.get("invest_low_risk", 0)) > 0:
		StatManager.set_baldo_lesson("Mutual Funds", "Steady +1.5% to +2.5%/mo beats Digital Bank savings while keeping risk low.")
	elif int(chosen_option.get("deposit_to_savings", 0)) > 0 or int(chosen_option.get("savings_bonus", 0)) > 0:
		StatManager.set_baldo_lesson("Compound Ipon", "Digital Bank Ipon earns 0.5%/mo (6% p.a.) automatically -- patuloy lang!")
	elif cost >= 1500:
		StatManager.set_baldo_lesson("Tradeoff Check", "Malaking ₱" + UITheme.format_num(cost) + " gastos -- Need ba ito o Want, at kumusta ang Goal?")
	elif cost < 0:
		StatManager.set_baldo_lesson("Pay Yourself First", "Extra ₱" + UITheme.format_num(abs(cost)) + " cash! Mag-tabi ng 20%+ sa Ipon bago magastos.")
	StatManager.check_goal_milestones()
	StatManager.check_monthly_mission_completion()
	
	emit_signal("on_event_resolved", event_id)
	print("Event Resolved: ", event_id, " | Option: ", choice_text)
	
	var tradeoff_str = format_option_Preview_bbcode(chosen_option)
	var log_text = title + " (" + choice_text + ")"
	if tradeoff_str != "":
		log_text += "\n[font_size=12]" + tradeoff_str + "[/font_size]"
	PlannerManager.record_event(StatManager.current_month, StatManager.current_day, log_text)
	
	# If there's a follow-up event
	if chosen_option.has("next_event_id") and chosen_option["next_event_id"] != "":
		trigger_event(chosen_option["next_event_id"])

func evaluate_daily_events() -> void:
	var month = StatManager.year[StatManager.current_month].month
	var day = StatManager.current_day
	var phase = StatManager.current_phase
	var phase_key := str(StatManager.current_month) + "_" + str(day) + "_" + str(phase)
	if last_evaluated_phase_key == phase_key:
		return
	last_evaluated_phase_key = phase_key
	current_stage = StatManager.get_stage_info()["stage"]
	
	# STAGE 1: BUDGETING (January - February)
	if month == "January":
		if day == 2 and phase == 0:
			trigger_event("first_salary")
		elif day == 5 and phase == 2:
			trigger_event("groceries_vs_eatout")
		elif day == 12 and phase == 1:
			trigger_event("electricity_spike")
		elif day == 18 and phase == 1:
			trigger_event("micro_ulan_surge")
		elif day == 22 and phase == 1:
			trigger_event("sibling_school_payment")
	elif month == "February":
		if day == 4 and phase == 1:
			trigger_event("phone_plan_upgrade")
		elif day == 10 and phase == 1:
			trigger_event("micro_opisina_potluck")
		elif day == 16 and phase == 0:
			trigger_event("commute_cost_increase")
	# STAGE 2: CREDIT AND DEBT (March - April)
	elif month == "March":
		if day == 3 and phase == 0:
			trigger_event("credit_card_offer")
		elif day == 8 and phase == 0:
			trigger_event("micro_grocery_cashback")
		elif day == 14 and phase == 2:
			trigger_event("refrigerator_breakdown")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	elif month == "April":
		if day == 5 and phase == 2:
			trigger_event("online_shopping_temptation")
		elif day == 12 and phase == 1:
			trigger_event("coworker_debt_story")
		elif day == 20 and phase == 1:
			trigger_event("family_medical_checkup")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	# STAGE 3: INTEREST AND FINANCIAL RISK (May - June)
	elif month == "May":
		if day == 4 and phase == 0:
			if (StatManager.credit_balance + StatManager.debt_balance + StatManager.get_total_active_loan_balance()) > 0:
				trigger_event("interest_applied")
			else:
				StatManager.set_baldo_lesson("Debt-Free Win", "Walang pumatong na interest ngayong Mayo dahil ₱0 ang utang at credit balance mo!")
		elif day == 12 and phase == 1:
			trigger_event("sibling_hospitalized")
		elif day == 18 and phase == 1:
			trigger_event("personal_health_issue")
		elif day == 22 and phase == 1:
			trigger_event("micro_meralco_tipid_reward")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	elif month == "June":
		if day == 2 and phase == 0:
			if StatManager.health_issue_delayed:
				trigger_event("health_complication")
		elif day == 6 and phase == 1:
			trigger_event("emergency_loan_5_6")
		elif day == 12 and phase == 0:
			trigger_event("inflation_hits_essentials")
		elif day == 22 and phase == 1:
			if StatManager.has_credit_card:
				trigger_event("credit_limit_increased")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	# STAGE 4: INVESTMENTS AND LONG-TERM PLANNING (July - August)
	elif month == "July":
		if day == 4 and phase == 0:
			trigger_event("side_income_opportunity")
		elif day == 10 and phase == 1:
			trigger_event("micro_midyear_ukay_find")
		elif day == 16 and phase == 1:
			trigger_event("investment_opportunity")
		elif day == 24 and phase == 1:
			trigger_event("sibling_condition_worsens")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	elif month == "August":
		if day == 4 and phase == 0:
			trigger_event("emergency_fund_decision")
		elif day == 14 and phase == 1:
			if StatManager.get_total_investments() > 0:
				trigger_event("investment_fluctuation")
		elif day == 22 and phase == 1:
			trigger_event("family_pressure_increases")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	# STAGE 5: MASTERY STAGE (September - December)
	elif month == "September":
		if day == 3 and phase == 0:
			trigger_event("job_layoff")
		elif day == 10 and phase == 1:
			trigger_event("lifestyle_adjustment_choice")
		elif day == 20 and phase == 1:
			if (StatManager.get_total_debt_and_loans() + StatManager.credit_balance) > 0:
				trigger_event("debt_collector_pressure")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	elif month == "October":
		if day == 6 and phase == 1:
			trigger_event("major_medical_emergency")
		elif day == 12 and phase == 2:
			trigger_event("social_isolation_effect")
		elif day == 18 and phase == 0:
			trigger_event("job_opportunity_tradeoff")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	elif month == "November":
		if day == 4 and phase == 0:
			trigger_event("new_job_offer")
		elif day == 14 and phase == 1:
			trigger_event("housing_pressure")
		elif day == 18 and phase == 0:
			trigger_event("micro_ber_months_sideline")
		elif day == 22 and phase == 1:
			if StatManager.get_total_investments() > 0:
				trigger_event("market_crash_or_boom")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")
	elif month == "December":
		if day == 10 and phase == 1:
			trigger_event("final_goal_opportunity")
		elif day == 25 and phase == 1:
			if StatManager.has_credit_card and StatManager.credit_balance > 0:
				trigger_event("credit_card_statement")

func get_events_context_for_ai() -> String:
	var ctx = "=== CURRENT & PAST EVENTS CONTEXT ===\n"
	
	# 1. Active Direct Event (if any)
	if is_direct_event_active and not current_direct_event.is_empty():
		ctx += "[URGENT DIRECT EVENT ON SCREEN RIGHT NOW]:\n"
		ctx += "- " + str(current_direct_event.get("title", "")) + ": " + str(current_direct_event.get("description", "")) + "\n"
		for opt in current_direct_event.get("options", []):
			ctx += "  * Option: \"" + str(opt.get("choice_text", "")) + "\" (Cost: PHP " + str(opt.get("cost", 0)) + ", Credit: PHP " + str(opt.get("credit_cost", 0)) + ", Happy: " + str(opt.get("happy_change", 0)) + ", Social: " + str(opt.get("social_change", 0)) + ")\n"
			
	# 2. Active Indirect Events on Phone
	if active_events.size() > 0:
		ctx += "[ACTIVE UNRESOLVED PHONE NOTIFICATIONS (" + str(active_events.size()) + " pending — must be resolved before day ends)]:\n"
		for ev in active_events:
			ctx += "- " + str(ev.get("title", "")) + ": " + str(ev.get("description", "")) + "\n"
			for opt in ev.get("options", []):
				ctx += "  * Option: \"" + str(opt.get("choice_text", "")) + "\" (Cost: PHP " + str(opt.get("cost", 0)) + ", Credit: PHP " + str(opt.get("credit_cost", 0)) + ", Happy: " + str(opt.get("happy_change", 0)) + ", Social: " + str(opt.get("social_change", 0)) + ")\n"
	else:
		ctx += "[ACTIVE PHONE NOTIFICATIONS]: None pending right now.\n"
		
	# 3. Past Resolved Events History (Player's Past Decisions)
	if event_history.size() > 0:
		ctx += "[PLAYER'S PAST EVENT DECISIONS (" + str(event_history.size()) + " total)]:\n"
		var start_idx = max(0, event_history.size() - 12)
		for i in range(start_idx, event_history.size()):
			var item = event_history[i]
			var cc_note = " [Charged Credit: PHP " + str(item.get("credit_cost", 0)) + "]" if int(item.get("credit_cost", 0)) > 0 else ""
			ctx += "- " + str(item["month"]) + " " + str(item["day"]) + ": \"" + str(item["title"]) + "\" -> Player chose \"" + str(item["choice_text"]) + "\" (Cash Cost: PHP " + str(item["cost"]) + cc_note + ", Happy: " + str(item["happy_change"]) + ", Social: " + str(item["social_change"]) + ")\n"
	else:
		ctx += "[PLAYER'S PAST EVENT DECISIONS]: No special events resolved yet.\n"
		
	# 4. Recent Financial Milestone Logs from PlannerManager (Salaries, Bills, Garnishments)
	var recent_logs = PlannerManager.get_recent_logs_summary(8)
	if recent_logs != "":
		ctx += "[RECENT PLANNER / TRANSACTION LOGS]:\n" + recent_logs
		
	return ctx
