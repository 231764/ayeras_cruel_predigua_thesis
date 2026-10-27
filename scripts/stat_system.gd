extends Node2D

@export var happy_bar: ProgressBar
@export var social_bar: ProgressBar
@export var current_balance: Label
@export var savings: Label
@export var credit_balance: Label
@export var credit_score: Label
@export var debt_balance: Label
@export var date_label: Label
@export var status_report_label: RichTextLabel

@onready var next_phase_button: Button = $NextPhaseButton
@onready var goal_button: Button = $GoalButton
@onready var savings_jar_button: Button = $SavingsJarButton
@onready var food_option: OptionButton = $DailyRoutinePanel/VBoxContainer/FoodHBox/FoodOption
@onready var commute_option: OptionButton = $DailyRoutinePanel/VBoxContainer/CommuteHBox/CommuteOption

var modal_queue: Array[Callable] = []
var is_modal_open: bool = false
var is_game_over: bool = false
var pending_desk_tool_to_open: String = ""

func _ready() -> void:
	update_ui()
	StatManager.on_stats_changed.connect(update_ui)
	
	EventManager.on_direct_event_triggered.connect(func(_event_data):
		_update_next_button_visibility()
	)
	
	EventManager.on_indirect_event_triggered.connect(func(_event_data):
		update_ui()
	)
	
	EventManager.on_event_resolved.connect(func(_id):
		update_ui()
		_update_next_button_visibility()
	)
	
	# Initial goal selection, salary, and event check for the very first day
	if StatManager.current_day == 1 and StatManager.current_month == 0 and StatManager.current_phase == 0:
		call_deferred("_start_initial_day")
	else:
		EventManager.call_deferred("evaluate_daily_events")

func _start_initial_day() -> void:
	if not StatManager.has_selected_goal:
		trigger_goal_selection()
	receive_salary()

func _update_next_button_visibility() -> void:
	if next_phase_button:
		next_phase_button.visible = (not EventManager.is_direct_event_active) and (not is_modal_open) and (not is_game_over)

func enqueue_modal(task: Callable) -> void:
	modal_queue.append(task)
	if not is_modal_open:
		_run_next_modal()

func _run_next_modal() -> void:
	if modal_queue.is_empty():
		is_modal_open = false
		_update_next_button_visibility()
		if not is_game_over:
			EventManager.evaluate_daily_events()
			if pending_desk_tool_to_open != "" and not EventManager.is_direct_event_active:
				var tool_to_open = pending_desk_tool_to_open
				pending_desk_tool_to_open = ""
				_open_desk_tool_by_name(tool_to_open)
		return
		
	is_modal_open = true
	_update_next_button_visibility()
	var next_task: Callable = modal_queue.pop_front()
	next_task.call()

func _open_desk_tool_by_name(tool_name: String) -> void:
	var parent_desk = get_parent()
	if not parent_desk:
		return
	if tool_name == "budget":
		var b_btn = parent_desk.get_node_or_null("Budget Button")
		if b_btn and b_btn.has_method("_button_pressed"):
			b_btn._button_pressed()
	elif tool_name == "planner":
		var p_btn = parent_desk.get_node_or_null("Planner Button")
		if p_btn and p_btn.has_method("_button_pressed"):
			p_btn._button_pressed()

func spawn_dialog(dialog: AcceptDialog) -> void:
	enqueue_modal(func():
		add_child(dialog)
		dialog.popup_centered()
		var closed := false
		var on_close = func():
			if closed:
				return
			closed = true
			dialog.hide()
			dialog.queue_free()
			_run_next_modal()
		dialog.confirmed.connect(on_close)
		dialog.canceled.connect(on_close)
	)

func trigger_goal_selection() -> void:
	enqueue_modal(func():
		var goal_scene = preload("res://scenes/goal_selection.tscn")
		var goal_instance = goal_scene.instantiate()
		add_child(goal_instance)
		goal_instance.show_goal_selection()
		goal_instance.goal_modal_closed.connect(func():
			goal_instance.visible = false
			goal_instance.queue_free()
			update_ui()
			_run_next_modal()
		)
	)

