extends Control

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

var current_viewing_event_id: String = ""
var chat_messages: Array = []
var is_request_pending: bool = false

func _ready() -> void:
	EventManager.on_indirect_event_triggered.connect(_on_event_triggered)
	EventManager.on_event_resolved.connect(_on_event_resolved)
	ai_http_request.request_completed.connect(_on_ai_request_completed)
	
	if chat_input and not chat_input.text_submitted.is_connected(_on_chat_input_submitted):
		chat_input.text_submitted.connect(_on_chat_input_submitted)
	
	# Initialize system prompt slot (dynamically refreshed with live context before every message)
	chat_messages.append({
		"role": "system",
		"content": _build_system_prompt()
	})
	
	add_chat_bubble("Baldo", "Yow par! Ako si Baldo, ang financial buddy mo. Tanong ka lang kung paano i-budget ang sahod mo, ano gagawin sa bills, o kung may gumugulo sa isip mo!")
	refresh_notifications()

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
		child.queue_free()
		
	for event in EventManager.active_events:
		var btn = Button.new()
		btn.text = "New Message: " + event["title"]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.pressed.connect(func(): open_event_detail(event))
		notifications_container.add_child(btn)

func open_event_detail(event: Dictionary) -> void:
	current_viewing_event_id = event["id"]
	event_title.text = event["title"]
	event_desc.text = event["description"]
	
	for child in options_container.get_children():
		child.queue_free()
		
	var i = 0
	for option in event["options"]:
		var btn = Button.new()
		var choice_text = option["choice_text"]
		btn.custom_minimum_size = Vector2(0, 60)
		
		var rtf = RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtf.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		var stats_text = ""
		
		if option.has("cost") and option["cost"] > 0:
			stats_text += "[color=red]-" + str(option["cost"]) + " PHP[/color] "
		elif option.has("cost") and option["cost"] < 0:
			stats_text += "[color=green]+" + str(abs(option["cost"])) + " PHP[/color] "
		if option.has("extra_utilities") and int(option["extra_utilities"]) > 0:
			stats_text += "[color=orange]+" + str(option["extra_utilities"]) + " PHP Bill[/color] "
		if option.has("happy_change") and option["happy_change"] != 0:
			var val = option["happy_change"]
			var sign_str = "+" if val > 0 else ""
			var color = "green" if val > 0 else "red"
			stats_text += "[color=" + color + "]" + sign_str + str(val) + " Happy[/color] "
		if option.has("social_change") and option["social_change"] != 0:
			var val = option["social_change"]
			var sign_str = "+" if val > 0 else ""
			var color = "green" if val > 0 else "red"
			stats_text += "[color=" + color + "]" + sign_str + str(val) + " Social[/color] "
			
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
	chat_panel.show()

func _on_close_chat_button_pressed() -> void:
	chat_panel.hide()

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
	var total_util_due = StatManager.monthly_utilities + StatManager.extra_utilities_this_month
	var rent_short = max(0, StatManager.monthly_rent - rent_env)
	var util_short = max(0, total_util_due - util_env)
	var tips: Array[String] = []
	
	# 1. Check active unread phone events
	if EventManager.active_events.size() > 0:
		var active_ev = EventManager.active_events[0]
		tips.append("May unread message ka pa tungkol sa \"" + str(active_ev["title"]) + "\"! I-settle mo muna 'yan bago mag-Evening.")
		
	# 2. Check past decisions context
	if EventManager.event_history.size() > 0:
		var last_ev = EventManager.event_history[EventManager.event_history.size() - 1]
		tips.append("Naalala ko pinili mo yung \"" + str(last_ev["choice_text"]) + "\" sa \"" + str(last_ev["title"]) + "\".")
		
	# 3. Check debt, envelopes, and Life Goal savings progress
	var goal = StatManager.get_current_goal()
	if StatManager.debt_balance > 0:
		tips.append("Naku par, may PHP " + str(StatManager.debt_balance) + " kang utang na may 5% monthly interest at kaltas sa sahod, kaya tipid mode muna tayo!")
	elif rent_short > 0 or util_short > 0:
		tips.append("Sa PHP " + str(StatManager.current_balance) + " mong hawak ngayon, magtabi ka na sa Cash Envelopes: kulang ka pa ng PHP " + str(rent_short) + " sa Upa at PHP " + str(util_short) + " sa Kuryente/Tubig bago mag-katapusan.")
	else:
		tips.append("Solid par, kumpleto na ang pambayad mo sa Upa at Utilities envelopes! Maghulog ka na sa Ipon / Savings (nasa PHP " + str(StatManager.savings) + " / PHP " + str(goal["cost"]) + " ka na para sa \"" + str(goal["title"]) + "\") para kumita ng 2% monthly compounding interest!")
		
	# 4. Check well-being meters
	if StatManager.happy < 40 or StatManager.social < 40:
		tips.append("Pero bantayan mo rin sarili mo ha—Happiness mo ay " + str(StatManager.happy) + "/100 at Social ay " + str(StatManager.social) + "/100. 'Wag puro tipid kung ma-buburnout ka naman!")
	else:
		tips.append("Goods pa naman ang Happiness (" + str(StatManager.happy) + "/100) at Social (" + str(StatManager.social) + "/100) mo, tuloy lang ang hustle para pumaldo!")
		
	return " ".join(tips)
