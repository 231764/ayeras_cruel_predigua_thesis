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

# Simple Interest Loans & Predatory 5-6 System (GDD Sections 4.3, 4.4, 8.3)
var active_loans: Array = [] # Array of {"id", "name", "principal", "monthly_rate", "term_months", "total_interest", "total_repayment", "remaining_balance", "monthly_payment", "months_left", "maturity_month"}
var total_loan_interest_incurred: int = 0

# Stage 3 Delayed Health Flag (GDD Section 8.3.1 Event 2)
var health_issue_delayed: bool = false

# Stage 4 Investments, Side Hustle & Family Pressure (GDD Section 8.4)
var has_side_income: bool = false
var side_income_biweekly: int = 2500 # +PHP 5,000/month (+PHP 2,500 per payday)
var monthly_family_support: int = 0 # +PHP 3,000/month from family_pressure_increases
var low_risk_investment: int = 0
var high_risk_investment: int = 0
var total_investment_principal: int = 0
var total_investment_gains: int = 0

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
var employment_status: String = "regular" # "regular" (25k/mo), "laid_off" (0/mo), "temporary_job" (15k/mo), "new_stable_job" (30k/mo)
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

# --- SIMPLE INTEREST LOANS & LENDING PLATFORM (GDD Sections 4.3, 4.4, 8.3) ---
func calculate_simple_interest(principal: int, monthly_rate: float, term_months: int) -> int:
	# Simple Interest Formula: I = P * r * t
	return int(round(float(principal) * monthly_rate * float(max(1, term_months))))

func get_personal_loan_monthly_rate() -> float:
	if credit_score >= 75:
		return 0.06 # 6% simple interest per month for high credit score
	elif credit_score >= 55:
		return 0.10 # 10% simple interest per month for fair credit score
	return 0.15

func can_take_formal_loan() -> bool:
	return credit_score >= 55 and active_loans.size() < 3

func take_simple_interest_loan(loan_id: String, loan_name: String, principal: int, monthly_rate: float, term_months: int) -> Dictionary:
	var clean_term: int = max(1, term_months)
	var total_interest: int = calculate_simple_interest(principal, monthly_rate, clean_term)
	var total_repayment: int = principal + total_interest
	var monthly_pay: int = int(ceil(float(total_repayment) / float(clean_term)))
	var mat_idx: int = (current_month + clean_term) % year.size()
	var mat_month: String = str(year[mat_idx].month)
	
	var loan_entry := {
		"id": loan_id,
		"name": loan_name,
		"principal": principal,
		"monthly_rate": monthly_rate,
		"term_months": clean_term,
		"total_interest": total_interest,
		"total_repayment": total_repayment,
		"remaining_balance": total_repayment,
		"monthly_payment": monthly_pay,
		"months_left": clean_term,
		"maturity_month": mat_month
	}
	active_loans.append(loan_entry)
	current_balance += principal
	weekly_income += principal
	total_loan_interest_incurred += total_interest
	on_stats_changed.emit()
	return loan_entry

func get_total_active_loan_balance() -> int:
	var total := 0
	for loan in active_loans:
		total += max(0, int(loan.get("remaining_balance", 0)))
	return total

func get_total_monthly_loan_payments_due() -> int:
	var total := 0
	for loan in active_loans:
		var rem: int = max(0, int(loan.get("remaining_balance", 0)))
		var m_pay: int = max(0, int(loan.get("monthly_payment", 0)))
		if rem > 0:
			total += min(rem, m_pay)
	return total

func get_total_debt_and_loans() -> int:
	return debt_balance + get_total_active_loan_balance()

func pay_active_loan(loan_index: int, amount: int) -> int:
	if loan_index < 0 or loan_index >= active_loans.size() or amount <= 0 or current_balance <= 0:
		return 0
	var loan: Dictionary = active_loans[loan_index]
	var rem: int = int(loan.get("remaining_balance", 0))
	var actual_pay: int = min(amount, min(current_balance, rem))
	if actual_pay <= 0:
		return 0
	current_balance -= actual_pay
	weekly_expenses += actual_pay
	loan["remaining_balance"] = rem - actual_pay
	if int(loan["remaining_balance"]) <= 0:
		active_loans.remove_at(loan_index)
		modify_credit_score(2)
	on_stats_changed.emit()
	return actual_pay

func pay_overdue_debt(amount: int) -> int:
	if amount <= 0 or current_balance <= 0 or debt_balance <= 0:
		return 0
	var actual_pay: int = min(amount, min(current_balance, debt_balance))
	current_balance -= actual_pay
	weekly_expenses += actual_pay
	debt_balance -= actual_pay
	if debt_balance == 0:
		modify_credit_score(2)
	else:
		modify_credit_score(1)
	on_stats_changed.emit()
	return actual_pay

