extends CanvasLayer

@onready var title_label = $EventPanelBackdrop/Panel/VBoxContainer/TitleLabel
@onready var desc_label = $EventPanelBackdrop/Panel/VBoxContainer/DescLabel
@onready var options_container = $EventPanelBackdrop/Panel/VBoxContainer/OptionsContainer


var current_event_id: String = ""

func _ready() -> void:
	visible = false
	EventManager.on_direct_event_triggered.connect(_on_event_triggered)
	EventManager.on_indirect_event_triggered.connect(_on_indirect_event_triggered)

func _on_event_triggered(event_data: Dictionary) -> void:
	visible = true
	current_event_id = event_data["id"]
	title_label.text = event_data["title"]
	desc_label.text = event_data["description"]
	
	# Clear old buttons
	for child in options_container.get_children():
		child.queue_free()
		
	# Create new buttons
	var options = event_data["options"]
	for i in range(options.size()):
		var btn = Button.new()
		var choice_text = options[i]["choice_text"]
		btn.custom_minimum_size = Vector2(0, 60)
		
		var rtf = RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtf.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		var stats_text = ""
		
		if options[i].has("cost") and options[i]["cost"] > 0:
			stats_text += "[color=red]-" + str(options[i]["cost"]) + " PHP[/color] "
		if options[i].has("happy_change") and options[i]["happy_change"] != 0:
			var val = options[i]["happy_change"]
			var sign = "+" if val > 0 else ""
			var color = "green" if val > 0 else "red"
			stats_text += "[color=" + color + "]" + sign + str(val) + " Happy[/color] "
		if options[i].has("social_change") and options[i]["social_change"] != 0:
			var val = options[i]["social_change"]
			var sign = "+" if val > 0 else ""
			var color = "green" if val > 0 else "red"
			stats_text += "[color=" + color + "]" + sign + str(val) + " Social[/color] "
			
		rtf.text = "[center]" + choice_text + "\n[font_size=14]" + stats_text + "[/font_size][/center]"
		btn.add_child(rtf)
		btn.pressed.connect(_on_option_selected.bind(i))
		options_container.add_child(btn)

func _on_indirect_event_triggered(event_data: Dictionary) -> void:
	# For testing, we just print this out. Later this will show up on the phone.
	print("New Notification on Phone: ", event_data["title"])

func _on_option_selected(index: int) -> void:
	EventManager.resolve_event(current_event_id, index)
	visible = false
