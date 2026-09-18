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
		btn.text = options[i]["choice_text"]
		btn.pressed.connect(_on_option_selected.bind(i))
		options_container.add_child(btn)

func _on_indirect_event_triggered(event_data: Dictionary) -> void:
	# For testing, we just print this out. Later this will show up on the phone.
	print("New Notification on Phone: ", event_data["title"])

func _on_option_selected(index: int) -> void:
	EventManager.resolve_event(current_event_id, index)
	visible = false
