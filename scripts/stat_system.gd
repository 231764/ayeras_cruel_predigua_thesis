extends Node2D

@export var happy_bar: ProgressBar
@export var social_bar: ProgressBar
@export var current_balance: Label
@export var savings: Label
@export var credit_balance: Label
@export var credit_score: Label
@export var debt_balance: Label


func _ready() -> void:
# stats are to be handled in a seperate GDScript, for now, they are temporary.
# ex. in stat_manager.gd, the values would be like 
	update_ui()
	#powerLabel.text = "%d / %d" % [StatManager.power, maxPower]
	#allyProgBar.value = StatManager.allies
	#allyLabel.text = "%d / %d" % [StatManager.allies, maxAllies]

func update_ui() -> void:
	happy_bar.value = StatManager.happy;
	social_bar.value = StatManager.social;
	current_balance.text = "PHP" + str(StatManager.current_balance);
	savings.text = "PHP" + str(StatManager.savings);
	credit_balance.text = "PHP" + str(StatManager.credit_balance);
	credit_score.text = str(StatManager.credit_score);
	debt_balance.text = "PHP" + str(StatManager.debt_balance);

func happy_calc(amount: int) -> void:
	StatManager.happy += amount
	
func social_calc(amount: int) -> void:
	StatManager.social += amount
	
func current_balance_calc(amount: int) -> void:
	StatManager.current_balance += amount
	
func savings_calc(amount: int) -> void:
	StatManager.savings += amount
	
func credit_balance_calc(amount: int) -> void:
	StatManager.credit_balance += amount
	
func credit_score_calc(amount: int) -> void:
	StatManager.credit_score += amount

func debt_calc(amount: int) -> void:
	StatManager.debt += amount

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_ui()
	pass

#func stat_event_handler() this could be its own script... but thats for a later update
# for events, it will tackle with 2 or more stats. using the functions above, it will


func _on_button_pressed() -> void:
	print("You added so much money!")	
	happy_calc(5)
	pass # Replace with function body.
