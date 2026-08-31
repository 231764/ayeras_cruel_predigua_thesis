extends Button

var current_interface

@onready var button = $"../Back Button"
func set_interface(interface):
	current_interface = interface
	print(current_interface)

func _on_pressed():
	if current_interface:
		current_interface.visible = false	
	button.visible = false;

		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.pressed.connect(_on_pressed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