func open_savings_and_goal_inspector() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return
	enqueue_modal(func():
		var goal_scene = preload("res://scenes/goal_selection.tscn")
		var goal_instance = goal_scene.instantiate()
		add_child(goal_instance)
		goal_instance.show_savings_and_goal_inspector()
		goal_instance.goal_modal_closed.connect(func():
			goal_instance.visible = false
			goal_instance.queue_free()
			update_ui()
			_run_next_modal()
		)
	)

func update_ui() -> void:
	if happy_bar:
		happy_bar.value = StatManager.happy
	if social_bar:
		social_bar.value = StatManager.social
	if current_balance:
		current_balance.text = "PHP " + str(StatManager.current_balance)
	if savings:
		savings.text = "PHP " + str(StatManager.savings)
	if credit_balance:
		credit_balance.text = "PHP " + str(StatManager.credit_balance)
	if credit_score:
		credit_score.text = str(StatManager.credit_score)
	if debt_balance:
		debt_balance.text = "PHP " + str(StatManager.get_total_debt_and_loans())
	
	var phase_names = ["Morning", "Afternoon", "Evening"]
	if date_label:
		var notif_badge = ""
		if EventManager.active_events.size() > 0:
			notif_badge = "  [📱 " + str(EventManager.active_events.size()) + " Unread]"
		date_label.text = StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day) + " - " + phase_names[StatManager.current_phase] + notif_badge
		
	if goal_button:
		var g = StatManager.get_current_goal()
		var pct = StatManager.get_goal_progress_percent()
		goal_button.text = "🎯 " + str(g["title"]) + ": PHP " + str(StatManager.savings) + " / " + str(g["cost"]) + " (" + str(pct) + "%)"
		
	if savings_jar_button:
		savings_jar_button.text = "🏺 Ipon: PHP " + str(StatManager.savings) + " (+2%/mo)\n[Maghulog / Kumuha]"
		
	if food_option:
		var cook_cost = max(0, StatManager.food_costs[0] + StatManager.daily_food_modifier)
		var eatout_cost = max(0, StatManager.food_costs[1] + StatManager.daily_food_modifier)
		food_option.set_item_text(0, "Magluto (PHP " + str(cook_cost) + ")")
		food_option.set_item_text(1, "Mag-order (PHP " + str(eatout_cost) + ")")
		if food_option.selected != StatManager.daily_food_choice:
			food_option.selected = StatManager.daily_food_choice
			
	if commute_option:
		var pub_cost = max(0, StatManager.commute_costs[0] + StatManager.daily_commute_modifier)
		var moto_cost = max(0, StatManager.commute_costs[1] + StatManager.daily_commute_modifier)
		commute_option.set_item_text(0, "Jeep/Bus (PHP " + str(pub_cost) + ")")
		commute_option.set_item_text(1, "Angkas/Joyride (PHP " + str(moto_cost) + ")")
		if commute_option.selected != StatManager.daily_commute_choice:
			commute_option.selected = StatManager.daily_commute_choice
			
	_update_status_report()

