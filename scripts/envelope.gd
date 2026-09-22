extends Node2D

@export var category_label: Label
@export var amount_label: Label
@export var money_edit: TextEdit

var amount
var category

func setup(new_category: String, new_amount: int) -> void:
	category = new_category
	amount = new_amount
	update_display()

func update_display() -> void:
	print(StatManager.current_balance)
	category_label.text = category
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
		# Update main UI to reflect balance change
		var main_scene = get_tree().current_scene
		if main_scene:
			var stat_sys = main_scene.find_child("Stat System", true, false)
			if stat_sys and stat_sys.has_method("update_ui"):
				stat_sys.update_ui()

func remove_money(value: int) -> void:
	if(amount >= value and value > 0):
		StatManager.current_balance += value
		
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] -= value
				break
		amount -= value
		update_display()
		# Update main UI to reflect balance change
		var main_scene = get_tree().current_scene
		if main_scene:
			var stat_sys = main_scene.find_child("Stat System", true, false)
			if stat_sys and stat_sys.has_method("update_ui"):
				stat_sys.update_ui()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_submit_money_pressed() -> void:
	var parsed_amount = int(money_edit.text)
	add_money(parsed_amount)
	pass # Replace with function body.


func _on_withdraw_money_pressed() -> void:
	var parsed_amount = int(money_edit.text)
	remove_money(parsed_amount)
	pass # Replace with function body.
