extends Node2D

@export var happy_bar: ProgressBar
@export var social_bar: ProgressBar
@export var current_balance: Label
@export var savings: Label
@export var credit_balance: Label
@export var credit_score: Label
@export var debt_balance: Label
@export var date_label: Label

@onready var next_phase_button: Button = $NextPhaseButton


func _ready() -> void:
	update_ui()
	EventManager.call_deferred("evaluate_daily_events")
	StatManager.on_stats_changed.connect(update_ui)
	
	EventManager.on_direct_event_triggered.connect(func(event_data): 
		if next_phase_button: next_phase_button.visible = false
	)
	
	EventManager.on_event_resolved.connect(func(id): 
		update_ui()
		if next_phase_button: next_phase_button.visible = true
	)
	
	# Initial salary for the very first day
	if StatManager.current_day == 1 and StatManager.current_month == 0:
		call_deferred("receive_salary")

func spawn_dialog(dialog: AcceptDialog) -> void:
	if next_phase_button:
		next_phase_button.visible = false
	add_child(dialog)
	dialog.popup_centered()
	
	# Connect to both confirmed and canceled to clean up and re-enable button
	dialog.confirmed.connect(func():
		if next_phase_button:
			next_phase_button.visible = true
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		if next_phase_button:
			next_phase_button.visible = true
		dialog.queue_free()
	)

func update_ui() -> void:
	happy_bar.value = StatManager.happy;
	social_bar.value = StatManager.social;
	if current_balance:
		current_balance.text = "PHP" + str(StatManager.current_balance)
	if savings:
		savings.text = "PHP" + str(StatManager.savings)
	if credit_balance:
		credit_balance.text = "PHP" + str(StatManager.credit_balance)
	if credit_score:
		credit_score.text = str(StatManager.credit_score)
	if debt_balance:
		debt_balance.text = "PHP" + str(StatManager.debt_balance)
	
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
	dialog.dialog_text = "Hindi pwedeng matapos ang araw nang may unread notifications ka sa phone!"
	spawn_dialog(dialog)
	
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
	
	check_game_over_conditions()
	
	# Check for Weekly Summary BEFORE incrementing day
	if StatManager.current_day == 7 or StatManager.current_day == 14 or StatManager.current_day == 21 or StatManager.current_day == 28:
		trigger_weekly_summary(StatManager.current_day / 7)
		
	# Check for Monthly Bills
	if StatManager.current_day == StatManager.year[StatManager.current_month].days:
		trigger_monthly_bills()
	
	StatManager.current_day += 1
	if (StatManager.year[StatManager.current_month].days < StatManager.current_day):
		StatManager.current_day = 1
		if (StatManager.year[StatManager.current_month].month == "December"):
			trigger_game_over("CONGRATULATIONS!\n\nNaka-survive ka ng isang buong taon! Abangan ang next updates para sa iyong Final Score!")
			return
		else: 
			StatManager.current_month += 1
		
	# Check for Salary (Day 1 and Day 15)
	if StatManager.current_day == 1 or StatManager.current_day == 15:
		receive_salary()
		
	print("New Day: " + StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day))
	update_ui()
	
func receive_salary() -> void:
	var base_salary = 12500
	var salary_amount = base_salary
	var garnished_amount = 0
	
	if StatManager.debt_balance > 0:
		var max_garnish = int(base_salary * 0.5)
		if StatManager.debt_balance <= max_garnish:
			garnished_amount = StatManager.debt_balance
		else:
			garnished_amount = max_garnish
			
		StatManager.debt_balance -= garnished_amount
		salary_amount -= garnished_amount

	StatManager.current_balance += salary_amount
	StatManager.weekly_income += salary_amount
	StatManager.on_stats_changed.emit()
	
	var dialog = AcceptDialog.new()
	dialog.title = "Sahod Day!"
	var text = "Pumasok na ang sahod mo na PHP " + str(base_salary) + "!"
	var log_text = "Sahod Day! (+ PHP " + str(base_salary) + ")"
	if garnished_amount > 0:
		text += "\n\nPero kinuha ng banko ang PHP " + str(garnished_amount) + " para pambayad sa utang mo!"
		text += "\nAng natira sa iyo ay PHP " + str(salary_amount) + "."
		log_text += "\n[font_size=12][color=red]-" + str(garnished_amount) + " PHP Kaltas Utang[/color][/font_size]"
		
	dialog.dialog_text = text
	spawn_dialog(dialog)
	PlannerManager.record_event(StatManager.current_month, StatManager.current_day, log_text)
	