func _update_status_report() -> void:
	if not status_report_label:
		return
	var stage_info = StatManager.get_stage_info()
	var g = StatManager.get_current_goal()
	var target = StatManager.get_goal_target()
	var pct = StatManager.get_goal_progress_percent()
	var total_util = StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
	var rent_env = StatManager.get_envelope_amount("Rent")
	var util_env = StatManager.get_envelope_amount("Utilities")
	var cc_env = StatManager.get_envelope_amount("Credit Card")
	var food_env = StatManager.get_envelope_amount("Food")
	var trans_env = StatManager.get_envelope_amount("Transportation")
	var ent_env = StatManager.get_envelope_amount("Entertainment")
	var total_debt_and_loans = StatManager.get_total_debt_and_loans()
	
	var goal_ok = "[color=green]REACHED (PHP " + str(StatManager.savings) + " / PHP " + str(target) + ")[/color]" if StatManager.savings >= target else "[color=yellow]PHP " + str(StatManager.savings) + " / PHP " + str(target) + " (" + str(pct) + "%)[/color]"
	var happy_ok = "[color=green]GOOD (" + str(StatManager.happy) + "/100)[/color]" if StatManager.happy >= 50 else "[color=red]LOW (" + str(StatManager.happy) + "/100 - Need >=50)[/color]"
	var social_ok = "[color=green]GOOD (" + str(StatManager.social) + "/100)[/color]" if StatManager.social >= 50 else "[color=red]LOW (" + str(StatManager.social) + "/100 - Need >=50)[/color]"
	var credit_ok = "[color=green]GOOD (" + str(StatManager.credit_score) + "/100)[/color]" if StatManager.credit_score >= 70 else "[color=red]POOR (" + str(StatManager.credit_score) + "/100 - Need >=70)[/color]"
	var debt_ok = "[color=green]DEBT-FREE (PHP 0)[/color]" if total_debt_and_loans == 0 and StatManager.credit_balance == 0 else "[color=red]HAS OBLIGATIONS (Debt/Loans: PHP " + str(total_debt_and_loans) + ", Credit: PHP " + str(StatManager.credit_balance) + ")[/color]"
	
	var txt = "[b][font_size=22]" + stage_info["name"] + "[/font_size][/b]\n"
	txt += "[i]\"" + stage_info["theme"] + "\"[/i]\n\n"
	txt += "[b]1. Year-End Victory Conditions Status:[/b]\n"
	txt += "• Employment Status: [color=yellow]" + StatManager.get_employment_display_text() + "[/color]\n"
	txt += "• Life Goal (" + str(g["title"]) + "): " + goal_ok + "\n"
	txt += "• Well-Being (Happiness): " + happy_ok + "\n"
	txt += "• Relationships (Sociability): " + social_ok + "\n"
	txt += "• Credit Standing: " + credit_ok + "\n"
	txt += "• Debt, Loans & Credit Status: " + debt_ok + "\n"
	txt += "• Savings Interest Earned: [color=lightblue]PHP " + str(StatManager.total_savings_interest_earned) + "[/color] | Investments: [color=aqua]PHP " + str(StatManager.get_total_investments()) + "[/color] (P&L: PHP " + str(StatManager.total_investment_gains) + ")\n\n"
	txt += "[b]2. Monthly Bills, Loans, Installments & Allocated Envelopes:[/b]\n"
	txt += "• Upa (Rent): PHP " + str(rent_env) + " / PHP " + str(StatManager.monthly_rent) + "\n"
	txt += "• Utilities + Installments + Family Support: PHP " + str(util_env) + " / PHP " + str(total_util) + " (Installments: " + StatManager.get_installments_summary_text() + ", Family Padala: PHP " + str(StatManager.monthly_family_support) + "/mo)\n"
	txt += "• Credit Card Envelope: PHP " + str(cc_env) + " (Card Balance: PHP " + str(StatManager.credit_balance) + " / Limit: PHP " + str(StatManager.credit_limit) + ")\n"
	txt += "• Active Simple Interest Loans: " + StatManager.get_loans_summary_text() + "\n"
	txt += "• Pagkain (Food): PHP " + str(food_env) + " | Pamasahe: PHP " + str(trans_env) + " | Libangan: PHP " + str(ent_env) + "\n"
	status_report_label.text = txt

func happy_calc(amount: int) -> void:
	StatManager.modify_happy(amount)
	
func social_calc(amount: int) -> void:
	StatManager.modify_social(amount)
	
func current_balance_calc(amount: int) -> void:
	StatManager.spend_direct(-amount)
	
func savings_calc(amount: int) -> void:
	StatManager.savings = max(0, StatManager.savings + amount)
	StatManager.sync_savings_envelope()
	StatManager.on_stats_changed.emit()
	
func credit_balance_calc(amount: int) -> void:
	StatManager.credit_balance = max(0, StatManager.credit_balance + amount)
	StatManager.on_stats_changed.emit()
	
func credit_score_calc(amount: int) -> void:
	StatManager.modify_credit_score(amount)

func debt_calc(amount: int) -> void:
	StatManager.debt_balance = max(0, StatManager.debt_balance + amount)
	StatManager.on_stats_changed.emit()

func advance_phase() -> void:
	if EventManager.is_direct_event_active or is_modal_open or is_game_over:
		print("Cannot advance phase while an event or modal is active!")
		return
		
	if StatManager.current_phase == 2: # Evening
		# Check if there are active indirect events
		if EventManager.active_events.size() > 0:
			print("Cannot end day. You have unread notifications!")
			_show_notification_warning()
			return
		
		# Move to next day
		StatManager.current_phase = 0
		daily_cycle()
		update_ui()
		if not is_modal_open and not is_game_over:
			EventManager.evaluate_daily_events()
	else:
		StatManager.current_phase += 1
		update_ui()
		print("Phase advanced. Current Phase: ", StatManager.current_phase)
		EventManager.evaluate_daily_events()

