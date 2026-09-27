extends Node2D


@onready var grid = $GridContainer
@onready var dateLabel = $"Date Label"
@onready var notes = $Notes
@onready var dayLabel = $"Day Label"
@onready var event_label = $Events/"Event Label"

var day_of_entry = 1;
var month_of_entry = 0;
var month_picker = 0;

func _ready():
	visibility_changed.connect(_on_visibility_changed)
	if visible:
		_on_visibility_changed()

func _on_visibility_changed() -> void:
	if visible:
		day_of_entry = StatManager.current_day
		month_picker = 0
		update_ui()

func update_ui() -> void:
	month_of_entry = StatManager.current_month + month_picker
	dayLabel.text = str(day_of_entry)
	dateLabel.text = str(StatManager.year[month_of_entry].month)
	make_buttons_for_month()
	replace_notes()
	replace_events()
	
func make_buttons_for_month() -> void:
	#Get the number of days for the current month
	var days_in_month = StatManager.year[month_of_entry].days
	
	#Remove existing day buttons
	for child in grid.get_children():
		child.queue_free()
	
	#Create buttons for each day
	for day in range(1, days_in_month + 1):
		var button = Button.new()
		button.text = str(day)
		button.custom_minimum_size = Vector2(50, 50)
		
		# Highlight current date
		if day == StatManager.current_day and month_of_entry == StatManager.current_month:
			button.add_theme_color_override("font_color", Color.YELLOW)
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0, 0.4, 0.2)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			
		button.pressed.connect(_on_day_pressed.bind(day))
		grid.add_child(button)

func _on_day_pressed(day: int) -> void:
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
	var date : int = day_of_entry
	var month : int = month_of_entry
	var current_notes : String = notes.text 
	PlannerManager.save_entry(month, date, current_notes)
	

func _on_previous_month_pressed() -> void:
	if month_of_entry > 0:
		month_picker -= 1
		day_of_entry = 1 #Reset to Day1 by default
		update_ui()


func _on_next_month_pressed() -> void:
	if month_of_entry < 11:
		month_picker += 1
		day_of_entry = 1
		update_ui()
