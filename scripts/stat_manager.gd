extends Node

signal on_stats_changed

var happy := 70 # starting happiness value (0-100 scale, >=50 is Normal)
var social := 70 # starting sociability/relationship value (0-100 scale, >=50 is Normal)
var current_balance := 5000 # starting pocket money before first salary
var savings := 0 # starting savings value
var credit_score := 70 # starting credit score value (0-100 scale, >=70 is Good)
var credit_balance := 0 # starting credit card balance (unlocked in Stage 2)
var debt_balance := 0 # starting unpaid debt value

# Credit Card System (GDD Sections 4.3, 4.4, 8.2)
var has_credit_card: bool = false
var credit_limit: int = 0
var credit_monthly_interest_rate: float = 0.05 # 5% monthly compounding interest on unpaid credit balance
var total_credit_interest_incurred: int = 0

# Recurring Monthly Installments (GDD Sections 8.1, 8.2)
var active_installments: Array = [] # Array of {"id": String, "name": String, "monthly_cost": int, "months_left": int}

# Phone Plan Upgrade / Slow Phone Mechanic (GDD Section 8.1.1 Event 3)
var phone_is_slow: bool = false
var phone_lag_seconds: float = 2.0
var phone_upgraded: bool = false

# Life Goal System (GDD Section 2.3)
var life_goals := [
	{
		"id": "sibling_tuition",
		"title": "Graduation Fund ng Kapatid",
		"description": "Maipon ang pang-matrikula at graduation fees ng nakababatang kapatid.",
		"cost": 40000,
		"difficulty": "Balanced (Recommended)"
	},
	{
		"id": "small_business",
		"title": "Puhunan sa Maliit na Negosyo",
		"description": "Makapagpatayo ng sari-sari store o food cart para sa pamilya.",
		"cost": 60000,
		"difficulty": "Challenging"
	},
	{
		"id": "home_repair",
		"title": "Pagpapaayos ng Bahay sa Probinsya",
		"description": "Maipa-renovate ang bubong at bahay ng pamilya sa probinsya.",
		"cost": 80000,
		"difficulty": "Hard (Paldo Master)"
	}
]
var selected_goal_index: int = 0
var has_selected_goal: bool = false

# Savings Compounding Interest (GDD Section 4.4)
var savings_monthly_interest_rate: float = 0.02 # 2% monthly compounding interest
var total_savings_interest_earned: int = 0

# Base Economy Parameters (Rebalanced so entry-level breadwinner can save & survive)
var base_biweekly_salary: int = 12500 # PHP 25,000 / month
var monthly_rent: int = 6000
var monthly_utilities: int = 2000
var extra_utilities_this_month: int = 0

# Daily Routine Options & Modifiers
var daily_food_choice: int = 0 # 0 = Cook (200/day, 0 Happy), 1 = Eat Out (450/day, +1 Happy)
var daily_commute_choice: int = 0 # 0 = Public (80/day, -1 Happy), 1 = Mototaxi (180/day, +1 Happy)
var food_costs := [200, 450]
var food_happy_deltas := [0, 1]
var commute_costs := [80, 180]
var commute_happy_deltas := [-1, 1]
var daily_food_modifier: int = 0
var daily_commute_modifier: int = 0

# For the BUDGETING aspect
var envelopes := [
	{"category": "Food", "display_name": "Pagkain\n(Food)", "amount": 0},
	{"category": "Transportation", "display_name": "Pamasahe\n(Transportation)", "amount": 0},
	{"category": "Entertainment", "display_name": "Libangan\n(Entertainment)", "amount": 0},
	{"category": "Rent", "display_name": "Upa\n(Rent)", "amount": 0},
	{"category": "Utilities", "display_name": "Kuryente/Tubig\n(Utilities)", "amount": 0},
	{"category": "Credit Card", "display_name": "Credit Card\n(Pambayad sa Bill)", "amount": 0},
	{"category": "Savings", "display_name": "Ipon / Bangko\n(Savings +2%/mo)", "amount": 0}
]

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

# Weekly Tracking & Delta Snapshots (GDD Section 3.2)
var weekly_income: int = 0
var weekly_expenses: int = 0
var week_start_savings: int = 0
var week_start_debt: int = 0
var week_start_happy: int = 70
var week_start_social: int = 70

func _ready() -> void:
	pass

func select_life_goal(index: int) -> void:
	selected_goal_index = clamp(index, 0, life_goals.size() - 1)
	has_selected_goal = true
	on_stats_changed.emit()

