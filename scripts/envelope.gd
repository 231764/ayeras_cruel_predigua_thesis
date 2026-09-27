extends Node2D

@export var category_label: Label
@export var amount_label: Label
@export var money_edit: TextEdit

var amount
var category
var display_name

func setup(new_category: String, new_amount: int, new_display_name: String) -> void:
	category = new_category
	amount = new_amount
	display_name = new_display_name
	update_display()

func update_display() -> void:
	category_label.text = display_name
	amount_label.text = "₱" + str(amount)

func add_money(value: int) -> void:
	if(StatManager.current_balance >= value and value > 0):
		StatManager.current_balance -= value
		
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] += value
				break
		amount += value
		update_display()
		StatManager.on_stats_changed.emit()

func remove_money(value: int) -> void:
	if(amount >= value and value > 0):
		StatManager.current_balance += value
		
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] -= value
				break
		amount -= value
		update_display()
		StatManager.on_stats_changed.emit()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_submit_money_pressed() -> void:
	var parsed_amount = money_edit.text.to_int()
	if parsed_amount > 0:
		add_money(parsed_amount)
		money_edit.text = ""

func _on_withdraw_money_pressed() -> void:
	var parsed_amount = money_edit.text.to_int()
	if parsed_amount > 0:
		remove_money(parsed_amount)
		money_edit.text = ""
