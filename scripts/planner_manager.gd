extends Node

var entries = [] # Array of player note dictionaries: {"Month": int, "Day": int, "Text": String}
var recorded_events = [] # Array of event log dictionaries: {"Month": int, "Day": int, "Text": String}

func save_entry(month: int, day: int, text: String) -> void:
	# Checks if entry exists. If yes, rewrite existing note text.
	for entry in entries:
		if entry.get("Month") == month and entry.get("Day") == day:
			entry["Text"] = text
			return
	
	# Only append if non-empty
	if text.strip_edges() != "":
		entries.append({
			"Month": month,
			"Day": day,
			"Text": text
		})

func get_entry(month: int, day: int) -> String:
	for entry in entries:
		if entry.get("Month") == month and entry.get("Day") == day:
			return entry.get("Text", "")
	return ""

func record_event(month: int, day: int, text: String) -> void:
	recorded_events.append({
		"Month": month,
		"Day": day,
		"Text": text
	})

func get_recorded_events(month: int, day: int) -> String:
	var result = ""
	for ev in recorded_events:
		if ev.get("Month") == month and ev.get("Day") == day:
			result += "• " + ev.get("Text", "") + "\n"
	return result

func has_events_on_day(month: int, day: int) -> bool:
	for ev in recorded_events:
		if ev.get("Month") == month and ev.get("Day") == day:
			return true
	return false

func has_notes_on_day(month: int, day: int) -> bool:
	return get_entry(month, day).strip_edges() != ""

func has_scheduled_milestone(month: int, day: int) -> bool:
	var m_idx: int = clamp(month, 0, StatManager.year.size() - 1)
	var last_day: int = int(StatManager.year[m_idx].days)
	if day == 1 or day == 15 or day == last_day:
		return true
	if day == 25 and m_idx >= 2 and StatManager.has_credit_card:
		return true
	return false

func get_upcoming_milestones(month: int, day: int) -> String:
	var m_idx: int = clamp(month, 0, StatManager.year.size() - 1)
	var last_day: int = int(StatManager.year[m_idx].days)
	var lines: Array[String] = []
	if day == 1 or day == 15:
		lines.append("• [color=darkgreen]💰 Sahod Day (" + StatManager.get_employment_display_text() + ")[/color]")
	if day == 7 or day == 14 or day == 21 or day == 28:
		lines.append("• [color=darkblue]📊 Weekly Financial Summary (Week " + str(int(day / 7)) + ")[/color]")
	if day == 25 and m_idx >= 2 and StatManager.has_credit_card:
		lines.append("• [color=darkorange]💳 Credit Card Statement Billing Date[/color]")
	if day == last_day:
		var tot_util: int = StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
		lines.append("• [color=darkred]🏠 Katapusan Bills Due: Upa (PHP " + str(StatManager.monthly_rent) + ") + Utilities/Installments (PHP " + str(tot_util) + ") + 2% Savings Interest[/color]")
	return "\n".join(lines)

func reset_planner() -> void:
	entries.clear()
	recorded_events.clear()

func get_recent_logs_summary(limit: int = 8) -> String:
	if recorded_events.is_empty():
		return ""
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	var out = ""
	var start_idx = max(0, recorded_events.size() - limit)
	for i in range(start_idx, recorded_events.size()):
		var ev = recorded_events[i]
		var m_idx = clamp(int(ev.get("Month", 0)), 0, StatManager.year.size() - 1)
		var m_name = StatManager.year[m_idx].month
		var d_num = int(ev.get("Day", 1))
		var clean_text = regex.sub(str(ev.get("Text", "")), "", true).replace("\n", " ")
		out += "- " + m_name + " " + str(d_num) + ": " + clean_text + "\n"
	return out
