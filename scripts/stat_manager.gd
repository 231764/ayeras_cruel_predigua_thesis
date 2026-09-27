extends Node

signal on_stats_changed

var happy := 50 #starting happy value 
var social := 50 #starting social value
var current_balance := 5000 #starting current balance value
var savings := 50 #starting savings value
var credit_score := 50 #starting credit score value
var credit_balance := 10 #starting credit balance value
var debt_balance := 0 #starting debt value

# For the BUDGETTING aspect
var envelopes := [
	{"category": "Food", "display_name": "Pagkain\n(Food)", "amount": 0},
	{"category": "Transportation", "display_name": "Pamasahe\n(Transportation)", "amount": 0},
	{"category": "Entertainment", "display_name": "Libangan\n(Entertainment)", "amount": 0},
	{"category": "Rent", "display_name": "Upa\n(Rent)", "amount": 0},
	{"category": "Utilities", "display_name": "Kuryente/Tubig\n(Utilities)", "amount": 0}
]

var daily_food_choice: int = 0 # 0 = Cook (350), 1 = Eat Out (600)
var daily_commute_choice: int = 0 # 0 = Public (100), 1 = Mototaxi (200)

var days_at_zero_happiness: int = 0
var days_at_zero_social: int = 0

# For the CYCLES aspect

var current_day := 1
var current_month := 0
var current_phase := 0 # 0 = Morning, 1 = Afternoon, 2 = Evening
var year := [
	{"month": "January", "days": 31},
	{"month": "February", "days": 28},
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

var weekly_income: int = 0
var weekly_expenses: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func spend_from_category(category_name: String, amount: int) -> void:
	weekly_expenses += amount
	# Try to pull from envelope first
	for envelope in envelopes:
		if envelope["category"] == category_name:
			if envelope["amount"] >= amount:
				envelope["amount"] -= amount
				return
			else:
				# Envelope exists but doesn't have enough, drain it and pull rest from current_balance
				var remaining = amount - envelope["amount"]
				envelope["amount"] = 0
				current_balance -= remaining
				
				# Handle Debt roll-over if current balance goes below 0
				if current_balance < 0:
					debt_balance += abs(current_balance)
					current_balance = 0
				return
	
	# If no envelope found, pull from current_balance
	current_balance -= amount
	# Handle Debt roll-over if current balance goes below 0
	if current_balance < 0:
		debt_balance += abs(current_balance)
		current_balance = 0
		
	on_stats_changed.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
