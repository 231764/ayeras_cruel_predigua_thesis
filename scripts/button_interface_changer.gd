extends TextureButton

@export var button = TextureButton
@export var interface = Node2D
@onready var back_button = $"../Back Button"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.pressed.connect(_button_pressed)
	pass # Replace with function body.

func _button_pressed() -> void:
	if back_button.visible:
		return
		
	print("You pressed " + button.name)	
	interface.visible = true
	back_button.visible = true
	back_button.set_interface(interface)
	
	for child in get_parent().get_children():
		if child is TextureButton and child.name.ends_with("Button"):
			child.disabled = true
		if child is Label and child.name.ends_with("Label"):
			child.visible = false
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
