extends Node

signal on_entry_recorded(entry: Dictionary)
signal on_achievement_unlocked(achievement: Dictionary)
signal on_ledger_reset()

const SCHEMA_VERSION := "1.1.0"
const ENTRY_TYPES := ["transaction", "decision", "achievement", "milestone"]

const ACHIEVEMENT_DEFINITIONS := [
	{
		"id": "first_goal_set",
		"icon": "goal",
		"title": "May Pangarap",
		"subtitle": "1-Year Goal Setter",
		"description": "Pumili ng 1-Year Breadwinner Life Goal.",
		"lesson": "Ang malinaw na goal ang gabay sa bawat peso."
	},
	{
		"id": "first_paycheck",
		"icon": "cash",
		"title": "Unang Sahod",
		"subtitle": "First Payday Logged",
		"description": "Natanggap ang unang sahod sa trabaho.",
		"lesson": "Mag-budget muna bago gumastos tuwing sahod."
	},
	{
		"id": "smart_budgeter",
		"icon": "budget",
		"title": "Wais sa Sobre",
		"subtitle": "Bills 100% Funded",
		"description": "100% pondohan ang Upa at Bills envelopes.",
		"lesson": "Unahin ang fixed bills para iwas late fees."
	},
	{
		"id": "bills_autopaid",
		"icon": "planner",
		"title": "Auto-Paid Pro",
		"subtitle": "Zero-Stress Katapusan",
		"description": "Auto-paid ang Monthly Bills via Envelopes (+2 CS).",
		"lesson": "Kumpletong sobre = tuloy-tuloy na Credit Score."
	},
	{
		"id": "discipline_streak_2",
		"icon": "happy",
		"title": "Disiplinadong Budgeter",
		"subtitle": "2-Week Envelope Streak",
		"description": "2 magkasunod na linggo ng Envelope Discipline.",
		"lesson": "Maliliit na disiplina araw-araw = malaking ipon."
	},
	{
		"id": "discipline_streak_4",
		"icon": "happy_max",
		"title": "Budgeting Legend",
		"subtitle": "4-Week Envelope Streak",
		"description": "4 magkasunod na linggo ng Envelope Discipline.",
		"lesson": "Consistency ang panlaban sa petsa de peligro."
	},
	{
		"id": "first_savings_5k",
		"icon": "bank",
		"title": "Unang Pundar",
		"subtitle": "PHP 5,000 Bank Savings",
		"description": "Nakaipon ng PHP 5,000 sa bangko (+2%/mo).",
		"lesson": "Pay Yourself First para lumago ang ipon."
	},
	{
		"id": "emergency_buffer_20k",
		"icon": "bank",
		"title": "Emergency Shield",
		"subtitle": "PHP 20,000 Safety Net",
		"description": "Nakaipon ng PHP 20,000 bilang Emergency Fund.",
		"lesson": "Emergency Fund ang sumasalo sa sakit o layoff."
	},
	{
		"id": "compounding_magic",
		"icon": "cash",
		"title": "Kapangyarihan ng Tubo",
		"subtitle": "PHP 1,000+ Interest Earned",
		"description": "Kumita ng PHP 1,000+ mula sa 2% bank interest.",
		"lesson": "Maagang ipon = pera mismo ang nagtatrabaho."
	},
	{
		"id": "credit_responsible",
		"icon": "creditscore",
		"title": "Good Credit Standing",
		"subtitle": "80+ Credit Score, Zero Debt",
		"description": "Naabot ang 80+ Credit Score nang walang utang.",
		"lesson": "Mataas na Credit Score = mababang loan rate."
	},
	{
		"id": "first_investor",
		"icon": "laptop",
		"title": "Paldo Investor",
		"subtitle": "Portfolio Started",
		"description": "Nag-invest sa Mutual Fund o Stock Market.",
		"lesson": "Balansehin lagi ang risk at safety sa invest."
	},
	{
		"id": "layoff_survivor",
		"icon": "social",
		"title": "Bangon Breadwinner",
		"subtitle": "Recovered From Layoff",
		"description": "Nakabalik sa trabaho matapos ang Job Layoff.",
		"lesson": "Emergency Fund + tipid mode = kayang bumangon."
	},
	{
		"id": "goal_achieved",
		"icon": "goal",
		"title": "Goal Unlocked!",
		"subtitle": "100% Life Goal Funded",
		"description": "Naabot ang 100% ng target savings ng Life Goal.",
		"lesson": "Planadong buwan = abot-kamay ang pangarap."
	},
	{
		"id": "tunay_na_paldo",
		"icon": "creditscore",
		"title": "Tunay na Paldo",
		"subtitle": "4/4 Breadwinner Mastery",
		"description": "Pasado sa lahat ng 4 Year-End Victory Conditions!",
		"lesson": "Tunay na paldo = ipon, zero debt, at masayang buhay."
	}
]

