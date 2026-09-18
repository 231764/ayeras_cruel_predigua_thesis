extends Node2D

@export var happy_bar: ProgressBar
@export var social_bar: ProgressBar
@export var current_balance: Label
@export var savings: Label
@export var credit_balance: Label
@export var credit_score: Label
@export var debt_balance: Label
@export var date_label: Label


func _ready() -> void:
	update_ui()
	EventManager.call_deferred("evaluate_daily_events")

func update_ui() -> void:
	happy_bar.value = StatManager.happy;
	social_bar.value = StatManager.social;
	current_balance.text = "PHP" + str(StatManager.current_balance);
	savings.text = "PHP" + str(StatManager.savings);
	credit_balance.text = "PHP" + str(StatManager.credit_balance);
	credit_score.text = str(StatManager.credit_score);
	debt_balance.text = "PHP" + str(StatManager.debt_balance);
	
	var phase_names = ["Morning", "Afternoon", "Evening"]
	if date_label:
		date_label.text = StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day) + " - " + phase_names[StatManager.current_phase]

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

func advance_phase() -> void:
	if EventManager.is_direct_event_active:
		print("Cannot advance phase while an event is active!")
		return
		
	if StatManager.current_phase == 2: # Evening
		# Check if there are active indirect events
		if EventManager.active_events.size() > 0:
			print("Cannot end day. You have unread notifications!")
			return # Block advancing
		
		# Move to next day
		StatManager.current_phase = 0
		daily_cycle()
	else:
		StatManager.current_phase += 1
	
	update_ui()
	print("Phase advanced. Current Phase: ", StatManager.current_phase)
	
	# Automatically trigger any events scheduled for this day/phase
	EventManager.evaluate_daily_events()

func daily_cycle() -> void:
	StatManager.current_day += 1
	if (StatManager.year[StatManager.current_month].days < StatManager.current_day):
		StatManager.current_day = 1
		if (StatManager.year[StatManager.current_month].month == "December"):
			StatManager.current_month = 0
		else: StatManager.current_month += 1
	print("New Day: " + StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day))

#func stat_event_handler() this could be its own script... but thats for a later update
# for events, it will tackle with 2 or more stats. using the functions above, it will


func _on_button_pressed() -> void:
	print("You added so much money!")	
	happy_calc(5)
	pass # Replace with function body.