func process_monthly_loan_installments() -> Dictionary:
	var paid_cash := 0
	var rolled_to_debt := 0
	for i in range(active_loans.size() - 1, -1, -1):
		var loan: Dictionary = active_loans[i]
		var rem: int = int(loan.get("remaining_balance", 0))
		var due: int = min(rem, int(loan.get("monthly_payment", rem)))
		if due > 0:
			var covered: int = min(current_balance, due)
			var unpaid: int = due - covered
			current_balance -= covered
			weekly_expenses += covered
			paid_cash += covered
			if unpaid > 0:
				debt_balance += unpaid
				rolled_to_debt += unpaid
				modify_credit_score(-4)
			loan["remaining_balance"] = max(0, rem - due)
		loan["months_left"] = max(0, int(loan.get("months_left", 1)) - 1)
		if int(loan["remaining_balance"]) <= 0:
			active_loans.remove_at(i)
	on_stats_changed.emit()
	return {"paid_cash": paid_cash, "rolled_to_debt": rolled_to_debt}

func get_loans_summary_text() -> String:
	if active_loans.is_empty():
		return "None"
	var parts: Array[String] = []
	for loan in active_loans:
		parts.append(str(loan["name"]) + " (Remaining: PHP " + str(loan["remaining_balance"]) + ", Due: PHP " + str(min(int(loan["remaining_balance"]), int(loan["monthly_payment"]))) + "/mo, Maturity: " + str(loan["maturity_month"]) + ")")
	return "; ".join(parts)

# --- INVESTMENTS SYSTEM (GDD Section 8.4) ---
func get_total_investments() -> int:
	return max(0, low_risk_investment) + max(0, high_risk_investment)

func invest_low_risk(amount: int, force_event: bool = false) -> bool:
	if amount <= 0:
		return false
	if current_balance >= amount:
		current_balance -= amount
		weekly_expenses += amount
		low_risk_investment += amount
		total_investment_principal += amount
		on_stats_changed.emit()
		return true
	elif force_event:
		spend_direct(amount)
		low_risk_investment += amount
		total_investment_principal += amount
		on_stats_changed.emit()
		return true
	return false

func invest_high_risk(amount: int, force_event: bool = false) -> bool:
	if amount <= 0:
		return false
	if current_balance >= amount:
		current_balance -= amount
		weekly_expenses += amount
		high_risk_investment += amount
		total_investment_principal += amount
		on_stats_changed.emit()
		return true
	elif force_event:
		spend_direct(amount)
		high_risk_investment += amount
		total_investment_principal += amount
		on_stats_changed.emit()
		return true
	return false

func apply_investment_fluctuation(low_rate: float = 0.04, high_rate: float = 0.15) -> Dictionary:
	var low_delta := 0
	var high_delta := 0
	if low_risk_investment > 0:
		low_delta = int(round(float(low_risk_investment) * low_rate))
		low_risk_investment = max(0, low_risk_investment + low_delta)
	if high_risk_investment > 0:
		high_delta = int(round(float(high_risk_investment) * high_rate))
		high_risk_investment = max(0, high_risk_investment + high_delta)
	var total_delta := low_delta + high_delta
	total_investment_gains += total_delta
	on_stats_changed.emit()
	return {"low_delta": low_delta, "high_delta": high_delta, "total_delta": total_delta}

func withdraw_investments_to_cash() -> int:
	var total := get_total_investments()
	if total <= 0:
		return 0
	current_balance += total
	weekly_income += total
	low_risk_investment = 0
	high_risk_investment = 0
	on_stats_changed.emit()
	return total

func withdraw_investments_to_savings() -> int:
	var total := get_total_investments()
	if total <= 0:
		return 0
	savings += total
	low_risk_investment = 0
	high_risk_investment = 0
	sync_savings_envelope()
	on_stats_changed.emit()
	return total

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
	var combined_debt := get_total_debt_and_loans()
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
		"total_debt": combined_debt,
		"debt_delta": combined_debt - week_start_debt,
		"happy": happy,
		"happy_delta": happy - week_start_happy,
		"social": social,
		"social_delta": social - week_start_social
	}
	# Reset weekly accumulators and advance baseline snapshots for the new week
	weekly_income = 0
	weekly_expenses = 0
	week_start_savings = savings
	week_start_debt = combined_debt
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

