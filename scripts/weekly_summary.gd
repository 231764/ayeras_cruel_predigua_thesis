extends CanvasLayer

@onready var title = $Panel/VBoxContainer/Title
@onready var income_label = $Panel/VBoxContainer/IncomeLabel
@onready var expenses_label = $Panel/VBoxContainer/ExpensesLabel
@onready var net_label = $Panel/VBoxContainer/NetLabel

signal summary_closed

func _ready() -> void:
	visible = false
	
func show_summary(week_num: int) -> void:
	show_summary_with_values(week_num, StatManager.weekly_income, StatManager.weekly_expenses)
	StatManager.weekly_income = 0
	StatManager.weekly_expenses = 0

func show_summary_with_values(week_num: int, income_val: int, expenses_val: int) -> void:
	title.text = "Katapusan ng Week " + str(week_num)
	income_label.text = "Pumasok na Pera: + PHP " + str(income_val)
	expenses_label.text = "Mga Nagastos: - PHP " + str(expenses_val)
	
	var net = income_val - expenses_val
	if net >= 0:
		net_label.text = "Natira sa Pera: + PHP " + str(net)
		net_label.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		net_label.text = "Natira sa Pera: - PHP " + str(abs(net))
		net_label.add_theme_color_override("font_color", Color(1, 0, 0))
		
	visible = true

func _on_continue_pressed() -> void:
	visible = false
	summary_closed.emit()
