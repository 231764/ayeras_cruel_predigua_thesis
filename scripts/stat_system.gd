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
			_show_notification_warning()
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

func _show_notification_warning() -> void:
	# Show an AcceptDialog warning
	var dialog = AcceptDialog.new()
	dialog.title = "Unread Notifications"
	dialog.dialog_text = "You cannot end the day. You have unread notifications on your phone!"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	
	# Make the phone button flash
	var main_scene = get_tree().current_scene
	if main_scene:
		var phone_btn = main_scene.find_child("Phone Button", true, false)
		if phone_btn:
			var tween = create_tween()
			tween.tween_property(phone_btn, "modulate", Color(1, 0, 0, 1), 0.2)
			tween.tween_property(phone_btn, "modulate", Color(1, 1, 1, 1), 0.2)
			tween.tween_property(phone_btn, "modulate", Color(1, 0, 0, 1), 0.2)
			tween.tween_property(phone_btn, "modulate", Color(1, 1, 1, 1), 0.2)

func daily_cycle() -> void:
	# Process daily living costs before moving to the next day
	process_daily_expenses()
	
	StatManager.current_day += 1
	if (StatManager.year[StatManager.current_month].days < StatManager.current_day):
		StatManager.current_day = 1
		if (StatManager.year[StatManager.current_month].month == "December"):
			StatManager.current_month = 0
		else: StatManager.current_month += 1
		
	# Check for Salary (Day 1 and Day 15)
	if StatManager.current_day == 1 or StatManager.current_day == 15:
		receive_salary()
		
	print("New Day: " + StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day))
	update_ui()
	
func receive_salary() -> void:
	var salary_amount = 12500
	StatManager.current_balance += salary_amount
	
	var dialog = AcceptDialog.new()
	dialog.title = "Payday!"
	dialog.dialog_text = "You received your salary of PHP " + str(salary_amount) + "!"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	
func process_daily_expenses() -> void:
	# Food: 0 = Cook (350), 1 = Eat Out (600)
	if StatManager.daily_food_choice == 0:
		StatManager.spend_from_category("Food", 350)
		StatManager.happy -= 1
	else:
		StatManager.spend_from_category("Food", 600)
		StatManager.happy += 1
		
	# Commute: 0 = Public Transit (100), 1 = Mototaxi (200)
	if StatManager.daily_commute_choice == 0:
		StatManager.spend_from_category("Transportation", 100)
		StatManager.happy -= 1
	else:
		StatManager.spend_from_category("Transportation", 200)
		StatManager.happy += 1
		
	# Clamp happiness
	StatManager.happy = clamp(StatManager.happy, 0, 100)
	
func _on_food_option_selected(index: int) -> void:
	StatManager.daily_food_choice = index

func _on_commute_option_selected(index: int) -> void:
	StatManager.daily_commute_choice = index

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# UI update is now driven by events and phase changes rather than every frame
	pass
#func stat_event_handler() this could be its own script... but thats for a later update
# for events, it will tackle with 2 or more stats. using the functions above, it will


func _on_button_pressed() -> void:
	print("You added so much money!")	
	happy_calc(5)
	pass # Replace with function body.