func get_current_goal() -> Dictionary:
	return life_goals[clamp(selected_goal_index, 0, life_goals.size() - 1)]

func get_goal_target() -> int:
	return int(get_current_goal()["cost"])

func get_goal_progress_percent() -> int:
	var target = max(1, get_goal_target())
	return int(clamp(round(float(savings) / float(target) * 100.0), 0.0, 100.0))

func unlock_credit_card(limit: int = 20000) -> void:
	has_credit_card = true
	credit_limit = max(credit_limit, limit)
	on_stats_changed.emit()

func get_available_credit() -> int:
	if not has_credit_card:
		return 0
	return max(0, credit_limit - credit_balance)

func can_use_credit_card(amount: int) -> bool:
	return has_credit_card and amount > 0 and (credit_balance + amount) <= credit_limit

func charge_credit_card(amount: int) -> bool:
	if not can_use_credit_card(amount):
		return false
	credit_balance += amount
	on_stats_changed.emit()
	return true

func get_credit_minimum_due() -> int:
	if credit_balance <= 0:
		return 0
	return min(credit_balance, max(500, int(round(float(credit_balance) * 0.10))))

func pay_credit_card_balance(amount: int) -> int:
	if amount <= 0 or credit_balance <= 0:
		return 0
	var actual_pay = min(amount, credit_balance)
	# Pull from Credit Card envelope first, then current_balance
	spend_from_category("Credit Card", actual_pay)
	credit_balance -= actual_pay
	on_stats_changed.emit()
	return actual_pay

func apply_monthly_credit_card_interest() -> int:
	if credit_balance <= 0:
		return 0
	var interest = max(1, int(round(float(credit_balance) * credit_monthly_interest_rate)))
	credit_balance += interest
	total_credit_interest_incurred += interest
	on_stats_changed.emit()
	return interest

func add_installment(id: String, inst_name: String, monthly_cost: int, months: int) -> void:
	for inst in active_installments:
		if inst.get("id") == id:
			inst["monthly_cost"] = monthly_cost
			inst["months_left"] = months
			on_stats_changed.emit()
			return
	active_installments.append({
		"id": id,
		"name": inst_name,
		"monthly_cost": monthly_cost,
		"months_left": months
	})
	on_stats_changed.emit()

func get_total_monthly_installments() -> int:
	var total := 0
	for inst in active_installments:
		if int(inst.get("months_left", 0)) > 0:
			total += int(inst.get("monthly_cost", 0))
	return total

func advance_installments_one_month() -> void:
	for i in range(active_installments.size() - 1, -1, -1):
		active_installments[i]["months_left"] = int(active_installments[i]["months_left"]) - 1
		if int(active_installments[i]["months_left"]) <= 0:
			active_installments.remove_at(i)
	on_stats_changed.emit()

func get_installments_summary_text() -> String:
	if active_installments.is_empty():
		return "None"
	var parts: Array[String] = []
	for inst in active_installments:
		parts.append(str(inst["name"]) + " (PHP " + str(inst["monthly_cost"]) + "/mo, " + str(inst["months_left"]) + " mos left)")
	return ", ".join(parts)

func sync_savings_envelope() -> void:
	for env in envelopes:
		if env["category"] == "Savings":
			env["amount"] = savings
			break

func deposit_savings(amount: int) -> bool:
	if amount > 0 and current_balance >= amount:
		current_balance -= amount
		savings += amount
		sync_savings_envelope()
		on_stats_changed.emit()
		return true
	return false

func withdraw_savings(amount: int) -> bool:
	if amount > 0 and savings >= amount:
		savings -= amount
		current_balance += amount
		sync_savings_envelope()
		on_stats_changed.emit()
		return true
	return false

func apply_monthly_savings_interest() -> int:
	if savings <= 0:
		return 0
	var interest_earned = max(1, int(round(float(savings) * savings_monthly_interest_rate)))
	savings += interest_earned
	total_savings_interest_earned += interest_earned
	sync_savings_envelope()
	on_stats_changed.emit()
	return interest_earned

func modify_happy(amount: int) -> void:
	happy = clamp(happy + amount, 0, 100)
	on_stats_changed.emit()

func modify_social(amount: int) -> void:
	social = clamp(social + amount, 0, 100)
	on_stats_changed.emit()

func modify_credit_score(amount: int) -> void:
	credit_score = clamp(credit_score + amount, 0, 100)
	on_stats_changed.emit()

