extends Button

var current_interface

@onready var button = $"../Back Button"
func set_interface(interface):
	current_interface = interface
	print(current_interface)

func _on_pressed():
	if current_interface:
		current_interface.visible = false	
	button.visible = false
	
	for child in get_parent().get_children():
		if child is TextureButton and child.name.ends_with("Button"):
			child.disabled = false
		if child is Label and child.name.ends_with("Label"):
			child.visible = true

		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.pressed.connect(_on_pressed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
