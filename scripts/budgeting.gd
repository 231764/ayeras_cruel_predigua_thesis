extends Node2D

var current_envelope = 0

func next_envelope():
	current_envelope += 1
	
	if current_envelope >= StatManager.envelopes.size():
		current_envelope = 0
	
	update_envelope()
	
func previous_envelope():
	current_envelope -= 1
	
	if current_envelope < 0:
		current_envelope = StatManager.envelopes.size() - 1
	
	update_envelope()
	
func update_envelope():
	var envelope = StatManager.envelopes[current_envelope]
	var category = envelope["category"]
	var amount = envelope["amount"]
	$Envelope.setup(category, amount)	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_envelope()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_left_button_pressed() -> void:
	previous_envelope()
	pass # Replace with function body.


func _on_right_button_pressed() -> void:
	next_envelope()
	pass # Replace with function body.
