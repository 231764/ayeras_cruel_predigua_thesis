extends Control

@onready var notifications_container = $ScrollContainer/VBoxContainer/NotificationsContainer
@onready var event_detail_panel = $EventDetailPanel
@onready var event_title = $EventDetailPanel/VBoxContainer/EventTitle
@onready var event_desc = $EventDetailPanel/VBoxContainer/EventDescription
@onready var options_container = $EventDetailPanel/VBoxContainer/OptionsContainer

@onready var chat_panel = $ChatPanel
@onready var chat_history = $ChatPanel/VBoxContainer/ChatHistory
@onready var chat_input = $ChatPanel/VBoxContainer/HBoxContainer/ChatInput
@onready var ai_http_request = $AIHTTPRequest

var current_viewing_event_id: String = ""
var chat_messages: Array = []

func _ready() -> void:
	EventManager.on_indirect_event_triggered.connect(_on_event_triggered)
	EventManager.on_event_resolved.connect(_on_event_resolved)
	ai_http_request.request_completed.connect(_on_ai_request_completed)
	
	# Initialize chat prompt
	chat_messages.append({
		"role": "system",
		"content": "You are Baldo, a wise and trustworthy Filipino friend who acts as a financial coach for a young breadwinner working their first job. You provide financial and life advice. IMPORTANT: You must ALWAYS speak in a casual, relatable Gen-Z Filipino 'Taglish' tone. Use common slang like 'omsim', 'paldo', 'petsa de peligro', 'hustle', and 'dasurv' when appropriate. Keep responses concise and extremely helpful."
	})
	
	refresh_notifications()

func _on_event_triggered(event_data: Dictionary) -> void:
	refresh_notifications()

func _on_event_resolved(event_id: String) -> void:
	refresh_notifications()
	event_detail_panel.hide()

func refresh_notifications() -> void:
	# Clear existing
	for child in notifications_container.get_children():
		child.queue_free()
		
	# Populate active events
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
	
	# Clear options
	for child in options_container.get_children():
		child.queue_free()
		
	# Add options
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
		if option.has("happy_change") and option["happy_change"] != 0:
			var val = option["happy_change"]
			var sign = "+" if val > 0 else ""
			var color = "green" if val > 0 else "red"
			stats_text += "[color=" + color + "]" + sign + str(val) + " Happy[/color] "
		if option.has("social_change") and option["social_change"] != 0:
			var val = option["social_change"]
			var sign = "+" if val > 0 else ""
			var color = "green" if val > 0 else "red"
			stats_text += "[color=" + color + "]" + sign + str(val) + " Social[/color] "
			
		rtf.text = "[center]" + choice_text + "\n[font_size=14]" + stats_text + "[/font_size][/center]"
		btn.add_child(rtf)
		# Bind the index so the lambda captures the correct value
		btn.pressed.connect(func(idx=i): resolve_current_event(idx))
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

func _on_send_chat_button_pressed() -> void:
	var text = chat_input.text.strip_edges()
	if text == "":
		return
		
	chat_input.text = ""
	add_chat_bubble("You", text)
	
	chat_messages.append({
		"role": "user",
		"content": text
	})
	
	send_ai_request()

func add_chat_bubble(sender: String, text: String) -> void:
	var color = "white"
	if sender == "Baldo":
		color = "lightblue"
	elif sender == "System":
		color = "gray"
		
	chat_history.text += "\n[color=" + color + "]" + sender + ":[/color] " + text

func send_ai_request() -> void:
	# Optimization: Keep only the system prompt + last 10 messages to avoid token limit
	while chat_messages.size() > 11:
		chat_messages.remove_at(1)

	var api_key = OS.get_environment("OPENAI_API_KEY")
	if api_key == "":
		add_chat_bubble("System", "OpenAI API Key not found. Please set the OPENAI_API_KEY environment variable.")
		return
		
	var url = "https://api.openai.com/v1/chat/completions"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var body = {
		"model": "gpt-4o-mini",
		"messages": chat_messages,
		"max_tokens": 150
	}
	
	var error = ai_http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		add_chat_bubble("System", "Failed to send request.")

func _on_ai_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		var response = json.get_data()
		
		if response.has("choices") and response["choices"].size() > 0:
			var reply = response["choices"][0]["message"]["content"]
			add_chat_bubble("Baldo", reply)
			chat_messages.append({
				"role": "assistant",
				"content": reply
			})
	else:
		add_chat_bubble("System", "API Error: " + str(response_code))
