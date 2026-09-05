extends Node2D

@onready var timer = $Timer
@onready var label = $Label
@onready var interface = $"."

var event_occurance = RandomNumberGenerator.new()
var event_day = 0

func update_ui() -> void:
	label.text = TimeCycle.year[TimeCycle.current_month].month + " " + str(TimeCycle.current_day) + " " + TimeCycle.Phase.keys()[TimeCycle.current_phase]
	pass

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

#Temporary handling of events. May be turned in another GDscript in future iterations
func event_handler() -> void:
	if (event_day <= 0): stop_cycle() 
	event_day -= 1
	print(int (event_day/3))
	pass

func start_cycle() -> void:
	update_ui()
	timer.start()
	interface.visible = true
	event_day = event_occurance.randi_range(4,7) * 3 #*3 to include the three phases
	pass # Replace with function body.

func stop_cycle() -> void:
	timer.stop()
	interface.visible = false

#Every timer tick, do this:
func _on_timer_timeout() -> void:
	update_ui()
	event_handler()
	TimeCycle.next_phase()
	pass # Replace with function body.

# Temporary button for phone interface. To end the day and start the timer.
func _on_end_day_pressed() -> void:
	start_cycle()
	pass # Replace with function body.
