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

func resolve_event(event_id: String, option_index: int) -> void:
	if not event_pool.has(event_id):
		return
		
	var event = event_pool[event_id]
	var options = event["options"]
	
	if option_index < 0 or option_index >= options.size():
		return
		
	var chosen_option = options[option_index]
	var cost: int = int(chosen_option.get("cost", 0))
	var happy_delta: int = int(chosen_option.get("happy_change", 0))
	var social_delta: int = int(chosen_option.get("social_change", 0))
	
	# Apply cost (via category envelope if specified, otherwise direct balance with debt rollover)
	if cost != 0:
		var cat: String = str(chosen_option.get("category", ""))
		if cat != "" and cost > 0:
			StatManager.spend_from_category(cat, cost)
		else:
			StatManager.spend_direct(cost)
			
	# Apply extra monthly bill modifiers if present
	if chosen_option.has("extra_utilities"):
		StatManager.extra_utilities_this_month += int(chosen_option["extra_utilities"])
		
	# Apply daily routine choice updates if present
	if chosen_option.has("set_daily_food"):
		StatManager.daily_food_choice = int(chosen_option["set_daily_food"])
	if chosen_option.has("set_daily_commute"):
		StatManager.daily_commute_choice = int(chosen_option["set_daily_commute"])
		
	# Apply clamped stat changes
	if happy_delta != 0:
		StatManager.modify_happy(happy_delta)
	if social_delta != 0:
		StatManager.modify_social(social_delta)
		
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
		"cost": cost,
		"happy_change": happy_delta,
		"social_change": social_delta,
		"extra_utilities": int(chosen_option.get("extra_utilities", 0))
	})
		
	emit_signal("on_event_resolved", event_id)
	print("Event Resolved: ", event_id, " | Option: ", choice_text)
	
	var tradeoff_str = ""
	if cost > 0:
		tradeoff_str += "[color=red]-" + str(cost) + " PHP[/color] "
	elif cost < 0:
		tradeoff_str += "[color=green]+" + str(abs(cost)) + " PHP[/color] "
	if chosen_option.has("extra_utilities") and int(chosen_option["extra_utilities"]) > 0:
		tradeoff_str += "[color=orange]+" + str(chosen_option["extra_utilities"]) + " PHP Utilities Due[/color] "
	if happy_delta != 0:
		var sign_str = "+" if happy_delta > 0 else ""
		var color = "green" if happy_delta > 0 else "red"
		tradeoff_str += "[color=" + color + "]" + sign_str + str(happy_delta) + " Happy[/color] "
	if social_delta != 0:
		var sign_str = "+" if social_delta > 0 else ""
		var color = "green" if social_delta > 0 else "red"
		tradeoff_str += "[color=" + color + "]" + sign_str + str(social_delta) + " Social[/color] "
		
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
	
	if month == "January":
		if day == 3 and phase == 2:
			trigger_event("groceries_vs_eatout")
		elif day == 5 and phase == 1:
			trigger_event("electricity_spike")
	elif month == "February":
		if day == 14 and phase == 2:
			trigger_event("friends_birthday")
	elif month == "March":
		if day == 10 and phase == 0:
			trigger_event("sick_day")

func get_events_context_for_ai() -> String:
	var ctx = "=== CURRENT & PAST EVENTS CONTEXT ===\n"
	
	# 1. Active Direct Event (if any)
	if is_direct_event_active and not current_direct_event.is_empty():
		ctx += "[URGENT DIRECT EVENT ON SCREEN RIGHT NOW]:\n"
		ctx += "- " + str(current_direct_event.get("title", "")) + ": " + str(current_direct_event.get("description", "")) + "\n"
		for opt in current_direct_event.get("options", []):
			ctx += "  * Option: \"" + str(opt.get("choice_text", "")) + "\" (Cost: PHP " + str(opt.get("cost", 0)) + ", Happy: " + str(opt.get("happy_change", 0)) + ", Social: " + str(opt.get("social_change", 0)) + ")\n"
			
	# 2. Active Indirect Events on Phone
	if active_events.size() > 0:
		ctx += "[ACTIVE UNRESOLVED PHONE NOTIFICATIONS (" + str(active_events.size()) + " pending — must be resolved before day ends)]:\n"
		for ev in active_events:
			ctx += "- " + str(ev.get("title", "")) + ": " + str(ev.get("description", "")) + "\n"
			for opt in ev.get("options", []):
				var extra_util = " +PHP " + str(opt.get("extra_utilities", 0)) + " Utilities bill" if opt.has("extra_utilities") else ""
				ctx += "  * Option: \"" + str(opt.get("choice_text", "")) + "\" (Cost: PHP " + str(opt.get("cost", 0)) + extra_util + ", Happy: " + str(opt.get("happy_change", 0)) + ", Social: " + str(opt.get("social_change", 0)) + ")\n"
	else:
		ctx += "[ACTIVE PHONE NOTIFICATIONS]: None pending right now.\n"
		
	# 3. Past Resolved Events History (Player's Past Decisions)
	if event_history.size() > 0:
		ctx += "[PLAYER'S PAST EVENT DECISIONS (" + str(event_history.size()) + " total)]:\n"
		var start_idx = max(0, event_history.size() - 12)
		for i in range(start_idx, event_history.size()):
			var item = event_history[i]
			ctx += "- " + str(item["month"]) + " " + str(item["day"]) + ": \"" + str(item["title"]) + "\" -> Player chose \"" + str(item["choice_text"]) + "\" (Cost: PHP " + str(item["cost"]) + ", Happy: " + str(item["happy_change"]) + ", Social: " + str(item["social_change"]) + ")\n"
	else:
		ctx += "[PLAYER'S PAST EVENT DECISIONS]: No special events resolved yet.\n"
		
	# 4. Recent Financial Milestone Logs from PlannerManager (Salaries, Bills, Garnishments)
	var recent_logs = PlannerManager.get_recent_logs_summary(8)
	if recent_logs != "":
		ctx += "[RECENT PLANNER / TRANSACTION LOGS]:\n" + recent_logs
		
	return ctx
