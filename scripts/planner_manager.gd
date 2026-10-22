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
