extends Node

signal on_direct_event_triggered(event_data)
signal on_indirect_event_triggered(event_data)
signal on_event_resolved(event_id)

var event_pool = {}
var active_events = []
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
		# Direct events usually pause the game and force an immediate choice
		is_direct_event_active = true
		emit_signal("on_direct_event_triggered", event)

func resolve_event(event_id: String, option_index: int) -> void:
	if not event_pool.has(event_id):
		return
		
	var event = event_pool[event_id]
	var options = event["options"]
	
	if option_index < 0 or option_index >= options.size():
		return
		
	var chosen_option = options[option_index]
	
	# Apply stat changes
	if chosen_option.has("cost"):
		StatManager.current_balance -= chosen_option["cost"]
	if chosen_option.has("happy_change"):
		StatManager.happy += chosen_option["happy_change"]
	if chosen_option.has("social_change"):
		StatManager.social += chosen_option["social_change"]
		
	# Check if it was an active indirect event and remove it
	if event in active_events:
		active_events.erase(event)
		
	if event["is_direct"]:
		is_direct_event_active = false
		
	emit_signal("on_event_resolved", event_id)
	print("Event Resolved: ", event_id, " | Option: ", chosen_option["choice_text"])
	
	# If there's a follow-up event
	if chosen_option.has("next_event_id") and chosen_option["next_event_id"] != "":
		trigger_event(chosen_option["next_event_id"])

func evaluate_daily_events() -> void:
	var month = StatManager.year[StatManager.current_month].month
	var day = StatManager.current_day
	var phase = StatManager.current_phase
	
	if month == "January":
		if day == 1 and phase == 0:
			trigger_event("first_salary")
		elif day == 3 and phase == 2:
			trigger_event("groceries_vs_eatout")
		elif day == 5 and phase == 1:
			trigger_event("electricity_spike")
