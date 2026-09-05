extends Node

var happy := 50 #starting happy value 
var social := 50 #starting social value
var current_balance := 5000 #starting current balance value
var savings := 50 #starting social value
var credit_score := 50 #starting social value
var credit_balance := 10 #starting social value
var debt_balance := 50 #starting social value

# For the BUDGETTING aspect
var envelopes := [
	{"category": "Food", "amount": 0},
	{"category": "Transportation", "amount": 0},
	{"category": "Entertainment", "amount": 0}
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
