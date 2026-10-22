extends TextureButton

@export var button: TextureButton
@export var interface: Node2D
@onready var back_button = $"../Back Button"

func _ready() -> void:
	if button and not button.pressed.is_connected(_button_pressed):
		button.pressed.connect(_button_pressed)

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
		if child.name == "Stat System":
			child.visible = false

func _process(_delta: float) -> void:
	pass
