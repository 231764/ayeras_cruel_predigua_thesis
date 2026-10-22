extends Button

var current_interface

@onready var button = $"../Back Button"

func set_interface(interface) -> void:
	current_interface = interface

func _on_pressed() -> void:
	if current_interface:
		current_interface.visible = false
	button.visible = false
	
	for child in get_parent().get_children():
		if child is TextureButton and child.name.ends_with("Button"):
			child.disabled = false
		if child is Label and child.name.ends_with("Label"):
			child.visible = true
		if child.name == "Stat System":
			child.visible = true

func _ready() -> void:
	if button and not button.pressed.is_connected(_on_pressed):
		button.pressed.connect(_on_pressed)

func _process(_delta: float) -> void:
	pass