func set_employment_status(status: String) -> void:
	employment_status = status
	match status:
		"laid_off":
			base_biweekly_salary = 0
		"temporary_job":
			base_biweekly_salary = 7500
		"new_stable_job":
			base_biweekly_salary = 15000
		_:
			employment_status = "regular"
			base_biweekly_salary = 12500
	on_stats_changed.emit()

func get_employment_display_text() -> String:
	match employment_status:
		"laid_off":
			return "Laid Off / Unemployed (PHP 0/mo Regular Salary)"
		"temporary_job":
			return "Temporary Job (PHP 15,000/mo)"
		"new_stable_job":
			return "New Stable Job (PHP 30,000/mo)"
		_:
			return "Regular Job (PHP 25,000/mo)"

func evaluate_year_end() -> Dictionary:
	var goal := get_current_goal()
	var target: int = get_goal_target()
	var total_obligations: int = get_total_debt_and_loans() + credit_balance
	
	var goal_reached: bool = (savings >= target)
	var wellbeing_maintained: bool = (happy >= 50 and social >= 50)
	var good_credit: bool = (credit_score >= 70)
	var debt_free: bool = (total_obligations == 0)
	
	var met_count := 0
	if goal_reached:
		met_count += 1
	if wellbeing_maintained:
		met_count += 1
	if good_credit:
		met_count += 1
	if debt_free:
		met_count += 1
		
	var is_full_paldo: bool = (met_count == 4)
	var ending_id := ""
	var ending_title := ""
	var ending_summary := ""
	var baldo_verdict := ""
	
	if is_full_paldo:
		ending_id = "full_paldo"
		ending_title = "🏆 TUNAY NA PALDO! (Full Breadwinner Mastery Victory)"
		ending_summary = "Nakamit mo ang iyong 1-Year Life Goal (\"" + str(goal["title"]) + "\"), nanatiling 100% debt-free, mataas ang Credit Score, at napangalagaan ang iyong Happiness at Relationships sa gitna ng layoff at mga krisis!"
		baldo_verdict = "Omsim par, ISA KANG ALAMAT! Kahit dumaan sa layoff, inflation, at hospital emergencies, na-balance mo ang Cash Envelopes, Ipon, at mental health mo. Tunay na PALDO!"
	elif goal_reached:
		ending_id = "pyrrhic_goal"
		ending_title = "⚠️ NATUPAD ANG GOAL PERO MAY KAPALIT (Partial Victory)"
		ending_summary = "Naabot mo ang target na PHP " + str(target) + " sa Ipon para sa \"" + str(goal["title"]) + "\", ngunit may naiwang utang/credit balance, bumaba ang Credit Score, o na-kompromiso ang iyong Happiness/Social."
		baldo_verdict = "Congrats at naipon mo yung pang-\"" + str(goal["title"]) + "\" par! Pero tandaan: ang tunay na pag-paldo ay hindi lang malaking ipon—dapat debt-free rin at hindi nasasakripisyo ang sarili at pamilya."
	elif debt_free and wellbeing_maintained:
		ending_id = "debt_free_survivor"
		ending_title = "🌱 MATATAG NA BREADWINNER (Debt-Free Survivor Ending)"
		ending_summary = "Nalampasan mo ang buong taon nang walang utang, maganda ang well-being, at nakabangon mula sa layoff, ngunit kinapos pa ang iyong Ipon (PHP " + str(savings) + " / PHP " + str(target) + ") para sa \"" + str(goal["title"]) + "\"."
		baldo_verdict = "Proud pa rin ako sa'yo lods! Hindi biro ang ma-layoff at ma-ospital ang kapatid, pero tinapos mo ang taon nang walang utang at buo ang loob. Konting ipon at investment pa, papaldo ka na!"
	else:
		ending_id = "financial_struggle"
		ending_title = "📉 KINAPOS SA TAONG ITO (Financial Struggle Ending)"
		ending_summary = "Natapos ang taon na kinapos sa Life Goal (PHP " + str(savings) + " / PHP " + str(target) + ") at may mabigat pang obligasyon o pagod na kalusugan/relasyon. Mahalagang aral ito sa pag-budget at paghahanda ng Emergency Fund."
		baldo_verdict = "Hinga nang malalim par! Mabigat talaga ang unang taon bilang breadwinner lalo na kung sabay-sabay ang utang at emergency. Bawi tayo next run: unahin ang Emergency Fund at iwas sa minimum payment trap!"
		
	return {
		"goal_title": str(goal["title"]),
		"goal_target": target,
		"savings": savings,
		"current_balance": current_balance,
		"total_investments": get_total_investments(),
		"happy": happy,
		"social": social,
		"credit_score": credit_score,
		"debt_balance": debt_balance,
		"loan_balance": get_total_active_loan_balance(),
		"credit_balance": credit_balance,
		"total_obligations": total_obligations,
		"goal_reached": goal_reached,
		"wellbeing_maintained": wellbeing_maintained,
		"good_credit": good_credit,
		"debt_free": debt_free,
		"conditions_met_count": met_count,
		"is_full_paldo_victory": is_full_paldo,
		"ending_id": ending_id,
		"ending_title": ending_title,
		"ending_summary": ending_summary,
		"baldo_verdict": baldo_verdict
	}

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
	var total_utilities_due = monthly_utilities + extra_utilities_this_month + inst_total + monthly_family_support
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
	summary += "- Employment Status: " + get_employment_display_text() + "\n"
	summary += "- Chosen 1-Year Life Goal: \"" + str(goal["title"]) + "\" — Target Cost: PHP " + str(goal["cost"]) + " | Progress: PHP " + str(savings) + " / PHP " + str(goal["cost"]) + " (" + str(get_goal_progress_percent()) + "%, Need PHP " + str(goal_rem) + " more)\n"
	summary += "- Available Cash (Current Balance): PHP " + str(current_balance) + "\n"
	summary += "- Savings (Ipon in Bank, earns 2% monthly compounding interest): PHP " + str(savings) + " (Total Compounding Interest Earned So Far: PHP " + str(total_savings_interest_earned) + ")\n"
	summary += "- Unpaid Overdue Debt Balance: PHP " + str(debt_balance) + " (5% monthly interest penalty if unpaid; Total Debt + Loans > PHP 50,000 = Game Over)\n"
	summary += "- Active Simple Interest Loans (Lending Platform / 5-6): " + get_loans_summary_text() + " (Total Loan Balance: PHP " + str(get_total_active_loan_balance()) + ")\n"
	summary += "- Credit Card Status: " + cc_status + " | Credit Score: " + str(credit_score) + "/100 (Need >=70 for Good standing)\n"
	summary += "- Active Monthly Installments: " + get_installments_summary_text() + "\n"
	summary += "- Investments Portfolio: Low-Risk Fund = PHP " + str(low_risk_investment) + " (+4%/mo steady) | High-Risk Stock = PHP " + str(high_risk_investment) + " (volatile) | Total Investment P&L = PHP " + str(total_investment_gains) + "\n"
	summary += "- Side Hustle / Freelance Status: " + ("Active (+PHP 5,000/mo, -3 Happy & -2 Social/week)" if has_side_income else "None") + " | Regular Family Support Obligation: PHP " + str(monthly_family_support) + "/mo\n"
	if health_issue_delayed:
		summary += "  [HEALTH WARNING: Player delayed medical treatment in Stage 3—at risk of severe health complication!]\n"
	summary += "- Phone Status: " + ("Slow Phone (2s lag per tap)" if phone_is_slow else ("Upgraded Plan (PHP 1,200/mo)" if phone_upgraded else "Normal")) + "\n"
	summary += "- Well-Being Meters: Happiness = " + str(happy) + "/100, Sociability/Relationships = " + str(social) + "/100 (Need >=50 by year-end; 5 consecutive days at 0 = Game Over)\n"
	if days_at_zero_happiness > 0:
		summary += "  [URGENT WARNING: Player has been at 0 Happiness for " + str(days_at_zero_happiness) + "/5 days! Burnout imminent!]\n"
	if days_at_zero_social > 0:
		summary += "  [URGENT WARNING: Player has been at 0 Social for " + str(days_at_zero_social) + "/5 days! Isolation imminent!]\n"
	summary += "- This Week's Tracker: Income = PHP " + str(weekly_income) + " | Expenses = PHP " + str(weekly_expenses) + "\n"
	summary += "- Active Daily Routine Settings: Food = " + food_mode + " | Commute = " + commute_mode + " (Total Daily Routine = PHP " + str(get_daily_food_cost() + get_daily_commute_cost()) + "/day)\n"
	summary += "- Cash Envelopes Allocated: " + ", ".join(env_lines) + "\n"
	summary += "- End-of-Month Fixed Bills Forecast: Rent Due = PHP " + str(monthly_rent) + " (Shortfall in Rent Envelope: PHP " + str(rent_shortfall) + "), Utilities + Installments + Family Support Due = PHP " + str(total_utilities_due) + " (Shortfall in Utilities Envelope: PHP " + str(util_shortfall) + ")\n"
	return summary
