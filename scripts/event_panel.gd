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
		var opt = options[i]
		var choice_text = opt["choice_text"]
		btn.custom_minimum_size = Vector2(0, 60)
		
		var rtf = RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtf.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		var stats_text = ""
		
		if opt.has("cost") and opt["cost"] > 0:
			stats_text += "[color=red]-" + str(opt["cost"]) + " PHP[/color] "
		elif opt.has("cost") and opt["cost"] < 0:
			stats_text += "[color=green]+" + str(abs(opt["cost"])) + " PHP[/color] "
		if opt.has("extra_utilities") and int(opt["extra_utilities"]) > 0:
			stats_text += "[color=orange]+" + str(opt["extra_utilities"]) + " PHP Bill[/color] "
		if opt.has("happy_change") and opt["happy_change"] != 0:
			var val = opt["happy_change"]
			var sign_str = "+" if val > 0 else ""
			var color = "green" if val > 0 else "red"
			stats_text += "[color=" + color + "]" + sign_str + str(val) + " Happy[/color] "
		if opt.has("social_change") and opt["social_change"] != 0:
			var val = opt["social_change"]
			var sign_str = "+" if val > 0 else ""
			var color = "green" if val > 0 else "red"
			stats_text += "[color=" + color + "]" + sign_str + str(val) + " Social[/color] "
			
		rtf.text = "[center]" + choice_text + "\n[font_size=14]" + stats_text + "[/font_size][/center]"
		btn.add_child(rtf)
		btn.pressed.connect(_on_option_selected.bind(i))
		options_container.add_child(btn)

func _on_indirect_event_triggered(event_data: Dictionary) -> void:
	print("New Notification on Phone: ", event_data["title"])

func _on_option_selected(index: int) -> void:
	EventManager.resolve_event(current_event_id, index)
	visible = false
