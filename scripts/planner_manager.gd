extends Node


var entries = [] #An array of entries

func save_entry(month: int, day: int, text: String) -> void:
	#Checks if entry exists. If yes, rewrite existing note text.
	for entry in entries:
		if entry.get("Month") == month && entry.get("Day") == day:
			entry["Text"] = text
			return
	
	#If entry doesn't exist, so create a new one
	entries.append({
		"Month": month,
		"Day": day,
		"Text": text
	})
	


func get_entry(month: int, day: int) -> String:
	for entry in entries:
		if entry.get("Month") == month && entry.get("Day") == day:
			return entry.get("Text", "")
	
	return ""
