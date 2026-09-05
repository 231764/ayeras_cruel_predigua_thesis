extends Node2D

@onready var timer = $Timer
@onready var label = $Label


func update_ui() -> void:
	label.text = TimeCycle.year[TimeCycle.current_month].month + " " + str(TimeCycle.current_day) + " " + TimeCycle.Phase.keys()[TimeCycle.current_phase]
	pass

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.start()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	update_ui()
	TimeCycle.next_phase()
	pass # Replace with function body.
