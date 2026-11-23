extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

@onready var modal_panel: Panel = $EventPanelBackdrop/Panel
@onready var title_label = $EventPanelBackdrop/Panel/VBoxContainer/TitleLabel
@onready var desc_label = $EventPanelBackdrop/Panel/VBoxContainer/DescLabel
@onready var options_container = $EventPanelBackdrop/Panel/VBoxContainer/OptionsScroll/OptionsContainer

var current_event_id: String = ""
var _art_frame: PanelContainer = null
var _art_texture_rect: TextureRect = null
var _category_chip: PanelContainer = null
var _category_pill: Label = null
var _panel_tween: Tween = null
var _art_tween: Tween = null

func _ready() -> void:
	visible = false
	UITheme.style_header_banner(title_label, UITheme.BTN_GOLD, 8, 6.0, UITheme.TYPE_HEADING)
	if desc_label:
		UITheme.apply_type(desc_label, UITheme.TYPE_BODY, UITheme.FONT_BODY)
	_ensure_event_visual_header()
	EventManager.on_direct_event_triggered.connect(_on_event_triggered)
	EventManager.on_indirect_event_triggered.connect(_on_indirect_event_triggered)

func _ensure_event_visual_header() -> void:
	if _art_frame or not title_label:
		return
	var vbox := title_label.get_parent() as VBoxContainer
	if not vbox:
		return
	_art_frame = PanelContainer.new()
	_art_frame.name = "EventArtFrame"
	_art_frame.clip_contents = true
	_art_frame.custom_minimum_size = Vector2(0, 174)
	_art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_sb := UITheme.make_card_style(Color(0.953, 0.898, 0.855, 1.0), UITheme.INK_BORDER, 10, 2, 3, 4.0, 4.0)
	_art_frame.add_theme_stylebox_override("panel", frame_sb)
	vbox.add_child(_art_frame)
	vbox.move_child(_art_frame, title_label.get_index() + 1)

	var art_wrap := Control.new()
	art_wrap.name = "ArtWrapper"
	art_wrap.clip_contents = true
	art_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art_frame.add_child(art_wrap)

	_art_texture_rect = TextureRect.new()
	_art_texture_rect.name = "EventArtTexture"
	_art_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_wrap.add_child(_art_texture_rect)

	_category_chip = PanelContainer.new()
	_category_chip.name = "CategoryChip"
	_category_chip.offset_left = 8.0
	_category_chip.offset_top = 8.0
	_category_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_category_chip.add_theme_stylebox_override("panel", UITheme.make_tactile_btn_style(UITheme.PAPER_KRAFT, UITheme.INK_BORDER, 6, 2, 10.0, 3.0))
	art_wrap.add_child(_category_chip)

	_category_pill = Label.new()
	_category_pill.name = "CategoryPill"
	_category_pill.text = "Gastos at Routine"
	UITheme.apply_type(_category_pill, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	_category_pill.add_theme_color_override("font_color", UITheme.INK_DARK)
	_category_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_category_chip.add_child(_category_pill)

func _on_event_triggered(event_data: Dictionary) -> void:
	visible = true
	if modal_panel:
		if _panel_tween and _panel_tween.is_valid():
			_panel_tween.kill()
		modal_panel.pivot_offset = modal_panel.size * 0.5
		modal_panel.scale = Vector2(0.96, 0.96)
		modal_panel.modulate = Color(1, 1, 1, 0.0)
		_panel_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_panel_tween.tween_property(modal_panel, "scale", Vector2(1.0, 1.0), 0.16)
		_panel_tween.tween_property(modal_panel, "modulate:a", 1.0, 0.14)
	current_event_id = str(event_data["id"])
	var meta: Dictionary = EventManager.get_event_category_meta(event_data)
	var cat_col: Color = meta.get("color", UITheme.BTN_GOLD)
	UITheme.style_header_banner(title_label, cat_col, 8, 6.0, UITheme.TYPE_HEADING)
	if _category_pill:
		_category_pill.text = str(meta.get("label", "Event"))
	if _category_chip:
		_category_chip.add_theme_stylebox_override("panel", UITheme.make_tactile_btn_style(cat_col.lightened(0.28), UITheme.INK_BORDER, 6, 2, 10.0, 3.0))
	var ev_tex: Texture2D = EventManager.get_event_texture(current_event_id)
	if _art_frame and _art_texture_rect:
		_art_texture_rect.texture = ev_tex
		_art_texture_rect.visible = (ev_tex != null)
		_art_frame.custom_minimum_size = Vector2(0, 174) if ev_tex != null else Vector2(0, 42)
		if ev_tex != null:
			if _art_tween and _art_tween.is_valid():
				_art_tween.kill()
			_art_texture_rect.pivot_offset = _art_texture_rect.size * 0.5
			_art_texture_rect.scale = Vector2(0.985, 0.985)
			_art_texture_rect.modulate.a = 0.0
			_art_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_art_tween.tween_property(_art_texture_rect, "scale", Vector2.ONE, 0.18)
			_art_tween.tween_property(_art_texture_rect, "modulate:a", 1.0, 0.16)
	title_label.text = str(event_data["title"])
	desc_label.text = str(event_data["description"])
	
	# Clear old buttons immediately
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
		
	# Create new buttons
	var options = event_data["options"]
	var btn_h: float = 68.0 if options.size() <= 3 else 62.0
	for i in range(options.size()):
		var btn := Button.new()
		var opt = options[i]
		var choice_text := str(opt["choice_text"])
		var can_select := EventManager.is_option_selectable(opt)
		btn.custom_minimum_size = Vector2(0, btn_h)
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
		rtf.add_theme_font_override("normal_font", UITheme.FONT_BODY)
		rtf.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
		rtf.add_theme_font_size_override("normal_font_size", UITheme.TYPE_BODY)
		rtf.add_theme_font_size_override("bold_font_size", UITheme.TYPE_BODY)
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