func _show_notification_warning() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Unread Notifications"
	dialog.dialog_text = "Hindi pwedeng matapos ang araw nang may unread notifications ka sa phone! Buksan ang Phone sa desk para basahin at sagutin."
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
	
	# Stop immediately if a Game Over condition was met
	if check_game_over_conditions():
		return
	
	# Check for Weekly Summary BEFORE incrementing day
	if StatManager.current_day == 7 or StatManager.current_day == 14 or StatManager.current_day == 21 or StatManager.current_day == 28:
		if StatManager.has_side_income:
			StatManager.modify_happy(-3)
			StatManager.modify_social(-2)
		trigger_weekly_summary(int(StatManager.current_day / 7))
		
	# Check for Monthly Bills on the last day of the month
	if StatManager.current_day == StatManager.year[StatManager.current_month].days:
		trigger_monthly_bills()
	
	StatManager.current_day += 1
	if StatManager.year[StatManager.current_month].days < StatManager.current_day:
		StatManager.current_day = 1
		if StatManager.year[StatManager.current_month].month == "December":
			trigger_year_end_evaluation()
			return
		else:
			StatManager.current_month += 1
		
	# Check for Salary (Day 1 and Day 15)
	if StatManager.current_day == 1 or StatManager.current_day == 15:
		receive_salary()
		
	print("New Day: " + StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day))
	update_ui()

func trigger_year_end_evaluation() -> void:
	enqueue_modal(func():
		is_game_over = true
		_update_next_button_visibility()
		var yee_scene = preload("res://scenes/year_end_evaluation.tscn")
		var yee_instance = yee_scene.instantiate()
		add_child(yee_instance)
		yee_instance.show_year_end_evaluation()
		yee_instance.play_again_requested.connect(func():
			yee_instance.visible = false
			yee_instance.queue_free()
			restart_new_year_run()
		)
		yee_instance.evaluation_closed.connect(func():
			yee_instance.visible = false
			yee_instance.queue_free()
			get_tree().quit()
		)
	)

func restart_new_year_run() -> void:
	modal_queue.clear()
	is_modal_open = false
	is_game_over = false
	pending_desk_tool_to_open = ""
	StatManager.reset_for_new_run()
	update_ui()
	_update_next_button_visibility()
	_start_initial_day()
	
func receive_salary() -> void:
	var base_salary = StatManager.base_biweekly_salary
	var side_bonus = StatManager.side_income_biweekly if StatManager.has_side_income else 0
	var total_gross = base_salary + side_bonus
	var salary_amount = total_gross
	var garnished_amount = 0
	
	if StatManager.debt_balance > 0 and total_gross > 0:
		var max_garnish = int(total_gross * 0.5)
		if StatManager.debt_balance <= max_garnish:
			garnished_amount = StatManager.debt_balance
		else:
			garnished_amount = max_garnish
			
		StatManager.debt_balance -= garnished_amount
		salary_amount -= garnished_amount

	StatManager.current_balance += salary_amount
	StatManager.weekly_income += salary_amount
	StatManager.on_stats_changed.emit()
	
	var salary_month = StatManager.current_month
	var salary_day = StatManager.current_day
	var dialog = AcceptDialog.new()
	var text := ""
	var log_text := ""
	if base_salary == 0 and side_bonus == 0:
		dialog.title = "Walang Sahod (Laid Off)"
		text = "Kasalukuyan kang walang regular na trabaho (Laid Off), kaya PHP 0 ang pumasok ngayong araw ng sahod. Gamitin nang maingat ang iyong Severance Pay at Ipon!"
		log_text = "Payday Notice: PHP 0 (Laid Off)"
	elif base_salary == 0 and side_bonus > 0:
		dialog.title = "Side Hustle Payday!"
		text = "Walang regular na sahod dahil sa Layoff, pero kumita ka ng PHP " + str(side_bonus) + " mula sa iyong Freelance Side Hustle!"
		log_text = "Side Hustle Payday! (+ PHP " + str(side_bonus) + ")"
	else:
		dialog.title = "Sahod Day!"
		text = "Pumasok na ang sahod mo na PHP " + str(base_salary) + " (" + StatManager.get_employment_display_text() + ")!"
		log_text = "Sahod Day! (+ PHP " + str(base_salary) + ")"
		if side_bonus > 0:
			text += "\n+ PHP " + str(side_bonus) + " mula sa iyong Freelance Side Hustle (Total: PHP " + str(total_gross) + ")!"
			log_text += "\n[font_size=12][color=green]+PHP " + str(side_bonus) + " Side Hustle[/color][/font_size]"
	if garnished_amount > 0:
		text += "\n\nPero kinuha ng banko ang PHP " + str(garnished_amount) + " para pambayad sa utang mo!"
		text += "\nAng natira sa iyo ay PHP " + str(salary_amount) + "."
		log_text += "\n[font_size=12][color=red]-" + str(garnished_amount) + " PHP Kaltas Utang[/color][/font_size]"
		
	dialog.dialog_text = text
	PlannerManager.record_event(salary_month, salary_day, log_text)
	spawn_dialog(dialog)
	
