extends Node2D

var current_envelope = 0

func next_envelope() -> void:
	current_envelope += 1
	if current_envelope >= StatManager.envelopes.size():
		current_envelope = 0
	update_envelope()
	
func previous_envelope() -> void:
	current_envelope -= 1
	if current_envelope < 0:
		current_envelope = StatManager.envelopes.size() - 1
	update_envelope()
	
func update_envelope() -> void:
	var envelope = StatManager.envelopes[current_envelope]
	var category = envelope["category"]
	var amount = envelope["amount"]
	var display_name = envelope["display_name"]
	$Envelope.setup(category, amount, display_name)

func _ready() -> void:
	StatManager.on_stats_changed.connect(update_envelope)
	visibility_changed.connect(func():
		if visible:
			update_envelope()
	)
	update_envelope()

func _on_left_button_pressed() -> void:
	previous_envelope()

func _on_right_button_pressed() -> void:
	next_envelope()