func get_daily_food_cost() -> int:
	var idx = clamp(daily_food_choice, 0, food_costs.size() - 1)
	return max(0, food_costs[idx] + daily_food_modifier)

func get_daily_commute_cost() -> int:
	var idx = clamp(daily_commute_choice, 0, commute_costs.size() - 1)
	return max(0, commute_costs[idx] + daily_commute_modifier)

func get_envelope_amount(category_name: String) -> int:
	if category_name == "Savings":
		return savings
	for envelope in envelopes:
		if envelope["category"] == category_name:
			return envelope["amount"]
	return 0

func set_envelope_amount(category_name: String, new_amount: int) -> void:
	var clamped_val = max(0, new_amount)
	for envelope in envelopes:
		if envelope["category"] == category_name:
			envelope["amount"] = clamped_val
			break
	if category_name == "Savings":
		savings = clamped_val
	on_stats_changed.emit()

func spend_direct(amount: int) -> void:
	if amount > 0:
		weekly_expenses += amount
		current_balance -= amount
		if current_balance < 0:
			debt_balance += abs(current_balance)
			current_balance = 0
	elif amount < 0:
		var gain = abs(amount)
		current_balance += gain
		weekly_income += gain
	on_stats_changed.emit()

func spend_from_category(category_name: String, amount: int) -> void:
	if amount <= 0:
		if amount < 0:
			spend_direct(amount)
		return
		
	weekly_expenses += amount
	# Try to pull from envelope first
	for envelope in envelopes:
		if envelope["category"] == category_name:
			if envelope["amount"] >= amount:
				envelope["amount"] -= amount
				if category_name == "Savings":
					savings = envelope["amount"]
				on_stats_changed.emit()
				return
			else:
				# Envelope exists but doesn't have enough; drain it and pull rest from current_balance
				var remaining = amount - envelope["amount"]
				envelope["amount"] = 0
				if category_name == "Savings":
					savings = 0
				current_balance -= remaining
				
				# Handle Debt roll-over if current balance goes below 0
				if current_balance < 0:
					debt_balance += abs(current_balance)
					current_balance = 0
				on_stats_changed.emit()
				return
	
	# If no envelope found, pull from current_balance
	current_balance -= amount
	# Handle Debt roll-over if current balance goes below 0
	if current_balance < 0:
		debt_balance += abs(current_balance)
		current_balance = 0
		
	on_stats_changed.emit()

func snapshot_weekly_summary(week_num: int) -> Dictionary:
	var summary_data := {
		"week_num": week_num,
		"income": weekly_income,
		"expenses": weekly_expenses,
		"net": weekly_income - weekly_expenses,
		"total_savings": savings,
		"savings_delta": savings - week_start_savings,
		"goal_title": str(get_current_goal()["title"]),
		"goal_target": get_goal_target(),
		"goal_percent": get_goal_progress_percent(),
		"total_debt": debt_balance,
		"debt_delta": debt_balance - week_start_debt,
		"happy": happy,
		"happy_delta": happy - week_start_happy,
		"social": social,
		"social_delta": social - week_start_social
	}
	# Reset weekly accumulators and advance baseline snapshots for the new week
	weekly_income = 0
	weekly_expenses = 0
	week_start_savings = savings
	week_start_debt = debt_balance
	week_start_happy = happy
	week_start_social = social
	return summary_data

func get_stage_info() -> Dictionary:
	match current_month:
		0, 1:
			return {"stage": 1, "name": "Foundational Stage 1: Budgeting", "theme": "I finally have income, but is it enough?"}
		2, 3:
			return {"stage": 2, "name": "Foundational Stage 2: Credit and Debt", "theme": "I don't have enough money, I need to borrow"}
		4, 5:
			return {"stage": 3, "name": "Foundational Stage 3: Interest and Financial Risk", "theme": "My past decisions start catching up"}
		6, 7:
			return {"stage": 4, "name": "Foundational Stage 4: Investments and Long-Term Planning", "theme": "I should think about the future despite chaos"}
		_:
			return {"stage": 5, "name": "Mastery Stage", "theme": "Situations keep getting worse. Can I manage until the end?"}

