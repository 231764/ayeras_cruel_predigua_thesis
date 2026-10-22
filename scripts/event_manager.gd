extends Node

signal on_direct_event_triggered(event_data)
signal on_indirect_event_triggered(event_data)
signal on_event_resolved(event_id)

var event_pool = {}
var active_events = []
var current_direct_event: Dictionary = {}
var event_history: Array = []
var current_stage = 1
var is_direct_event_active: bool = false

func _ready() -> void:
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
		event["description"] = "Narito na ang iyong monthly Credit Card Statement!\nTotal Balance: PHP " + str(bal) + " | Minimum Due (10%): PHP " + str(min_due) + "\nKung Minimum Due lang ang babayaran mo, papatungan ng 5% compounding interest ang natitirang balanse sa katapusan."
		if event["options"].size() >= 2:
			event["options"][0]["choice_text"] = "Bayaran nang Buo (PHP " + str(bal) + " — 0 Interest, +3 Credit Score)"
			event["options"][1]["choice_text"] = "Bayaran lang ang Minimum Due (PHP " + str(min_due) + " — -2 Credit Score)"
	
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

func format_option_Preview_bbcode(opt: Dictionary) -> String:
	var stats_text := ""
	var cost: int = int(opt.get("cost", 0))
	var credit_cost: int = int(opt.get("credit_cost", 0))
	
	if cost > 0:
		stats_text += "[color=red]-" + str(cost) + " PHP[/color] "
	elif cost < 0:
		stats_text += "[color=green]+" + str(abs(cost)) + " PHP[/color] "
		
	if credit_cost > 0:
		if StatManager.can_use_credit_card(credit_cost):
			stats_text += "[color=aqua]💳 +" + str(credit_cost) + " PHP Credit[/color] "
		else:
			stats_text += "[color=gray]💳 " + str(credit_cost) + " PHP (No Credit/Limit)[/color] "
			
	if opt.get("pay_credit_full", false):
		stats_text += "[color=red]-" + str(StatManager.credit_balance) + " PHP (Full Bill)[/color] "
	elif opt.get("pay_credit_minimum", false):
		stats_text += "[color=orange]-" + str(StatManager.get_credit_minimum_due()) + " PHP (Min Due)[/color] "
		
	if opt.has("installment") and opt["installment"] is Dictionary:
		var inst: Dictionary = opt["installment"]
		stats_text += "[color=orange]📅 PHP " + str(inst.get("monthly_cost", 0)) + "/mo x " + str(inst.get("months_left", 0)) + " mos[/color] "
		
	if opt.has("extra_utilities") and int(opt["extra_utilities"]) > 0:
		stats_text += "[color=orange]+" + str(opt["extra_utilities"]) + " PHP Bill[/color] "
	if opt.has("daily_commute_mod") and int(opt["daily_commute_mod"]) != 0:
		stats_text += "[color=orange]+" + str(opt["daily_commute_mod"]) + " PHP/day Commute[/color] "
	if opt.has("daily_food_mod") and int(opt["daily_food_mod"]) != 0:
		stats_text += "[color=orange]+" + str(opt["daily_food_mod"]) + " PHP/day Food[/color] "
		
	var happy_val: int = int(opt.get("happy_change", 0))
	if happy_val != 0:
		var sign_str = "+" if happy_val > 0 else ""
		var color = "green" if happy_val > 0 else "red"
		stats_text += "[color=" + color + "]" + sign_str + str(happy_val) + " Happy[/color] "
		
	var social_val: int = int(opt.get("social_change", 0))
	if social_val != 0:
		var sign_str = "+" if social_val > 0 else ""
		var color = "green" if social_val > 0 else "red"
		stats_text += "[color=" + color + "]" + sign_str + str(social_val) + " Social[/color] "
		
	var cs_val: int = int(opt.get("credit_score_change", 0))
	if cs_val != 0:
		var sign_str = "+" if cs_val > 0 else ""
		var color = "green" if cs_val > 0 else "red"
		stats_text += "[color=" + color + "]" + sign_str + str(cs_val) + " Credit Score[/color] "
		
	return stats_text

func is_option_selectable(opt: Dictionary) -> bool:
	if opt.has("credit_cost") and int(opt["credit_cost"]) > 0:
		return StatManager.can_use_credit_card(int(opt["credit_cost"]))
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
		
	var cost: int = int(chosen_option.get("cost", 0))
	var credit_cost: int = int(chosen_option.get("credit_cost", 0))
	var happy_delta: int = int(chosen_option.get("happy_change", 0))
	var social_delta: int = int(chosen_option.get("social_change", 0))
	var cs_delta: int = int(chosen_option.get("credit_score_change", 0))
	var paid_credit_amount: int = 0
	
	# 1. Apply cash/category cost
	if cost != 0:
		var cat: String = str(chosen_option.get("category", ""))
		if cat != "" and cost > 0:
			StatManager.spend_from_category(cat, cost)
		else:
			StatManager.spend_direct(cost)
			
	# 2. Apply Credit Card purchase
	if credit_cost > 0:
		StatManager.charge_credit_card(credit_cost)
		
	# 3. Apply Credit Card statement payments
	if chosen_option.get("pay_credit_full", false):
		paid_credit_amount = StatManager.pay_credit_card_balance(StatManager.credit_balance)
	elif chosen_option.get("pay_credit_minimum", false):
		paid_credit_amount = StatManager.pay_credit_card_balance(StatManager.get_credit_minimum_due())
		
	# 4. Apply Credit Card unlock
	if chosen_option.has("unlock_credit_card"):
		if bool(chosen_option["unlock_credit_card"]):
			StatManager.unlock_credit_card(int(chosen_option.get("credit_limit", 20000)))
			
	# 5. Apply Phone Slow / Upgraded flags
	if chosen_option.get("set_phone_slow", false):
		StatManager.phone_is_slow = true
		StatManager.phone_upgraded = false
	if chosen_option.get("set_phone_upgraded", false):
		StatManager.phone_is_slow = false
		StatManager.phone_upgraded = true
		
	# 6. Apply Installment plan if present
	if chosen_option.has("installment") and chosen_option["installment"] is Dictionary:
		var inst: Dictionary = chosen_option["installment"]
		StatManager.add_installment(
			str(inst.get("id", event_id)),
			str(inst.get("name", event["title"])),
			int(inst.get("monthly_cost", 0)),
			int(inst.get("months_left", 1))
		)
			
	# 7. Apply extra monthly bill & daily routine modifiers
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
		
	# 8. Apply clamped stat changes
	if happy_delta != 0:
		StatManager.modify_happy(happy_delta)
	if social_delta != 0:
		StatManager.modify_social(social_delta)
	if cs_delta != 0:
		StatManager.modify_credit_score(cs_delta)
		
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
	current_stage = StatManager.get_stage_info()["stage"]
	
	# STAGE 1: BUDGETING (January - February)
	if month == "January":
		if day == 2 and phase == 0:
			trigger_event("first_salary")
		elif day == 5 and phase == 2:
			trigger_event("groceries_vs_eatout")
		elif day == 12 and phase == 1:
			trigger_event("electricity_spike")
		elif day == 22 and phase == 1:
			trigger_event("sibling_school_payment")
	elif month == "February":
		if day == 4 and phase == 1:
			trigger_event("phone_plan_upgrade")
		elif day == 16 and phase == 0:
			trigger_event("commute_cost_increase")
	# STAGE 2: CREDIT AND DEBT (March - April)
	elif month == "March":
		if day == 3 and phase == 0:
			trigger_event("credit_card_offer")
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