var run_id: String = ""
var run_started_at_iso: String = ""
var entries: Array[Dictionary] = []
var unlocked_achievements: Dictionary = {}
var _next_seq_id: int = 1
var _composite_depth: int = 0
var _is_evaluating_achievements: bool = false

var totals: Dictionary = {}

func _ready() -> void:
	reset_ledger()

func _generate_run_id() -> String:
	var unix_sec := int(Time.get_unix_time_from_system())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var suffix := rng.randi_range(1000, 9999)
	return "run_%d_%d" % [unix_sec, suffix]

func _reset_totals() -> void:
	totals = {
		"total_inflow": 0,
		"total_outflow": 0,
		"net_cash_flow": 0,
		"total_transactions": 0,
		"total_decisions": 0,
		"total_tradeoffs": 0,
		"total_achievements": 0,
		"total_milestones": 0,
		"total_envelope_allocations": 0,
		"total_savings_deposited": 0,
		"total_savings_withdrawn": 0,
		"total_interest_earned": 0,
		"total_interest_paid": 0,
		"bills_autopaid_count": 0,
		"bills_shortfall_count": 0,
		"credit_paid_full_count": 0,
		"credit_paid_min_count": 0,
		"routine_changes_count": 0,
		"was_laid_off": false
	}

func reset_ledger() -> void:
	run_id = _generate_run_id()
	run_started_at_iso = Time.get_datetime_string_from_system(false, true)
	entries.clear()
	unlocked_achievements.clear()
	_next_seq_id = 1
	_composite_depth = 0
	_is_evaluating_achievements = false
	_reset_totals()
	on_ledger_reset.emit()

func begin_composite() -> void:
	_composite_depth += 1

func end_composite() -> void:
	_composite_depth = max(0, _composite_depth - 1)

func is_in_composite() -> bool:
	return _composite_depth > 0

func capture_state_snapshot() -> Dictionary:
	var cash: int = StatManager.current_balance
	var sav: int = StatManager.savings
	var cc_bal: int = StatManager.credit_balance
	var debt: int = StatManager.debt_balance
	var loans: int = StatManager.get_total_active_loan_balance()
	var inv: int = StatManager.get_total_investments()
	var env_non_savings := 0
	for env in StatManager.envelopes:
		if str(env.get("category", "")) != "Savings":
			env_non_savings += int(env.get("amount", 0))
	var net_worth: int = cash + sav + env_non_savings + inv - cc_bal - debt - loans
	return {
		"cash": cash,
		"savings": sav,
		"envelopes_non_savings": env_non_savings,
		"credit_balance": cc_bal,
		"debt_balance": debt,
		"loan_balance": loans,
		"investments": inv,
		"net_worth": net_worth,
		"happy": StatManager.happy,
		"social": StatManager.social,
		"credit_score": StatManager.credit_score,
		"employment_status": StatManager.employment_status,
		"goal_progress_pct": StatManager.get_goal_progress_percent()
	}

