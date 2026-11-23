extends Node2D

const UITheme = preload("res://scripts/ui_theme.gd")

@onready var grid = $GridContainer
@onready var dateLabel = $"Date Label"
@onready var next_month_btn: Button = get_node_or_null("Date Label/NextMonth")
@onready var prev_month_btn: Button = get_node_or_null("Date Label/PreviousMonth")
@onready var notes = $Notes
@onready var dayLabel = $"Day Label"
@onready var event_label = $Events/"Event Label"
@onready var save_note_btn = $Notes/Button

var day_of_entry = 1
var month_of_entry = 0
var month_picker = 0
var _is_initialized: bool = false

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_apply_save_btn_style()
	if visible:
		_on_visibility_changed()

func _apply_save_btn_style() -> void:
	UITheme.style_Button(save_note_btn, UITheme.BTN_SAGE, 6, 4, 10.0, 4.0)
	UITheme.apply_type(save_note_btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.style_Button(next_month_btn, UITheme.BTN_GOLD, 6, 4, 8.0, 4.0)
	UITheme.set_button_icon(next_month_btn, UITheme.ICON_ARROW_RIGHT, false, true)
	UITheme.style_Button(prev_month_btn, UITheme.BTN_GOLD, 6, 4, 8.0, 4.0)
	UITheme.set_button_icon(prev_month_btn, UITheme.ICON_ARROW_LEFT, false, true)
	if dateLabel:
		UITheme.apply_type(dateLabel, UITheme.TYPE_HEADING, UITheme.FONT_HEADING)
	var headers_hbox := get_node_or_null("WeekdayHeadersHBox")
	if headers_hbox:
		for i in range(headers_hbox.get_child_count()):
			var lbl := headers_hbox.get_child(i)
			if lbl is Label:
				var is_sun: bool = (i == 0)
				var is_sat: bool = (i == 6)
				var pill_bg := Color(0.95, 0.76, 0.72, 1.0) if is_sun else (Color(0.94, 0.85, 0.62, 1.0) if is_sat else Color(0.92, 0.84, 0.64, 1.0))
				lbl.add_theme_stylebox_override("normal", _make_day_style(pill_bg, UITheme.INK_BORDER, 1, 2, 4))
				UITheme.apply_type(lbl, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
				lbl.add_theme_color_override("font_color", Color(0.58, 0.12, 0.10, 1.0) if is_sun else UITheme.INK_DARK)
	if dayLabel:
		dayLabel.add_theme_stylebox_override("normal", UITheme.make_card_style(UITheme.BTN_GOLD, UITheme.INK_BORDER, 6, 2, 3, 8.0, 4.0))
		UITheme.apply_type(dayLabel, UITheme.TYPE_SUBHEAD, UITheme.FONT_UI)
		dayLabel.add_theme_color_override("font_color", UITheme.INK_DARK)

func _on_visibility_changed() -> void:
	if visible:
		day_of_entry = StatManager.current_day
		month_picker = 0
		month_of_entry = StatManager.current_month
		_is_initialized = true
		update_ui()
	elif _is_initialized:
		_auto_save_current_note()

func _auto_save_current_note() -> void:
	if _is_initialized and notes != null:
		PlannerManager.save_entry(month_of_entry, day_of_entry, notes.text)

func update_ui() -> void:
	month_of_entry = clamp(StatManager.current_month + month_picker, 0, StatManager.year.size() - 1)
	
	var month_name := str(StatManager.year[month_of_entry].month)
	dateLabel.text = month_name + " 2026"
	
	var weekday_full: String = StatManager.get_weekday_name(month_of_entry, day_of_entry, false)
	var extra_milestone := ""
	if day_of_entry == 1 or day_of_entry == 15:
		extra_milestone = "  |  Sahod Day"
	elif day_of_entry == StatManager.year[month_of_entry].days:
		extra_milestone = "  |  Katapusan Bills Due"
	elif day_of_entry in [7, 14, 21, 28]:
		extra_milestone = "  |  Weekly Summary"
		
	dayLabel.text = weekday_full + ", " + month_name + " " + str(day_of_entry) + ", 2026" + extra_milestone
	make_buttons_for_month()
	replace_notes()
	replace_events()

func _make_day_style(bg: Color, border: Color, border_w: int = 2, bottom_lip: int = 3, radius: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = bottom_lip
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	return sb

func _create_empty_calendar_slot() -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(50, 41)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _make_day_style(
		Color(0.86, 0.79, 0.75, 0.32),
		Color(0.45, 0.36, 0.32, 0.25),
		1, 1, 4
	))
	return slot

func make_buttons_for_month() -> void:
	var days_in_month: int = StatManager.year[month_of_entry].days
	var start_weekday: int = StatManager.get_month_start_weekday(month_of_entry)
	
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	
	# Leading empty cells so Day 1 aligns with its true 2026 Sunday-first (LIN..SAB) weekday
	for _empty_idx in range(start_weekday):
		grid.add_child(_create_empty_calendar_slot())
	
	for day in range(1, days_in_month + 1):
		var button := Button.new()
		var has_ev: bool = PlannerManager.has_events_on_day(month_of_entry, day)
		var has_nt: bool = PlannerManager.has_notes_on_day(month_of_entry, day)
		var has_ms: bool = PlannerManager.has_scheduled_milestone(month_of_entry, day)
		var dow: int = (start_weekday + day - 1) % 7
		
		var marker: String = ""
		if day == 1 or day == 15:
			marker = "\nSAHOD"
		elif day == days_in_month:
			marker = "\nBILLS"
		elif has_ms:
			marker = "\nCC DUE"
		elif has_ev and has_nt:
			marker = " •*"
		elif has_ev:
			marker = " •"
		elif has_nt:
			marker = " *"
			
		button.text = str(day) + marker
		button.add_theme_font_size_override("font_size", 10 if "\n" in marker else 13)
		button.custom_minimum_size = Vector2(50, 41)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var is_today: bool = (day == StatManager.current_day and month_of_entry == StatManager.current_month)
		var is_selected: bool = (day == day_of_entry)
		var ink_border := Color(0.15, 0.13, 0.11, 0.96)
		
		if is_today:
			button.add_theme_color_override("font_color", UITheme.INK_DARK)
			button.add_theme_color_override("font_hover_color", UITheme.INK_DARK)
			button.add_theme_stylebox_override("normal", _make_day_style(UITheme.BTN_SAGE, ink_border, 2, 4, 5))
			button.add_theme_stylebox_override("hover", _make_day_style(UITheme.BTN_SAGE.lightened(0.08), ink_border, 2, 4, 5))
			button.add_theme_stylebox_override("pressed", _make_day_style(UITheme.BTN_SAGE.darkened(0.06), ink_border, 2, 2, 5))
		elif is_selected:
			button.add_theme_color_override("font_color", UITheme.INK_DARK)
			button.add_theme_color_override("font_hover_color", UITheme.INK_DARK)
			button.add_theme_stylebox_override("normal", _make_day_style(UITheme.BTN_GOLD, ink_border, 2, 4, 5))
			button.add_theme_stylebox_override("hover", _make_day_style(UITheme.BTN_GOLD.lightened(0.08), ink_border, 2, 4, 5))
			button.add_theme_stylebox_override("pressed", _make_day_style(UITheme.BTN_GOLD.darkened(0.06), ink_border, 2, 2, 5))
		elif day == 1 or day == 15:
			button.add_theme_color_override("font_color", Color(0.08, 0.34, 0.16))
			button.add_theme_color_override("font_hover_color", UITheme.INK_DARK)
			button.add_theme_stylebox_override("normal", _make_day_style(Color(0.84, 0.94, 0.82, 0.96), ink_border, 1, 3, 5))
			button.add_theme_stylebox_override("hover", _make_day_style(Color(0.90, 0.97, 0.88, 1.0), ink_border, 2, 3, 5))
		elif day == days_in_month:
			button.add_theme_color_override("font_color", Color(0.55, 0.12, 0.10))
			button.add_theme_color_override("font_hover_color", UITheme.INK_DARK)
			button.add_theme_stylebox_override("normal", _make_day_style(Color(0.98, 0.85, 0.80, 0.96), ink_border, 1, 3, 5))
			button.add_theme_stylebox_override("hover", _make_day_style(Color(1.0, 0.90, 0.86, 1.0), ink_border, 2, 3, 5))
		elif has_ev or has_nt:
			button.add_theme_color_override("font_color", UITheme.INK_DARK)
			button.add_theme_color_override("font_hover_color", UITheme.INK_DARK)
			button.add_theme_stylebox_override("normal", _make_day_style(Color(0.96, 0.90, 0.72, 0.96), ink_border, 1, 3, 5))
			button.add_theme_stylebox_override("hover", _make_day_style(Color(0.99, 0.94, 0.80, 1.0), ink_border, 2, 3, 5))
		else:
			var day_fg := Color(0.68, 0.16, 0.14) if dow == 0 else (Color(0.55, 0.30, 0.08) if dow == 6 else UITheme.INK_DARK)
			button.add_theme_color_override("font_color", day_fg)
			button.add_theme_color_override("font_hover_color", UITheme.INK_DARK)
			button.add_theme_stylebox_override("normal", _make_day_style(Color(0.97, 0.94, 0.88, 0.94), Color(0.28, 0.22, 0.18, 0.78), 1, 3, 5))
			button.add_theme_stylebox_override("hover", _make_day_style(Color(1.0, 0.98, 0.94, 1.0), ink_border, 2, 3, 5))
			button.add_theme_stylebox_override("pressed", _make_day_style(Color(0.90, 0.86, 0.78, 1.0), ink_border, 2, 1, 5))
			
		button.mouse_entered.connect(func(): AudioManager.play_sfx("hover"))
		button.pressed.connect(_on_day_pressed.bind(day))
		grid.add_child(button)
		
	var total_cells: int = start_weekday + days_in_month
	var trailing_empty: int = (7 - (total_cells % 7)) % 7
	for _trail_idx in range(trailing_empty):
		grid.add_child(_create_empty_calendar_slot())

func _on_day_pressed(day: int) -> void:
	AudioManager.play_sfx("click")
	_auto_save_current_note()
	day_of_entry = day
	update_ui()

func replace_notes() -> void:
	notes.text = PlannerManager.get_entry(month_of_entry, day_of_entry)

func replace_events() -> void:
	if not event_label:
		return
	var recorded := PlannerManager.get_recorded_events(month_of_entry, day_of_entry)
	if recorded != "":
		recorded = recorded.replace("[color=green]", "[color=#1b5e20]").replace("[color=red]", "[color=#8b1e1e]")
		recorded = recorded.replace("[color=yellow]", "[color=#7a4900]").replace("[color=orange]", "[color=#8b4000]")
		recorded = recorded.replace("[color=aqua]", "[color=#0d47a1]").replace("[color=lightblue]", "[color=#1a3c6e]")
		recorded = recorded.replace("[color=gray]", "[color=#5c4d3c]")
	var upcoming := PlannerManager.get_upcoming_milestones(month_of_entry, day_of_entry)
	var parts: Array[String] = []
	
	if upcoming != "":
		parts.append("[b][color=#6e3b10]Paalala at Iskedyul:[/color][/b]\n" + upcoming)
	if recorded != "":
		parts.append("[b][color=#1b4332]Naganap na mga Aksyon:[/color][/b]\n" + recorded)
		
	if parts.is_empty():
		event_label.text = "[color=#5c4d3c]Walang nakatalang ganap o paalala sa araw na ito.[/color]\n[font_size=13][i][color=#6e5a44]Tip: Magtala sa ibaba para sa sariling budget notes.[/color][/i][/font_size]"
	else:
		event_label.text = "\n\n".join(parts)

func finish_notes() -> void:
	AudioManager.play_sfx("soft_chime")
	var date: int = day_of_entry
	var month: int = month_of_entry
	var current_notes: String = notes.text
	PlannerManager.save_entry(month, date, current_notes)
	make_buttons_for_month()

func _on_previous_month_pressed() -> void:
	if month_of_entry > 0:
		AudioManager.play_sfx("paper")
		_auto_save_current_note()
		month_picker -= 1
		day_of_entry = 1
		update_ui()

func _on_next_month_pressed() -> void:
	if month_of_entry < 11:
		AudioManager.play_sfx("paper")
		_auto_save_current_note()
		month_picker += 1
		day_of_entry = 1
		update_ui()
