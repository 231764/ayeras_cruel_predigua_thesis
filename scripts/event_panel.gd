extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

@onready var modal_panel: Panel = $EventPanelBackdrop/Panel
@onready var title_label = $EventPanelBackdrop/Panel/VBoxContainer/TitleLabel
@onready var desc_label = $EventPanelBackdrop/Panel/VBoxContainer/DescLabel
@onready var options_container = $EventPanelBackdrop/Panel/VBoxContainer/OptionsContainer

var current_event_id: String = ""

func _ready() -> void:
	visible = false
	UITheme.style_header_banner(title_label, UITheme.BTN_GOLD, 8, 6.0)
	EventManager.on_direct_event_triggered.connect(_on_event_triggered)
	EventManager.on_indirect_event_triggered.connect(_on_indirect_event_triggered)

func _on_event_triggered(event_data: Dictionary) -> void:
	visible = true
	if modal_panel:
		modal_panel.pivot_offset = modal_panel.size * 0.5
		modal_panel.scale = Vector2(0.96, 0.96)
		modal_panel.modulate = Color(1, 1, 1, 0.0)
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(modal_panel, "scale", Vector2(1.0, 1.0), 0.16)
		tw.tween_property(modal_panel, "modulate:a", 1.0, 0.14)
	current_event_id = event_data["id"]
	title_label.text = str(event_data["title"])
	desc_label.text = str(event_data["description"])
	
	# Clear old buttons immediately
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
		
	# Create new buttons
	var options = event_data["options"]
	for i in range(options.size()):
		var btn := Button.new()
		var opt = options[i]
		var choice_text := str(opt["choice_text"])
		var can_select := EventManager.is_option_selectable(opt)
		btn.custom_minimum_size = Vector2(0, 74)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not can_select
		UITheme.style_Button(btn, UITheme.PAPER_KRAFT if i == 0 else UITheme.PAPER_CREAM, 8, 5)
		
		var rtf := RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.fit_content = true
		rtf.scroll_active = false
		rtf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtf.add_theme_color_override("default_color", UITheme.INK_DARK)
		rtf.set_anchors_preset(Control.PRESET_FULL_RECT)
		rtf.offset_left = 12.0
		rtf.offset_top = 6.0
		rtf.offset_right = -12.0
		rtf.offset_bottom = -6.0
		
		var stats_text := EventManager.format_option_Preview_bbcode(opt)
		rtf.text = "[center][b]" + choice_text + "[/b]\n[font_size=14]" + stats_text + "[/font_size][/center]"
		btn.add_child(rtf)
		btn.pressed.connect(_on_option_selected.bind(i))
		options_container.add_child(btn)

func _on_indirect_event_triggered(event_data: Dictionary) -> void:
	print("New Notification on Phone: ", event_data["title"])

func _on_option_selected(index: int) -> void:
	EventManager.resolve_event(current_event_id, index)
	visible = false
