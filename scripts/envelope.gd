extends Node2D

const UITheme = preload("res://scripts/ui_theme.gd")

@export var category_label: Label
@export var amount_label: Label
@export var money_edit: TextEdit

@onready var target_info_label: Label = get_node_or_null("TargetInfoLabel")
@onready var target_progress_bar: ProgressBar = get_node_or_null("TargetProgressBar")
@onready var fill_target_btn: Button = get_node_or_null("QuickChipsHBox/FillTargetButton")
@onready var plus_500_btn: Button = get_node_or_null("QuickChipsHBox/Plus500Button")
@onready var plus_1000_btn: Button = get_node_or_null("QuickChipsHBox/Plus1000Button")
@onready var minus_500_btn: Button = get_node_or_null("QuickChipsHBox/Minus500Button")
@onready var submit_btn: Button = get_node_or_null("SubmitMoney")
@onready var withdraw_btn: Button = get_node_or_null("WithdrawMoney")

var amount: int = 0
var category: String = ""
var display_name: String = ""

func _apply_visual_styles() -> void:
	UITheme.style_Button(plus_500_btn, UITheme.PAPER_CREAM, 8, 4, 10.0, 5.0)
	UITheme.style_Button(plus_1000_btn, UITheme.PAPER_CREAM, 8, 4, 10.0, 5.0)
	UITheme.style_Button(fill_target_btn, UITheme.BTN_GOLD, 8, 4, 10.0, 5.0)
	UITheme.style_Button(minus_500_btn, UITheme.PAPER_WARM, 8, 4, 10.0, 5.0)
	UITheme.style_Button(submit_btn, UITheme.BTN_SAGE, 8, 5, 12.0, 6.0)
	UITheme.style_Button(withdraw_btn, UITheme.BTN_CORAL, 8, 5, 12.0, 6.0)
	if money_edit:
		var ed_sb := UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 8, 2, 4, 10.0, 6.0)
		var ed_focus := UITheme.make_card_style(Color(1.0, 0.99, 0.95, 1.0), UITheme.INK_DARK, 8, 3, 4, 10.0, 6.0)
		money_edit.add_theme_stylebox_override("normal", ed_sb)
		money_edit.add_theme_stylebox_override("focus", ed_focus)
		money_edit.add_theme_color_override("font_color", UITheme.INK_DARK)
		money_edit.add_theme_color_override("font_placeholder_color", UITheme.INK_MUTED)
	UITheme.style_progress_bar(target_progress_bar, UITheme.BTN_SAGE, 7)

func setup(new_category: String, new_amount: int, new_display_name: String) -> void:
	category = new_category
	amount = new_amount
	display_name = new_display_name
	update_display()

func update_display() -> void:
	category_label.text = display_name
	amount_label.text = "₱" + str(amount)
	var target := StatManager.get_envelope_recommended_target(category)
	var short := StatManager.get_envelope_shortfall_to_target(category)
	if target_progress_bar:
		if target > 0:
			target_progress_bar.max_value = float(target)
			target_progress_bar.value = float(min(amount, target))
			target_progress_bar.visible = true
		else:
			target_progress_bar.max_value = 100.0
			target_progress_bar.value = 100.0
			target_progress_bar.visible = false
	if target_info_label:
		match category:
			"Food":
				var days_left: int = int(amount / max(1, StatManager.get_daily_food_cost()))
				target_info_label.text = "15-Day Target: ₱" + str(target) + " | Runway: " + str(days_left) + " araw"
			"Transportation":
				var days_left: int = int(amount / max(1, StatManager.get_daily_commute_cost()))
				target_info_label.text = "15-Day Target: ₱" + str(target) + " | Runway: " + str(days_left) + " araw"
			"Rent":
				target_info_label.text = "Monthly Bill: ₱" + str(target) + (" [KUMPLETO]" if short == 0 else " (Kulang: ₱" + str(short) + ")")
			"Utilities":
				target_info_label.text = "Total Bills Due: ₱" + str(target) + (" [KUMPLETO]" if short == 0 else " (Kulang: ₱" + str(short) + ")")
			"Entertainment":
				target_info_label.text = "Pang-Weekend Barkada & Pamilya (Rec: ₱" + str(target) + ")"
			"Credit Card":
				target_info_label.text = "Card Balance: ₱" + str(target) + (" [HANDA]" if short == 0 else " (Kulang: ₱" + str(short) + ")")
			"Savings":
				target_info_label.text = "1-Year Life Goal: ₱" + str(target) + " (+2%/mo Compounding)"
			_:
				target_info_label.text = "Target: ₱" + str(target)
	if fill_target_btn:
		if short > 0:
			var fill_amt: int = min(StatManager.current_balance, short)
			fill_target_btn.text = "Fill Target (+₱" + str(fill_amt) + ")"
			fill_target_btn.disabled = (fill_amt <= 0)
		else:
			fill_target_btn.text = "Target Met"
			fill_target_btn.disabled = true
	if plus_500_btn:
		plus_500_btn.disabled = (StatManager.current_balance <= 0)
	if plus_1000_btn:
		plus_1000_btn.disabled = (StatManager.current_balance <= 0)
	if minus_500_btn:
		minus_500_btn.disabled = (amount <= 0)

func add_money(value: int) -> void:
	if StatManager.current_balance >= value and value > 0:
		if category == "Savings":
			StatManager.deposit_savings(value)
			amount = StatManager.savings
			update_display()
			return
			
		StatManager.current_balance -= value
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] += value
				break
		amount += value
		update_display()
		StatManager.on_stats_changed.emit()

func remove_money(value: int) -> void:
	if amount >= value and value > 0:
		if category == "Savings":
			StatManager.withdraw_savings(value)
			amount = StatManager.savings
			update_display()
			return
			
		StatManager.current_balance += value
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] -= value
				break
		amount -= value
		update_display()
		StatManager.on_stats_changed.emit()

func _ready() -> void:
	_apply_visual_styles()

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

func _on_plus_500_pressed() -> void:
	var to_add: int = min(500, StatManager.current_balance)
	if to_add > 0:
		add_money(to_add)

func _on_plus_1000_pressed() -> void:
	var to_add: int = min(1000, StatManager.current_balance)
	if to_add > 0:
		add_money(to_add)

func _on_minus_500_pressed() -> void:
	var to_rem: int = min(500, amount)
	if to_rem > 0:
		remove_money(to_rem)

func _on_fill_target_pressed() -> void:
	var added := StatManager.fill_envelope_to_target(category)
	if added > 0:
		amount = StatManager.get_envelope_amount(category)
		update_display()
