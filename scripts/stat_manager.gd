extends Node

var happy := 50 #starting happy value 
var social := 50 #starting social value
var current_balance := 5000 #starting current balance value
var savings := 50 #starting savings value
var credit_score := 50 #starting credit score value
var credit_balance := 10 #starting credit balance value
var debt_balance := 50 #starting debt value

# For the BUDGETTING aspect
var envelopes := [
	{"category": "Food", "amount": 0},
	{"category": "Transportation", "amount": 0},
	{"category": "Entertainment", "amount": 0}
]

# For the CYCLES aspect

var current_day := 1
var current_month := 0
var current_phase := 0 # 0 = Morning, 1 = Afternoon, 2 = Evening
var year := [
	{"month": "January", "days": 31},
	{"month": "February", "days": 29},
	{"month": "March", "days": 31},
	{"month": "April", "days": 30},
	{"month": "May", "days": 31},
	{"month": "June", "days": 30},
	{"month": "July", "days": 31},
	{"month": "August", "days": 31},
	{"month": "September", "days": 30},
	{"month": "October", "days": 31},
	{"month": "November", "days": 30},
	{"month": "December", "days": 31},
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