func get_live_summary_for_ai() -> String:
	var phase_names = ["Morning", "Afternoon", "Evening"]
	var month_name = year[current_month].month
	var days_in_month = year[current_month].days
	var stage_info = get_stage_info()
	var goal = get_current_goal()
	var goal_rem = max(0, get_goal_target() - savings)
	var food_mode = "Magluto sa bahay (PHP " + str(get_daily_food_cost()) + "/day)" if daily_food_choice == 0 else "Mag-order / Eat Out (PHP " + str(get_daily_food_cost()) + "/day)"
	var commute_mode = "Jeep/Bus Public Commute (PHP " + str(get_daily_commute_cost()) + "/day)" if daily_commute_choice == 0 else "Angkas/Joyride Mototaxi (PHP " + str(get_daily_commute_cost()) + "/day)"
	
	var env_lines: Array[String] = []
	for env in envelopes:
		env_lines.append(env["category"] + ": PHP " + str(env["amount"]))
	
	var inst_total = get_total_monthly_installments()
	var total_utilities_due = monthly_utilities + extra_utilities_this_month + inst_total
	var rent_env = get_envelope_amount("Rent")
	var util_env = get_envelope_amount("Utilities")
	var rent_shortfall = max(0, monthly_rent - rent_env)
	var util_shortfall = max(0, total_utilities_due - util_env)
	
	var cc_status = "Not Unlocked / Declined"
	if has_credit_card:
		cc_status = "Unlocked (Balance: PHP " + str(credit_balance) + " / Limit: PHP " + str(credit_limit) + ", Available Credit: PHP " + str(get_available_credit()) + ", Min Due: PHP " + str(get_credit_minimum_due()) + ", 5%/mo compounding interest on unpaid balance)"
	
	var summary = "=== LIVE PLAYER GAME STATE (StatManager) ===\n"
	summary += "- Date & Time: " + month_name + " " + str(current_day) + " (" + phase_names[current_phase] + "), " + str(days_in_month - current_day) + " days left in month\n"
	summary += "- Current Stage: " + stage_info["name"] + " (\"" + stage_info["theme"] + "\")\n"
	summary += "- Chosen 1-Year Life Goal: \"" + str(goal["title"]) + "\" — Target Cost: PHP " + str(goal["cost"]) + " | Progress: PHP " + str(savings) + " / PHP " + str(goal["cost"]) + " (" + str(get_goal_progress_percent()) + "%, Need PHP " + str(goal_rem) + " more)\n"
	summary += "- Available Cash (Current Balance): PHP " + str(current_balance) + "\n"
	summary += "- Savings (Ipon in Bank, earns 2% monthly compounding interest): PHP " + str(savings) + " (Total Compounding Interest Earned So Far: PHP " + str(total_savings_interest_earned) + ")\n"
	summary += "- Unpaid Debt Balance: PHP " + str(debt_balance) + " (5% monthly interest penalty if unpaid; >PHP 50,000 = Game Over)\n"
	summary += "- Credit Card Status: " + cc_status + " | Credit Score: " + str(credit_score) + "/100 (Need >=70 for Good standing)\n"
	summary += "- Active Monthly Installments: " + get_installments_summary_text() + "\n"
	summary += "- Phone Status: " + ("Slow Phone (2s lag per tap)" if phone_is_slow else ("Upgraded Plan (PHP 1,200/mo)" if phone_upgraded else "Normal")) + "\n"
	summary += "- Well-Being Meters: Happiness = " + str(happy) + "/100, Sociability/Relationships = " + str(social) + "/100 (Need >=50 by year-end; 5 consecutive days at 0 = Game Over)\n"
	if days_at_zero_happiness > 0:
		summary += "  [URGENT WARNING: Player has been at 0 Happiness for " + str(days_at_zero_happiness) + "/5 days! Burnout imminent!]\n"
	if days_at_zero_social > 0:
		summary += "  [URGENT WARNING: Player has been at 0 Social for " + str(days_at_zero_social) + "/5 days! Isolation imminent!]\n"
	summary += "- This Week's Tracker: Income = PHP " + str(weekly_income) + " | Expenses = PHP " + str(weekly_expenses) + "\n"
	summary += "- Active Daily Routine Settings: Food = " + food_mode + " | Commute = " + commute_mode + " (Total Daily Routine = PHP " + str(get_daily_food_cost() + get_daily_commute_cost()) + "/day)\n"
	summary += "- Cash Envelopes Allocated: " + ", ".join(env_lines) + "\n"
	summary += "- End-of-Month Fixed Bills Forecast: Rent Due = PHP " + str(monthly_rent) + " (Shortfall in Rent Envelope: PHP " + str(rent_shortfall) + "), Utilities + Installments Due = PHP " + str(total_utilities_due) + " (Shortfall in Utilities Envelope: PHP " + str(util_shortfall) + ")\n"
	return summary
