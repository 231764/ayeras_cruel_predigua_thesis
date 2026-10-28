extends Node2D

@onready var available_cash_label: Label = get_node_or_null("TopBudgetBar/HBoxContainer/AvailableCashLabel")
@onready var fund_bills_btn: Button = get_node_or_null("TopBudgetBar/HBoxContainer/FundBillsButton")
@onready var auto_budget_btn: Button = get_node_or_null("TopBudgetBar/HBoxContainer/AutoBudgetButton")
@onready var category_tabs_hbox: HBoxContainer = get_node_or_null("CategoryTabsHBox")

var current_envelope = 0
var _tab_buttons: Array[Button] = []

const TAB_LABELS := {
	"Food": "🍔 Pagkain",
	"Transportation": "🚌 Byahe",
	"Entertainment": "🎉 Libangan",
	"Rent": "🏠 Upa",
	"Utilities": "⚡ Bills",
	"Credit Card": "💳 Credit",
	"Savings": "🏺 Ipon"
}

func select_envelope(idx: int) -> void:
	if idx >= 0 and idx < StatManager.envelopes.size():
		current_envelope = idx
		update_envelope()

func next_envelope() -> void:
	current_envelope += 1
	if current_envelope >= StatManager.envelopes.size():
		current_envelope = 0
	update_envelope()
	
func previous_envelope() -> void:
	current_envelope -= 1
	if current_envelope < 0:
		current_envelope = StatManager.envelopes.size() - 1
	update_envelope()
	
func update_envelope() -> void:
	var envelope = StatManager.envelopes[current_envelope]
	var category = envelope["category"]
	var amount = envelope["amount"]
	var display_name = envelope["display_name"]
	$Envelope.setup(category, amount, display_name)
	_refresh_top_bar_and_tabs()

func _build_category_tabs() -> void:
	if not category_tabs_hbox:
		return
	for child in category_tabs_hbox.get_children():
		category_tabs_hbox.remove_child(child)
		child.queue_free()
	_tab_buttons.clear()
	for i in range(StatManager.envelopes.size()):
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		var idx := i
		btn.pressed.connect(func(): select_envelope(idx))
		category_tabs_hbox.add_child(btn)
		_tab_buttons.append(btn)

func _refresh_top_bar_and_tabs() -> void:
	if available_cash_label:
		available_cash_label.text = "💵 Hawak na Cash: PHP " + str(StatManager.current_balance)
	if fund_bills_btn:
		var bill_short := StatManager.get_envelope_shortfall_to_target("Rent") + StatManager.get_envelope_shortfall_to_target("Utilities")
		if bill_short > 0:
			fund_bills_btn.text = "🏠 Pondohan Upa & Bills (+₱" + str(min(StatManager.current_balance, bill_short)) + ")"
			fund_bills_btn.disabled = (StatManager.current_balance <= 0)
		else:
			fund_bills_btn.text = "✅ Upa & Bills Ready"
			fund_bills_btn.disabled = true
	if auto_budget_btn:
		auto_budget_btn.disabled = (StatManager.current_balance <= 0)
		
	if _tab_buttons.size() != StatManager.envelopes.size():
		_build_category_tabs()
	for i in range(_tab_buttons.size()):
		var env: Dictionary = StatManager.envelopes[i]
		var cat: String = str(env["category"])
		var amt: int = int(env["amount"])
		var short_lbl: String = TAB_LABELS.get(cat, cat)
		_tab_buttons[i].text = short_lbl + "\n₱" + str(amt)
		if i == current_envelope:
			_tab_buttons[i].modulate = Color(1.0, 0.92, 0.45, 1.0)
		else:
			_tab_buttons[i].modulate = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	_build_category_tabs()
	StatManager.on_stats_changed.connect(update_envelope)
	visibility_changed.connect(func():
		if visible:
			update_envelope()
	)
	update_envelope()

func _on_fund_bills_pressed() -> void:
	StatManager.fund_fixed_bills_envelopes()
	update_envelope()

func _on_auto_budget_pressed() -> void:
	StatManager.auto_budget_paycheck()
	update_envelope()

func _on_left_button_pressed() -> void:
	previous_envelope()

func _on_right_button_pressed() -> void:
	next_envelope()