func trigger_weekly_summary(week_num: int) -> void:
	var weekly_summary_scene = preload("res://scenes/weekly_summary.tscn")
	var summary_instance = weekly_summary_scene.instantiate()
	add_child(summary_instance)
	summary_instance.show_summary(week_num)
	
	if next_phase_button:
		next_phase_button.visible = false
	summary_instance.summary_closed.connect(func():
		if next_phase_button:
			next_phase_button.visible = true
		summary_instance.queue_free()
	)

func trigger_monthly_bills() -> void:
	# Apply 5% interest to existing debt
	var interest = int(StatManager.debt_balance * 0.05)
	if interest > 0:
		StatManager.debt_balance += interest
		
	var rent_amount = 10000
	var utilities_amount = 3000
	var total_bills = rent_amount + utilities_amount
	
	var initial_debt = StatManager.debt_balance
	
	StatManager.spend_from_category("Rent", rent_amount)
	StatManager.spend_from_category("Utilities", utilities_amount)
	
	var final_debt = StatManager.debt_balance
	var new_debt_incurred = final_debt - initial_debt
	
	if new_debt_incurred > 0:
		# Player went into debt
		var dialog = AcceptDialog.new()
		dialog.title = "Naku, Nagka-utang ka!"
		var text = "Nagbayad ka ng monthly bills (PHP " + str(total_bills) + "), pero kulang pondo mo!\n\nNadagdag ang PHP " + str(new_debt_incurred) + " sa utang mo."
		var log_text = "Monthly Bills [- PHP " + str(total_bills) + "] (Kulang pondo, utang +" + str(new_debt_incurred) + ")"
		if interest > 0:
			text += "\n\nMay penalty pa na PHP " + str(interest) + " interest sa dati mong utang."
			log_text += "\n[font_size=12][color=red]Interest Penalty -" + str(interest) + " PHP[/color][/font_size]"
		text += "\n\nMay 5% Interest na papatong kada buwan sa di mo nabayarang utang!"
		dialog.dialog_text = text
		dialog.ok_button_text = "Naiintindihan ko"
		spawn_dialog(dialog)
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, log_text)
	else:
		# Paid successfully
		var dialog = AcceptDialog.new()
		dialog.title = "Bayad na ang Bills!"
		var text = "Bayad na ang monthly bills mo:\nUpa: PHP 10,000\nKuryente/Tubig: PHP 3,000"
		var log_text = "Monthly Bills Paid! [- PHP " + str(total_bills) + "]"
		if interest > 0:
			text += "\n\nPero may binayaran ka ring PHP " + str(interest) + " na interest galing sa utang mo."
			log_text += "\n[font_size=12][color=red]Interest Penalty -" + str(interest) + " PHP[/color][/font_size]"
		dialog.dialog_text = text
		spawn_dialog(dialog)
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, log_text)
	
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
	
func check_game_over_conditions() -> void:
	if StatManager.debt_balance > 50000:
		trigger_game_over("GAME OVER: Baon sa utang! (Lagpas PHP 50,000 na ang utang mo)")
		return
		
	if StatManager.happy <= 0:
		StatManager.days_at_zero_happiness += 1
	else:
		StatManager.days_at_zero_happiness = 0
		
	if StatManager.social <= 0:
		StatManager.days_at_zero_social += 1
	else:
		StatManager.days_at_zero_social = 0
		
	if StatManager.days_at_zero_happiness >= 5:
		trigger_game_over("GAME OVER: Na-burnout ka dahil 5 days ka nang walang happiness. Need mo mag-unwind!")
		return
		
	if StatManager.days_at_zero_social >= 5:
		trigger_game_over("GAME OVER: Na-isolate mo na sarili mo for 5 days. Ingatan ang mental health!")
		return

func trigger_game_over(reason: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "GAME OVER"
	dialog.dialog_text = reason
	if next_phase_button:
		next_phase_button.visible = false
	add_child(dialog)
	dialog.popup_centered()
	# Quit game when closed
	dialog.confirmed.connect(func(): get_tree().quit())
	
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