func compute_deltas(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	var keys := [
		"cash",
		"savings",
		"envelopes_non_savings",
		"credit_balance",
		"debt_balance",
		"loan_balance",
		"investments",
		"net_worth",
		"happy",
		"social",
		"credit_score"
	]
	for k in keys:
		var diff: int = int(after.get(k, 0)) - int(before.get(k, 0))
		if diff != 0:
			out[k] = diff
	return out

func _build_game_date() -> Dictionary:
	var m_idx: int = clamp(StatManager.current_month, 0, StatManager.year.size() - 1)
	var m_name: String = str(StatManager.year[m_idx]["month"])
	var day_num: int = StatManager.current_day
	var phase_idx: int = clamp(StatManager.current_phase, 0, 2)
	var phase_names := ["Morning", "Afternoon", "Evening"]
	var stage_info := StatManager.get_stage_info()
	return {
		"month_index": m_idx,
		"month_name": m_name,
		"day": day_num,
		"weekday": StatManager.get_weekday_name(m_idx, day_num, true),
		"phase_index": phase_idx,
		"phase_name": phase_names[phase_idx],
		"stage": int(stage_info.get("stage", 1))
	}

func record_entry(
	entry_type: String,
	category: String,
	source: String,
	title: String,
	summary: String,
	cash_delta: int = 0,
	deltas: Dictionary = {},
	tradeoff: Dictionary = {},
	metadata: Dictionary = {}
) -> Dictionary:
	var clean_type: String = entry_type if entry_type in ENTRY_TYPES else "transaction"
	var snap: Dictionary = capture_state_snapshot()
	var gdate: Dictionary = _build_game_date()
	
	var entry := {
		"seq_id": _next_seq_id,
		"run_id": run_id,
		"schema_version": SCHEMA_VERSION,
		"real_timestamp_iso": Time.get_datetime_string_from_system(false, true),
		"game_date": gdate,
		"date_label": "%s, %s %d (%s)" % [gdate["weekday"], gdate["month_name"], gdate["day"], gdate["phase_name"]],
		"entry_type": clean_type,
		"category": category.strip_edges() if category.strip_edges() != "" else "General",
		"source": source.strip_edges() if source.strip_edges() != "" else "system",
		"title": title.strip_edges(),
		"summary": summary.strip_edges(),
		"cash_delta": cash_delta,
		"deltas": deltas.duplicate(true),
		"tradeoff": tradeoff.duplicate(true),
		"snapshot_after": snap,
		"metadata": metadata.duplicate(true)
	}
	_next_seq_id += 1
	entries.append(entry)
	
	# Update running aggregates (cash flow only counts real economic inflow/outflow, not internal transfers unless non-zero cash_delta passed)
	if cash_delta > 0:
		totals["total_inflow"] = int(totals["total_inflow"]) + cash_delta
	elif cash_delta < 0:
		totals["total_outflow"] = int(totals["total_outflow"]) + abs(cash_delta)
	totals["net_cash_flow"] = int(totals["total_inflow"]) - int(totals["total_outflow"])
	
	match clean_type:
		"transaction":
			totals["total_transactions"] = int(totals["total_transactions"]) + 1
		"decision":
			totals["total_decisions"] = int(totals["total_decisions"]) + 1
			if not tradeoff.is_empty():
				totals["total_tradeoffs"] = int(totals["total_tradeoffs"]) + 1
		"tradeoff":
			totals["total_tradeoffs"] = int(totals["total_tradeoffs"]) + 1
		"achievement":
			totals["total_achievements"] = int(totals["total_achievements"]) + 1
		"milestone":
			totals["total_milestones"] = int(totals["total_milestones"]) + 1
			
	if StatManager.employment_status == "laid_off":
		totals["was_laid_off"] = true
		
	on_entry_recorded.emit(entry)
	
	if clean_type != "achievement" and not _is_evaluating_achievements:
		evaluate_achievements(source)
		
	return entry

func record_transaction(
	category: String,
	source: String,
	title: String,
	summary: String,
	cash_delta: int,
	deltas: Dictionary = {},
	metadata: Dictionary = {}
) -> Dictionary:
	return record_entry("transaction", category, source, title, summary, cash_delta, deltas, {}, metadata)

func record_decision(
	category: String,
	source: String,
	title: String,
	summary: String,
	chosen_option: String,
	alternatives: Array = [],
	opportunity_cost_note: String = "",
	cash_delta: int = 0,
	deltas: Dictionary = {},
	metadata: Dictionary = {}
) -> Dictionary:
	var tf := {
		"chosen_option": chosen_option,
		"alternatives": alternatives.duplicate(true),
		"opportunity_cost_note": opportunity_cost_note
	}
	return record_entry("decision", category, source, title, summary, cash_delta, deltas, tf, metadata)

func record_tradeoff(
	category: String,
	source: String,
	title: String,
	summary: String,
	chosen_option: String,
	alternatives: Array = [],
	opportunity_cost_note: String = "",
	cash_delta: int = 0,
	deltas: Dictionary = {},
	metadata: Dictionary = {}
) -> Dictionary:
	# Unified taxonomy: every tradeoff IS a decision carrying structured alternatives & opportunity cost.
	return record_decision(category, source, title, summary, chosen_option, alternatives, opportunity_cost_note, cash_delta, deltas, metadata)

func record_milestone(
	category: String,
	source: String,
	title: String,
	summary: String,
	cash_delta: int = 0,
	deltas: Dictionary = {},
	metadata: Dictionary = {}
) -> Dictionary:
	return record_entry("milestone", category, source, title, summary, cash_delta, deltas, {}, metadata)

func _find_achievement_def(achievement_id: String) -> Dictionary:
	for def in ACHIEVEMENT_DEFINITIONS:
		if str(def["id"]) == achievement_id:
			return def
	return {}

func unlock_achievement(achievement_id: String, trigger_source: String = "system") -> bool:
	if unlocked_achievements.has(achievement_id):
		return false
	var def := _find_achievement_def(achievement_id)
	if def.is_empty():
		return false
	var gdate := _build_game_date()
	var date_txt := "%s %d, 2026" % [gdate["month_name"], gdate["day"]]
	var ach_record := {
		"id": achievement_id,
		"title": str(def["title"]),
		"subtitle": str(def["subtitle"]),
		"description": str(def["description"]),
		"lesson": str(def["lesson"]),
		"unlocked_date_text": date_txt,
		"unlocked_month_index": gdate["month_index"],
		"unlocked_day": gdate["day"],
		"unlocked_at_iso": Time.get_datetime_string_from_system(false, true),
		"trigger_source": trigger_source
	}
	unlocked_achievements[achievement_id] = ach_record
	
	var entry := record_entry(
		"achievement",
		"Achievement",
		"ledger_achievements",
		"Achievement Unlocked: " + str(def["title"]),
		str(def["description"]) + " — " + str(def["lesson"]),
		0,
		{},
		{},
		{"achievement_id": achievement_id, "trigger_source": trigger_source}
	)
	ach_record["unlocked_seq_id"] = int(entry.get("seq_id", 0))
	on_achievement_unlocked.emit(ach_record)
	return true

func evaluate_achievements(trigger_source: String = "") -> Array[Dictionary]:
	if _is_evaluating_achievements:
		return []
	_is_evaluating_achievements = true
	var newly_unlocked: Array[Dictionary] = []
	
	var checks := [
		["first_goal_set", StatManager.has_selected_goal],
		["first_paycheck", int(totals.get("total_inflow", 0)) >= 5000 and StatManager.current_day >= 1],
		["smart_budgeter", StatManager.get_envelope_amount("Rent") >= StatManager.monthly_rent and StatManager.get_envelope_amount("Utilities") >= (StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support)],
		["bills_autopaid", int(totals.get("bills_autopaid_count", 0)) >= 1],
		["discipline_streak_2", StatManager.envelope_discipline_streak >= 2],
		["discipline_streak_4", StatManager.envelope_discipline_streak >= 4],
		["first_savings_5k", StatManager.savings >= 5000],
		["emergency_buffer_20k", StatManager.savings >= 20000],
		["compounding_magic", StatManager.total_savings_interest_earned >= 1000],
		["credit_responsible", StatManager.credit_score >= 80 and StatManager.debt_balance == 0],
		["first_investor", StatManager.total_investment_principal > 0 or StatManager.get_total_investments() > 0],
		["layoff_survivor", bool(totals.get("was_laid_off", false)) and StatManager.employment_status in ["temporary_job", "new_stable_job"] and StatManager.debt_balance == 0],
		["goal_achieved", StatManager.has_selected_goal and StatManager.savings >= StatManager.get_goal_target()]
	]
	
	for pair in checks:
		var ach_id: String = str(pair[0])
		var cond: bool = bool(pair[1])
		if cond and not unlocked_achievements.has(ach_id):
			if unlock_achievement(ach_id, trigger_source):
				newly_unlocked.append(unlocked_achievements[ach_id])
				
	_is_evaluating_achievements = false
	return newly_unlocked

func get_achievements_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for def in ACHIEVEMENT_DEFINITIONS:
		var aid: String = str(def["id"])
		var item: Dictionary = def.duplicate(true)
		if unlocked_achievements.has(aid):
			item["unlocked"] = true
			item["unlocked_date_text"] = str(unlocked_achievements[aid].get("unlocked_date_text", ""))
			item["unlocked_seq_id"] = int(unlocked_achievements[aid].get("unlocked_seq_id", 0))
		else:
			item["unlocked"] = false
			item["unlocked_date_text"] = ""
			item["unlocked_seq_id"] = 0
		catalog.append(item)
	return catalog

func get_unlocked_achievements_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def in ACHIEVEMENT_DEFINITIONS:
		var aid: String = str(def["id"])
		if unlocked_achievements.has(aid):
			out.append(unlocked_achievements[aid].duplicate(true))
	return out

func get_filtered_entries(filter_type: String = "all", category_filter: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f_low := filter_type.to_lower()
	var c_low := category_filter.to_lower()
	for e in entries:
		var et: String = str(e.get("entry_type", ""))
		if f_low != "all":
			if f_low == "transaction" or f_low == "transactions" or f_low == "cash_flow":
				if et != "transaction" and int(e.get("cash_delta", 0)) == 0:
					continue
			elif f_low == "decision" or f_low == "decisions" or f_low == "tradeoff" or f_low == "tradeoffs":
				if et != "decision":
					continue
			elif f_low == "achievement" or f_low == "achievements":
				if et != "achievement":
					continue
			elif et != f_low:
				continue
		if c_low != "" and str(e.get("category", "")).to_lower() != c_low:
			continue
		out.append(e)
	return out

func get_analytics_summary() -> Dictionary:
	var snap := capture_state_snapshot()
	var inflow: int = int(totals.get("total_inflow", 0))
	var outflow: int = int(totals.get("total_outflow", 0))
	var savings_rate_pct: int = 0
	if inflow > 0:
		savings_rate_pct = int(clamp(round(float(StatManager.savings) / float(inflow) * 100.0), 0.0, 100.0))
	return {
		"run_id": run_id,
		"entry_count": entries.size(),
		"total_inflow": inflow,
		"total_outflow": outflow,
		"net_cash_flow": inflow - outflow,
		"savings_rate_pct": savings_rate_pct,
		"net_worth": int(snap.get("net_worth", 0)),
		"decisions_count": int(totals.get("total_decisions", 0)),
		"tradeoffs_count": int(totals.get("total_tradeoffs", 0)),
		"transactions_count": int(totals.get("total_transactions", 0)),
		"achievements_unlocked": unlocked_achievements.size(),
		"achievements_total": ACHIEVEMENT_DEFINITIONS.size(),
		"bills_autopaid_count": int(totals.get("bills_autopaid_count", 0)),
		"bills_shortfall_count": int(totals.get("bills_shortfall_count", 0)),
		"credit_paid_full_count": int(totals.get("credit_paid_full_count", 0)),
		"credit_paid_min_count": int(totals.get("credit_paid_min_count", 0)),
		"routine_changes_count": int(totals.get("routine_changes_count", 0))
	}

func get_ledger_summary_for_ai(recent_limit: int = 6) -> String:
	var stats := get_analytics_summary()
	var lines: Array[String] = []
	lines.append("=== MASTER LEDGER BEHAVIORAL DATA (LedgerManager) ===")
	lines.append("- Run ID: %s | Total Recorded Entries: %d | Achievements: %d/%d" % [
		run_id, stats["entry_count"], stats["achievements_unlocked"], stats["achievements_total"]
	])
	lines.append("- Cumulative Cash Flow: Total Inflow = PHP %d | Total Outflow = PHP %d | Net = PHP %d | Net Worth = PHP %d | Savings Rate = %d%%" % [
		stats["total_inflow"], stats["total_outflow"], stats["net_cash_flow"], stats["net_worth"], stats["savings_rate_pct"]
	])
	lines.append("- Behavioral Counters: Decisions = %d | Tradeoffs = %d | Bills Auto-Paid = %d | Bill Shortfalls = %d | CC Paid Full = %d | CC Paid Min = %d" % [
		stats["decisions_count"], stats["tradeoffs_count"], stats["bills_autopaid_count"], stats["bills_shortfall_count"], stats["credit_paid_full_count"], stats["credit_paid_min_count"]
	])
	var ach_names: Array[String] = []
	for a in get_unlocked_achievements_list():
		ach_names.append(str(a["title"]))
	lines.append("- Unlocked Achievements: " + (", ".join(ach_names) if not ach_names.is_empty() else "None yet"))
	
	# Recent key decisions / tradeoffs / transactions (skip routine spam so AI sees high-signal entries)
	var high_signal: Array[Dictionary] = []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		if str(e.get("category", "")) == "Daily Routine" and str(e.get("entry_type", "")) == "transaction":
			continue
		high_signal.append(e)
		if high_signal.size() >= recent_limit:
			break
	if not high_signal.is_empty():
		lines.append("- Recent High-Signal Ledger Entries:")
		high_signal.reverse()
		for e in high_signal:
			var tf: Dictionary = e.get("tradeoff", {})
			var tf_note := ""
			if not tf.is_empty() and str(tf.get("opportunity_cost_note", "")) != "":
				tf_note = " [Tradeoff: " + str(tf["opportunity_cost_note"]) + "]"
			lines.append("  * #%d [%s | %s] %s: %s (Cash Delta: %d)%s" % [
				int(e["seq_id"]), str(e["date_label"]), str(e["entry_type"]).to_upper(), str(e["title"]), str(e["summary"]), int(e["cash_delta"]), tf_note
			])
	return "\n".join(lines) + "\n"

func build_export_payload() -> Dictionary:
	var g := StatManager.get_current_goal()
	return {
		"schema_version": SCHEMA_VERSION,
		"game": "Paldo",
		"run_id": run_id,
		"run_started_at_iso": run_started_at_iso,
		"exported_at_iso": Time.get_datetime_string_from_system(false, true),
		"goal": {
			"id": str(g.get("id", "")),
			"title": str(g.get("title", "")),
			"cost": int(g.get("cost", 0)),
			"selected": StatManager.has_selected_goal
		},
		"analytics_summary": get_analytics_summary(),
		"totals": totals.duplicate(true),
		"final_state_snapshot": capture_state_snapshot(),
		"achievements_unlocked": get_unlocked_achievements_list(),
		"entries": entries.duplicate(true)
	}

func _csv_escape(value: Variant) -> String:
	var s := str(value).replace("\r", " ").replace("\n", " | ")
	if "," in s or "\"" in s:
		s = "\"" + s.replace("\"", "\"\"") + "\""
	return s

func build_csv_string() -> String:
	var header := [
		"seq_id",
		"run_id",
		"real_timestamp_iso",
		"stage",
		"month_index",
		"month_name",
		"day",
		"weekday",
		"phase",
		"entry_type",
		"category",
		"source",
		"title",
		"summary",
		"cash_delta",
		"delta_savings",
		"delta_credit_balance",
		"delta_debt",
		"delta_happy",
		"delta_social",
		"delta_credit_score",
		"chosen_option",
		"alternatives_count",
		"opportunity_cost_note",
		"after_cash",
		"after_savings",
		"after_credit_balance",
		"after_debt",
		"after_loans",
		"after_investments",
		"after_net_worth",
		"after_happy",
		"after_social",
		"after_credit_score",
		"after_goal_progress_pct"
	]
	var lines: Array[String] = [",".join(header)]
	for e in entries:
		var gd: Dictionary = e.get("game_date", {})
		var dl: Dictionary = e.get("deltas", {})
		var tf: Dictionary = e.get("tradeoff", {})
		var sp: Dictionary = e.get("snapshot_after", {})
		var alts: Array = tf.get("alternatives", [])
		var row := [
			_csv_escape(e.get("seq_id", 0)),
			_csv_escape(e.get("run_id", "")),
			_csv_escape(e.get("real_timestamp_iso", "")),
			_csv_escape(gd.get("stage", 1)),
			_csv_escape(gd.get("month_index", 0)),
			_csv_escape(gd.get("month_name", "")),
			_csv_escape(gd.get("day", 1)),
			_csv_escape(gd.get("weekday", "")),
			_csv_escape(gd.get("phase_name", "")),
			_csv_escape(e.get("entry_type", "")),
			_csv_escape(e.get("category", "")),
			_csv_escape(e.get("source", "")),
			_csv_escape(e.get("title", "")),
			_csv_escape(e.get("summary", "")),
			_csv_escape(e.get("cash_delta", 0)),
			_csv_escape(dl.get("savings", 0)),
			_csv_escape(dl.get("credit_balance", 0)),
			_csv_escape(dl.get("debt_balance", 0)),
			_csv_escape(dl.get("happy", 0)),
			_csv_escape(dl.get("social", 0)),
			_csv_escape(dl.get("credit_score", 0)),
			_csv_escape(tf.get("chosen_option", "")),
			_csv_escape(alts.size()),
			_csv_escape(tf.get("opportunity_cost_note", "")),
			_csv_escape(sp.get("cash", 0)),
			_csv_escape(sp.get("savings", 0)),
			_csv_escape(sp.get("credit_balance", 0)),
			_csv_escape(sp.get("debt_balance", 0)),
			_csv_escape(sp.get("loan_balance", 0)),
			_csv_escape(sp.get("investments", 0)),
			_csv_escape(sp.get("net_worth", 0)),
			_csv_escape(sp.get("happy", 0)),
			_csv_escape(sp.get("social", 0)),
			_csv_escape(sp.get("credit_score", 0)),
			_csv_escape(sp.get("goal_progress_pct", 0))
		]
		lines.append(",".join(row))
	return "\n".join(lines) + "\n"

func autosave_ledger() -> bool:
	var path := "user://ledger_latest.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(build_export_payload(), "\t"))
	file.close()
	return true

func _build_friendly_export_stem() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var date_part := "%04d-%02d-%02d" % [int(dt.get("year", 2026)), int(dt.get("month", 1)), int(dt.get("day", 1))]
	var short_id: String = run_id.right(4) if run_id.length() >= 4 else run_id
	return "Paldo_Ledger_" + date_part + "_" + short_id

func resolve_device_downloads_dir() -> Dictionary:
	# Prefer the OS Downloads folder so files appear directly where players expect downloads.
	var dl_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl_dir != "" and DirAccess.dir_exists_absolute(dl_dir):
		return {"path": dl_dir, "label": "Downloads"}
	var doc_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if doc_dir != "" and DirAccess.dir_exists_absolute(doc_dir):
		return {"path": doc_dir, "label": "Documents"}
	var fallback_abs: String = ProjectSettings.globalize_path("user://ledger_exports")
	DirAccess.make_dir_recursive_absolute(fallback_abs)
	return {"path": fallback_abs, "label": "App Data"}

func export_to_device_downloads() -> Dictionary:
	var stem := _build_friendly_export_stem()
	var csv_filename := stem + ".csv"
	var json_filename := stem + ".json"
	var csv_str := build_csv_string()
	var json_str := JSON.stringify(build_export_payload(), "\t")
	
	# Web / HTML5 builds: trigger native browser file downloads directly!
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		JavaScriptBridge.download_buffer(csv_str.to_utf8_buffer(), csv_filename, "text/csv")
		JavaScriptBridge.download_buffer(json_str.to_utf8_buffer(), json_filename, "application/json")
		autosave_ledger()
		return {
			"ok": true,
			"folder_path": "",
			"folder_label": "Browser Downloads",
			"json_path": json_filename,
			"csv_path": csv_filename,
			"json_filename": json_filename,
			"csv_filename": csv_filename,
			"entry_count": entries.size(),
			"error": ""
		}
		
	var target_info := resolve_device_downloads_dir()
	var res := export_ledger_files(str(target_info["path"]), stem)
	res["folder_path"] = str(target_info["path"])
	res["folder_label"] = str(target_info["label"])
	res["csv_filename"] = csv_filename
	res["json_filename"] = json_filename
	return res

func export_single_file(absolute_path: String) -> Dictionary:
	var clean_path := absolute_path.strip_edges()
	if clean_path == "":
		return {"ok": false, "path": "", "error": "Empty path"}
	var is_json := clean_path.to_lower().ends_with(".json")
	var content := JSON.stringify(build_export_payload(), "\t") if is_json else build_csv_string()
	var f := FileAccess.open(clean_path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "path": clean_path, "error": "Could not write file to selected location"}
	f.store_string(content)
	f.close()
	autosave_ledger()
	return {
		"ok": true,
		"path": clean_path,
		"filename": clean_path.get_file(),
		"format": "JSON" if is_json else "CSV",
		"entry_count": entries.size(),
		"error": ""
	}

func open_export_folder(folder_path: String) -> void:
	if folder_path == "" or DisplayServer.get_name() == "headless":
		return
	OS.shell_open(folder_path)

func export_ledger_files(custom_dir: String = "user://ledger_exports", custom_stem: String = "") -> Dictionary:
	var target_abs: String = custom_dir if custom_dir.is_absolute_path() else ProjectSettings.globalize_path(custom_dir)
	var dir_err := DirAccess.make_dir_recursive_absolute(target_abs)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		return {
			"ok": false,
			"folder_path": "",
			"folder_label": "",
			"json_path": "",
			"csv_path": "",
			"entry_count": entries.size(),
			"error": "Could not create export directory (err " + str(dir_err) + ")"
		}
	var base_name := custom_stem if custom_stem != "" else ("paldo_ledger_" + run_id)
	var json_path := target_abs.path_join(base_name + ".json")
	var csv_path := target_abs.path_join(base_name + ".csv")
	
	var jf := FileAccess.open(json_path, FileAccess.WRITE)
	if jf == null:
		return {
			"ok": false,
			"folder_path": target_abs,
			"folder_label": "",
			"json_path": "",
			"csv_path": "",
			"entry_count": entries.size(),
			"error": "Failed to write JSON file"
		}
	jf.store_string(JSON.stringify(build_export_payload(), "\t"))
	jf.close()
	
	var cf := FileAccess.open(csv_path, FileAccess.WRITE)
	if cf == null:
		return {
			"ok": false,
			"folder_path": target_abs,
			"folder_label": "",
			"json_path": json_path,
			"csv_path": "",
			"entry_count": entries.size(),
			"error": "Failed to write CSV file"
		}
	cf.store_string(build_csv_string())
	cf.close()
	
	autosave_ledger()
	return {
		"ok": true,
		"folder_path": target_abs,
		"folder_label": "Downloads" if target_abs == OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS) else "Folder",
		"json_path": json_path,
		"csv_path": csv_path,
		"json_filename": base_name + ".json",
		"csv_filename": base_name + ".csv",
		"entry_count": entries.size(),
		"error": ""
	}
