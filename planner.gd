extends Node2D

@onready var grid = $GridContainer
@onready var dateLabel = $"Date Label"
@onready var notes = $Notes
@onready var dayLabel = $"Day Label"
@onready var event_label = $Events/"Event Label"

var day_of_entry = 1
var month_of_entry = 0
var month_picker = 0
var _is_initialized: bool = false

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if visible:
		_on_visibility_changed()

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
	dayLabel.text = StatManager.year[month_of_entry].month + " " + str(day_of_entry)
	dateLabel.text = str(StatManager.year[month_of_entry].month)
	make_buttons_for_month()
	replace_notes()
	replace_events()
	
func make_buttons_for_month() -> void:
	# Get the number of days for the current month
	var days_in_month = StatManager.year[month_of_entry].days
	
	# Remove existing day buttons immediately from GridContainer before freeing
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	
	# Create buttons for each day
	for day in range(1, days_in_month + 1):
		var button = Button.new()
		var has_ev = PlannerManager.has_events_on_day(month_of_entry, day)
		var has_nt = PlannerManager.has_notes_on_day(month_of_entry, day)
		
		var marker = ""
		if has_ev and has_nt:
			marker = " ★*"
		elif has_ev:
			marker = " •"
		elif has_nt:
			marker = " *"
			
		button.text = str(day) + marker
		button.custom_minimum_size = Vector2(50, 50)
		
		var is_today = (day == StatManager.current_day and month_of_entry == StatManager.current_month)
		var is_selected = (day == day_of_entry)
		
		if is_today:
			button.add_theme_color_override("font_color", Color.YELLOW)
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.0, 0.45, 0.22)
			if is_selected:
				style.border_width_left = 2
				style.border_width_top = 2
				style.border_width_right = 2
				style.border_width_bottom = 2
				style.border_color = Color.WHITE
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
		elif is_selected:
			var sel_style = StyleBoxFlat.new()
			sel_style.bg_color = Color(0.28, 0.24, 0.22)
			sel_style.border_width_left = 2
			sel_style.border_width_top = 2
			sel_style.border_width_right = 2
			sel_style.border_width_bottom = 2
			sel_style.border_color = Color(0.95, 0.8, 0.3)
			button.add_theme_stylebox_override("normal", sel_style)
		elif has_ev or has_nt:
			button.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
			
		button.pressed.connect(_on_day_pressed.bind(day))
		grid.add_child(button)

func _on_day_pressed(day: int) -> void:
	_auto_save_current_note()
	day_of_entry = day
	update_ui()

func replace_notes() -> void:
	notes.text = PlannerManager.get_entry(month_of_entry, day_of_entry)

func replace_events() -> void:
	if event_label:
		var recorded = PlannerManager.get_recorded_events(month_of_entry, day_of_entry)
		if recorded == "":
			event_label.text = "Mga Ganap:\nWalang ganap."
		else:
			event_label.text = "Mga Ganap:\n" + recorded

func finish_notes() -> void:
	var date: int = day_of_entry
	var month: int = month_of_entry
	var current_notes: String = notes.text
	PlannerManager.save_entry(month, date, current_notes)
	make_buttons_for_month()

func _on_previous_month_pressed() -> void:
	if month_of_entry > 0:
		_auto_save_current_note()
		month_picker -= 1
		day_of_entry = 1
		update_ui()

func _on_next_month_pressed() -> void:
	if month_of_entry < 11:
		_auto_save_current_note()
		month_picker += 1
		day_of_entry = 1
		update_ui()
