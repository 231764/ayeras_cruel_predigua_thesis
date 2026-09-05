extends Node

enum Phase {
	MORNING,
	AFTERNOON,
	EVENING
}

var current_day := 1
var current_month := 0
var week = 6
var current_phase = Phase.MORNING
var year := [
	{"month": "January", "days": 31},
	{"month": "February", "days": 29},
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

func next_phase():
	#trigger automatic payments?
	match current_phase:
		Phase.MORNING:
			current_phase = Phase.AFTERNOON

		Phase.AFTERNOON:
			current_phase = Phase.EVENING

		Phase.EVENING:
			next_day()
			current_phase = Phase.MORNING

func next_day() -> void:
		#temporarily placed in stat system, may be for a different script that handles the time cycle
	if (week == 0):
		print("new week!")
		week = 7
	current_day += 1
	week -= 1
	if (year[current_month].days < current_day):
		current_day = 1
		next_month()

func next_week() -> void:
	#WEEKLY SUMMARY function
	pass

func next_month() -> void:
	if (year[current_month].month == "December"):
		current_month = 0
	else: current_month += 1
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#func _on_timer_timeout() -> void:
	#print(StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day) + " " + Phase.keys()[current_phase])
	#next_phase()
	#pass # Replace with function body.
