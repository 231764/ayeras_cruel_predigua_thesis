extends TextureButton

@export var button = TextureButton;
@export var interface = Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.pressed.connect(_button_pressed)
	pass # Replace with function body.

func _button_pressed() -> void:
	print("You pressed " + button.name)	
	interface.visible = true;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
