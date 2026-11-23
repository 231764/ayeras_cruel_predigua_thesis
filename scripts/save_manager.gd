class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://paldo_savegame.json"
const SAVE_VERSION := 1

static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func get_save_summary() -> Dictionary:
	if not has_save_file():
		return {}
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var json := JSON.new()
	if json.parse(txt) != OK or not (json.data is Dictionary):
		return {}
	var d: Dictionary = json.data
	if int(d.get("save_version", 0)) != SAVE_VERSION:
		return {}
	return d.get("meta", {})

static func has_active_save() -> bool:
	var meta := get_save_summary()
	return not meta.is_empty() and str(meta.get("run_status", "active")) == "active"

static func clear_save_file() -> void:
	if has_save_file():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func _get_autoload(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null(node_name)
	return null

static func save_completed_run(eval_data: Dictionary, is_game_over_end: bool = false, game_over_reason: String = "") -> bool:
	var sm := _get_autoload("StatManager")
	var avg_grade := "—"
	if sm and sm.has_method("get_average_grade_text"):
		avg_grade = str(sm.get_average_grade_text())
	var ending_meta := {
		"ending_title": "Game Over" if is_game_over_end else str(eval_data.get("ending_title", "Completed Run")),
		"ending_id": "game_over" if is_game_over_end else str(eval_data.get("ending_id", "")),
		"conditions_met": 0 if is_game_over_end else int(eval_data.get("conditions_met_count", 0)),
		"average_grade": avg_grade,
		"game_over_reason": game_over_reason
	}
	return save_game("game_over" if is_game_over_end else "finished", ending_meta)

static func save_game(run_status: String = "active", ending_meta: Dictionary = {}) -> bool:
	var sm := _get_autoload("StatManager")
	var em := _get_autoload("EventManager")
	var pm := _get_autoload("PlannerManager")
	var lm := _get_autoload("LedgerManager")
	if not sm or not em or not pm or not lm:
		return false
		
	var env_amounts := {}
	for env in sm.envelopes:
		env_amounts[str(env["category"])] = int(env["amount"])
		
	var m_idx: int = clamp(sm.current_month, 0, sm.year.size() - 1)
	var goal: Dictionary = sm.get_current_goal()
	
	var meta_dict := {
		"run_status": run_status,
		"month_name": str(sm.year[m_idx]["month"]),
		"day": sm.current_day,
		"goal_title": str(goal.get("title", "")),
		"savings": sm.savings,
		"goal_target": sm.get_goal_target(),
		"cash": sm.current_balance
	}
	for k in ["ending_title", "ending_id", "conditions_met", "average_grade", "game_over_reason"]:
		if ending_meta.has(k):
			meta_dict[k] = ending_meta[k]
	
	var payload := {
		"save_version": SAVE_VERSION,
		"saved_at_iso": Time.get_datetime_string_from_system(false, true),
		"meta": meta_dict,
		"stat_manager": {
			"happy": sm.happy,
			"social": sm.social,
			"current_balance": sm.current_balance,
			"savings": sm.savings,
			"credit_score": sm.credit_score,
			"credit_balance": sm.credit_balance,
			"debt_balance": sm.debt_balance,
			"has_credit_card": sm.has_credit_card,
			"credit_limit": sm.credit_limit,
			"total_credit_interest_incurred": sm.total_credit_interest_incurred,
			"active_installments": sm.active_installments.duplicate(true),
			"active_loans": sm.active_loans.duplicate(true),
			"total_loan_interest_incurred": sm.total_loan_interest_incurred,
			"health_issue_delayed": sm.health_issue_delayed,
			"has_side_income": sm.has_side_income,
			"monthly_family_support": sm.monthly_family_support,
			"low_risk_investment": sm.low_risk_investment,
			"high_risk_investment": sm.high_risk_investment,
			"total_investment_principal": sm.total_investment_principal,
			"total_investment_gains": sm.total_investment_gains,
			"phone_is_slow": sm.phone_is_slow,
			"phone_upgraded": sm.phone_upgraded,
			"selected_goal_index": sm.selected_goal_index,
			"has_selected_goal": sm.has_selected_goal,
			"initial_day_started": sm.initial_day_started,
			"total_savings_interest_earned": sm.total_savings_interest_earned,
			"employment_status": sm.employment_status,
			"base_biweekly_salary": sm.base_biweekly_salary,
			"monthly_rent": sm.monthly_rent,
			"monthly_utilities": sm.monthly_utilities,
			"extra_utilities_this_month": sm.extra_utilities_this_month,
			"daily_food_choice": sm.daily_food_choice,
			"daily_commute_choice": sm.daily_commute_choice,
			"daily_food_modifier": sm.daily_food_modifier,
			"daily_commute_modifier": sm.daily_commute_modifier,
			"envelope_amounts": env_amounts,
			"days_at_zero_happiness": sm.days_at_zero_happiness,
			"days_at_zero_social": sm.days_at_zero_social,
			"current_day": sm.current_day,
			"current_month": sm.current_month,
			"current_phase": sm.current_phase,
			"weekly_income": sm.weekly_income,
			"weekly_expenses": sm.weekly_expenses,
			"week_start_savings": sm.week_start_savings,
			"week_start_debt": sm.week_start_debt,
			"week_start_happy": sm.week_start_happy,
			"week_start_social": sm.week_start_social,
			"weekly_envelope_covered_days": sm.weekly_envelope_covered_days,
			"weekly_total_routine_days": sm.weekly_total_routine_days,
			"envelope_discipline_streak": sm.envelope_discipline_streak,
			"month_start_savings": sm.month_start_savings,
			"month_deposited_savings": sm.month_deposited_savings,
			"completed_monthly_missions": sm.completed_monthly_missions.duplicate(true),
			"reached_goal_milestones": sm.reached_goal_milestones.duplicate(true),
			"monthly_grades_history": sm.monthly_grades_history.duplicate(true)
		},
		"event_manager": {
			"active_events": em.active_events.duplicate(true),
			"event_history": em.event_history.duplicate(true),
			"last_evaluated_phase_key": em.last_evaluated_phase_key
		},
		"planner_manager": {
			"entries": pm.entries.duplicate(true),
			"recorded_events": pm.recorded_events.duplicate(true)
		},
		"ledger_manager": {
			"run_id": lm.run_id,
			"run_started_at_iso": lm.run_started_at_iso,
			"next_seq_id": lm._next_seq_id,
			"entries": lm.entries.duplicate(true),
			"unlocked_achievements": lm.unlocked_achievements.duplicate(true),
			"totals": lm.totals.duplicate(true)
		}
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	return true

static func load_game() -> bool:
	if not has_save_file():
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var json := JSON.new()
	if json.parse(txt) != OK or not (json.data is Dictionary):
		return false
	var payload: Dictionary = json.data
	if int(payload.get("save_version", 0)) != SAVE_VERSION:
		return false
		
	var sm := _get_autoload("StatManager")
	var em := _get_autoload("EventManager")
	var pm := _get_autoload("PlannerManager")
	var lm := _get_autoload("LedgerManager")
	if not sm or not em or not pm or not lm:
		return false
	var sd: Dictionary = payload.get("stat_manager", {})
	
	sm.happy = int(sd.get("happy", 70))
	sm.social = int(sd.get("social", 70))
	sm.current_balance = int(sd.get("current_balance", 5000))
	sm.savings = int(sd.get("savings", 0))
	sm.credit_score = int(sd.get("credit_score", 70))
	sm.credit_balance = int(sd.get("credit_balance", 0))
	sm.debt_balance = int(sd.get("debt_balance", 0))
	sm.has_credit_card = bool(sd.get("has_credit_card", false))
	sm.credit_limit = int(sd.get("credit_limit", 0))
	sm.total_credit_interest_incurred = int(sd.get("total_credit_interest_incurred", 0))
	sm.active_installments = (sd.get("active_installments", []) as Array).duplicate(true)
	sm.active_loans = (sd.get("active_loans", []) as Array).duplicate(true)
	sm.total_loan_interest_incurred = int(sd.get("total_loan_interest_incurred", 0))
	sm.health_issue_delayed = bool(sd.get("health_issue_delayed", false))
	sm.has_side_income = bool(sd.get("has_side_income", false))
	sm.monthly_family_support = int(sd.get("monthly_family_support", 0))
	sm.low_risk_investment = int(sd.get("low_risk_investment", 0))
	sm.high_risk_investment = int(sd.get("high_risk_investment", 0))
	sm.total_investment_principal = int(sd.get("total_investment_principal", 0))
	sm.total_investment_gains = int(sd.get("total_investment_gains", 0))
	sm.phone_is_slow = bool(sd.get("phone_is_slow", false))
	sm.phone_upgraded = bool(sd.get("phone_upgraded", false))
	sm.selected_goal_index = int(sd.get("selected_goal_index", 0))
	sm.has_selected_goal = bool(sd.get("has_selected_goal", true))
	sm.initial_day_started = bool(sd.get("initial_day_started", true))
	sm.total_savings_interest_earned = int(sd.get("total_savings_interest_earned", 0))
	sm.employment_status = str(sd.get("employment_status", "regular"))
	sm.base_biweekly_salary = int(sd.get("base_biweekly_salary", 12500))
	sm.monthly_rent = int(sd.get("monthly_rent", 6000))
	sm.monthly_utilities = int(sd.get("monthly_utilities", 2000))
	sm.extra_utilities_this_month = int(sd.get("extra_utilities_this_month", 0))
	sm.daily_food_choice = int(sd.get("daily_food_choice", 0))
	sm.daily_commute_choice = int(sd.get("daily_commute_choice", 0))
	sm.daily_food_modifier = int(sd.get("daily_food_modifier", 0))
	sm.daily_commute_modifier = int(sd.get("daily_commute_modifier", 0))
	
	var env_map: Dictionary = sd.get("envelope_amounts", {})
	for env in sm.envelopes:
		var cat: String = str(env["category"])
		if env_map.has(cat):
			env["amount"] = int(env_map[cat])
	sm.sync_savings_envelope()
	
	sm.days_at_zero_happiness = int(sd.get("days_at_zero_happiness", 0))
	sm.days_at_zero_social = int(sd.get("days_at_zero_social", 0))
	sm.current_day = int(sd.get("current_day", 1))
	sm.current_month = int(sd.get("current_month", 0))
	sm.current_phase = int(sd.get("current_phase", 0))
	sm.weekly_income = int(sd.get("weekly_income", 0))
	sm.weekly_expenses = int(sd.get("weekly_expenses", 0))
	sm.week_start_savings = int(sd.get("week_start_savings", sm.savings))
	sm.week_start_debt = int(sd.get("week_start_debt", 0))
	sm.week_start_happy = int(sd.get("week_start_happy", sm.happy))
	sm.week_start_social = int(sd.get("week_start_social", sm.social))
	sm.weekly_envelope_covered_days = int(sd.get("weekly_envelope_covered_days", 0))
	sm.weekly_total_routine_days = int(sd.get("weekly_total_routine_days", 0))
	sm.envelope_discipline_streak = int(sd.get("envelope_discipline_streak", 0))
	sm.month_start_savings = int(sd.get("month_start_savings", sm.savings))
	sm.month_deposited_savings = int(sd.get("month_deposited_savings", 0))
	sm.completed_monthly_missions = (sd.get("completed_monthly_missions", {}) as Dictionary).duplicate(true)
	sm.reached_goal_milestones = (sd.get("reached_goal_milestones", []) as Array).duplicate(true)
	sm.monthly_grades_history = (sd.get("monthly_grades_history", []) as Array).duplicate(true)
	
	var ed: Dictionary = payload.get("event_manager", {})
	em.active_events = (ed.get("active_events", []) as Array).duplicate(true)
	em.event_history = (ed.get("event_history", []) as Array).duplicate(true)
	em.last_evaluated_phase_key = str(ed.get("last_evaluated_phase_key", ""))
	em.is_direct_event_active = false
	em.current_direct_event = {}
	
	var pd: Dictionary = payload.get("planner_manager", {})
	pm.entries = (pd.get("entries", []) as Array).duplicate(true)
	pm.recorded_events = (pd.get("recorded_events", []) as Array).duplicate(true)
	
	var ld: Dictionary = payload.get("ledger_manager", {})
	lm.run_id = str(ld.get("run_id", lm._generate_run_id()))
	lm.run_started_at_iso = str(ld.get("run_started_at_iso", ""))
	lm._next_seq_id = int(ld.get("next_seq_id", 1))
	lm.entries.clear()
	for row in (ld.get("entries", []) as Array):
		if row is Dictionary:
			lm.entries.append(row.duplicate(true))
	lm.unlocked_achievements = (ld.get("unlocked_achievements", {}) as Dictionary).duplicate(true)
	lm.totals = (ld.get("totals", {}) as Dictionary).duplicate(true)
	
	sm.on_stats_changed.emit()
	lm.on_ledger_reset.emit()
	return true