func trigger_weekly_summary(week_num: int) -> void:
	# Snapshot the weekly numbers and stat deltas at the moment the week ends
	var snap = StatManager.snapshot_weekly_summary(week_num)
	
	enqueue_modal(func():
		var weekly_summary_scene = preload("res://scenes/weekly_summary.tscn")
		var summary_instance = weekly_summary_scene.instantiate()
		add_child(summary_instance)
		summary_instance.show_summary_from_snapshot(snap)
		summary_instance.summary_action_requested.connect(func(action_name: String):
			pending_desk_tool_to_open = action_name
		)
		summary_instance.summary_closed.connect(func():
			summary_instance.visible = false
			summary_instance.queue_free()
			_run_next_modal()
		)
	)

func trigger_monthly_bills() -> void:
	var bill_month = StatManager.current_month
	var bill_day = StatManager.current_day
	
	# 1. Apply 2% compounding monthly interest to Bank Savings (GDD Section 4.4)
	var savings_interest = StatManager.apply_monthly_savings_interest()
	
	# 2. Apply 5% compounding monthly interest to unpaid Credit Card balance (GDD Section 4.4)
	var cc_interest = StatManager.apply_monthly_credit_card_interest()
	
	# 3. Apply 5% compounding monthly interest to existing Overdue Debt
	var debt_interest = int(StatManager.debt_balance * 0.05)
	if debt_interest > 0:
		StatManager.debt_balance += debt_interest
		
	# 4. Process monthly Simple Interest Loan installments & Investment returns
	var loan_res = StatManager.process_monthly_loan_installments()
	var inv_delta := 0
	if StatManager.get_total_investments() > 0:
		var inv_res = StatManager.apply_investment_fluctuation(0.04, 0.08)
		inv_delta = int(inv_res.get("total_delta", 0))
		
	var installments_due = StatManager.get_total_monthly_installments()
	var rent_amount = StatManager.monthly_rent
	var utilities_amount = StatManager.monthly_utilities + StatManager.extra_utilities_this_month + installments_due + StatManager.monthly_family_support
	StatManager.extra_utilities_this_month = 0
	StatManager.advance_installments_one_month()
	var total_bills = rent_amount + utilities_amount
	
	var rent_env = StatManager.get_envelope_amount("Rent")
	var util_env = StatManager.get_envelope_amount("Utilities")
	
	# GDD Section 3.3: Auto-settle without touching current_balance if envelopes cover both bills!
	if rent_env >= rent_amount and util_env >= utilities_amount:
		StatManager.spend_from_category("Rent", rent_amount)
		StatManager.spend_from_category("Utilities", utilities_amount)
		StatManager.modify_credit_score(2)
		
		var dialog = AcceptDialog.new()
		dialog.title = "Auto-Paid na ang Monthly Bills!"
		var text = "Dahil kumpleto ang naka-budget mo sa Cash Envelopes, automatic nang nabayaran ang bills nang hindi nabawasan ang hawak mong cash!\n\n• Upa: PHP " + str(rent_amount) + "\n• Kuryente/Tubig + Installments + Family Padala: PHP " + str(utilities_amount) + "\n• +2 Credit Score!"
		var log_text = "Monthly Bills Auto-Paid via Envelopes! [- PHP " + str(total_bills) + "] (+2 Credit Score)"
		if savings_interest > 0:
			text += "\n\nKumita rin ang Ipon mo sa bangko ng +PHP " + str(savings_interest) + " (2% Compounding Interest)!"
			log_text += "\n[font_size=12][color=green]Savings Compounding Interest +" + str(savings_interest) + " PHP[/color][/font_size]"
		if inv_delta != 0:
			var inv_sign = "+" if inv_delta > 0 else ""
			text += "\n\nInvestments Monthly Update: " + inv_sign + "PHP " + str(inv_delta)
			log_text += "\n[font_size=12][color=aqua]Investments Return " + inv_sign + str(inv_delta) + " PHP[/color][/font_size]"
		if int(loan_res.get("paid_cash", 0)) > 0:
			text += "\n\nNabayaran din ang Loan Installment: -PHP " + str(loan_res["paid_cash"])
		if cc_interest > 0:
			text += "\n\n⚠ Pumatong ang +PHP " + str(cc_interest) + " (5% Compounding Interest) sa hindi nabayarang Credit Card balance!"
			log_text += "\n[font_size=12][color=orange]Credit Card Interest +" + str(cc_interest) + " PHP[/color][/font_size]"
		if debt_interest > 0:
			text += "\n\nPero nadagdagan ng PHP " + str(debt_interest) + " (5% Interest) ang dati mong utang."
			log_text += "\n[font_size=12][color=red]Debt Interest Penalty -" + str(debt_interest) + " PHP[/color][/font_size]"
		dialog.dialog_text = text
		PlannerManager.record_event(bill_month, bill_day, log_text)
		spawn_dialog(dialog)
	else:
		# GDD Section 3.3: Cost Mismatch or Unallocated Budget -> Prompt player to manually settle!
		enqueue_modal(func():
			var mbs_scene = preload("res://scenes/monthly_bill_settlement.tscn")
			var mbs_instance = mbs_scene.instantiate()
			add_child(mbs_instance)
			mbs_instance.setup_settlement(bill_month, bill_day, rent_amount, utilities_amount, savings_interest, debt_interest + cc_interest)
			mbs_instance.settlement_completed.connect(func():
				mbs_instance.visible = false
				mbs_instance.queue_free()
				update_ui()
				_run_next_modal()
			)
		)
	
