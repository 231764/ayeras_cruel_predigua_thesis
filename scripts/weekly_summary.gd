extends CanvasLayer

@onready var title = $Panel/VBoxContainer/Title
@onready var income_label = $Panel/VBoxContainer/IncomeLabel
@onready var expenses_label = $Panel/VBoxContainer/ExpensesLabel
@onready var net_label = $Panel/VBoxContainer/NetLabel

signal summary_closed

func _ready() -> void:
	visible = false
	
func show_summary(week_num: int) -> void:
	title.text = "Katapusan ng Week " + str(week_num)
	income_label.text = "Pumasok na Pera: + PHP " + str(StatManager.weekly_income)
	expenses_label.text = "Mga Nagastos: - PHP " + str(StatManager.weekly_expenses)
	
	var net = StatManager.weekly_income - StatManager.weekly_expenses
	if net >= 0:
		net_label.text = "Natira sa Pera: + PHP " + str(net)
		net_label.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		net_label.text = "Natira sa Pera: - PHP " + str(abs(net))
		net_label.add_theme_color_override("font_color", Color(1, 0, 0))
		
	visible = true

func _on_continue_pressed() -> void:
	# Reset weekly trackers
	StatManager.weekly_income = 0
	StatManager.weekly_expenses = 0
	visible = false
	summary_closed.emit()
