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
	if(StatManager.current_balance > value):
		StatManager.current_balance -= value
		
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] += value
				break
		amount += value
		update_display()

func remove_money(value: int) -> void:
	if(amount > value):
		StatManager.current_balance += value
		
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] -= value
				break
		amount -= value
		update_display()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_submit_money_pressed() -> void:
	var amount = int(money_edit.text)
	add_money(amount)
	pass # Replace with function body.


func _on_withdraw_money_pressed() -> void:
	var amount = int(money_edit.text)
	remove_money(amount)
	pass # Replace with function body.