func process_daily_expenses() -> void:
	var food_idx = clamp(StatManager.daily_food_choice, 0, 1)
	var food_cost = StatManager.get_daily_food_cost()
	var food_happy = StatManager.food_happy_deltas[food_idx]
	StatManager.spend_from_category("Food", food_cost)
	
	var comm_idx = clamp(StatManager.daily_commute_choice, 0, 1)
	var comm_cost = StatManager.get_daily_commute_cost()
	var comm_happy = StatManager.commute_happy_deltas[comm_idx]
	StatManager.spend_from_category("Transportation", comm_cost)
	
	StatManager.modify_happy(food_happy + comm_happy)
	
func check_game_over_conditions() -> bool:
	if StatManager.get_total_debt_and_loans() > 50000:
		trigger_game_over("GAME OVER: Baon sa utang! (Lagpas PHP 50,000 na ang utang mo)")
		return true
		
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
		return true
		
	if StatManager.days_at_zero_social >= 5:
		trigger_game_over("GAME OVER: Na-isolate mo na sarili mo for 5 days. Ingatan ang mental health!")
		return true
		
	return false

func trigger_game_over(reason: String) -> void:
	is_game_over = true
	modal_queue.clear()
	_update_next_button_visibility()
	var dialog = ConfirmationDialog.new()
	dialog.title = "GAME OVER"
	dialog.dialog_text = reason + "\n\nGusto mo bang maglaro ulit (New 1-Year Run)?"
	dialog.ok_button_text = "Maglaro Ulit (Restart)"
	dialog.cancel_button_text = "Lumabas (Quit)"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		restart_new_year_run()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
		get_tree().quit()
	)
	
func _on_food_option_selected(index: int) -> void:
	StatManager.daily_food_choice = index
	StatManager.on_stats_changed.emit()

func _on_commute_option_selected(index: int) -> void:
	StatManager.daily_commute_choice = index
	StatManager.on_stats_changed.emit()

func _process(_delta: float) -> void:
	pass

func _on_button_pressed() -> void:
	happy_calc(5)
