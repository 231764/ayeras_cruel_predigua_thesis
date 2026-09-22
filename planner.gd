extends Node2D


@onready var grid = $GridContainer
@onready var dateLabel = $"Date Label"
@onready var notes = $Notes
@onready var dayLabel = $"Day Label"

var day_of_entry = 1;
var month_of_entry = 0;
var month_picker = 0;

func _ready():
	update_ui()

func update_ui() -> void:
	month_of_entry = TimeCycle.current_month + month_picker
	dayLabel.text = str(day_of_entry)
	dateLabel.text = str(TimeCycle.year[month_of_entry].month)
	make_buttons_for_month()
	replace_notes()
	
func make_buttons_for_month() -> void:
	#Get the number of days for the current month
	var days_in_month = TimeCycle.year[month_of_entry].days
	
	#Remove existing day buttons
	for child in grid.get_children():
		child.queue_free()
	
	#Create buttons for each day
	for day in range(1, days_in_month + 1):
		var button = Button.new()
		button.text = str(day)
		button.custom_minimum_size = Vector2(50, 50)
		button.pressed.connect(_on_day_pressed.bind(day))
		grid.add_child(button)

func _on_day_pressed(day: int) -> void:
	day_of_entry = day
	update_ui()
	#Change events (if they exist) that happen on the day it happened || REPLACE_EVENTS

	pass

func replace_notes() -> void:
	notes.text = PlannerManager.get_entry(month_of_entry, day_of_entry)
	pass

func replace_events() -> void:
	pass


func finish_notes() -> void:
	var date : int = day_of_entry
	var month : int = month_of_entry
	var current_notes : String = notes.text 
	PlannerManager.save_entry(month, date, current_notes)
	

func _on_previous_month_pressed() -> void:
	month_picker -= 1
	if (month_picker < -11):
		month_picker = 0
	day_of_entry = 1 #Reset to Day1 by default
	update_ui()
	pass # Replace with function body.


func _on_next_month_pressed() -> void:
	month_picker += 1
	if (month_picker > 11):
		month_picker = 0
	day_of_entry = 1
	update_ui()
	pass # Replace with function body.
