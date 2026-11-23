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
	if category_label and category_label.label_settings:
		category_label.label_settings.font = UITheme.FONT_HEADING
		category_label.label_settings.font_size = UITheme.TYPE_HEADING
	if amount_label and amount_label.label_settings:
		amount_label.label_settings.font = UITheme.FONT_DISPLAY
		amount_label.label_settings.font_size = UITheme.TYPE_HERO_NUM
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
		money_edit.add_theme_font_override("font", UITheme.FONT_UI)
		money_edit.add_theme_font_size_override("font_size", UITheme.TYPE_BODY)
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
	amount_label.text = "₱" + UITheme.format_num(amount)
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
				target_info_label.text = "15-Day Target: ₱" + UITheme.format_num(target) + "  |  Runway: " + str(days_left) + " araw"
			"Transportation":
				if StatManager.employment_status == "laid_off":
					target_info_label.text = "Walang pasok ngayon — ₱0 ang araw-araw na byahe."
				else:
					var days_left: int = int(amount / max(1, StatManager.get_daily_commute_cost()))
					target_info_label.text = "Workday Target: ₱" + UITheme.format_num(target) + "  |  Runway: ~" + str(days_left) + " araw"
			"Rent":
				target_info_label.text = "Buwanang Upa: ₱" + UITheme.format_num(target) + (" — Kumpleto" if short == 0 else " — Kulang: ₱" + UITheme.format_num(short))
			"Utilities":
				target_info_label.text = "Buwanang Bills: ₱" + UITheme.format_num(target) + (" — Kumpleto" if short == 0 else " — Kulang: ₱" + UITheme.format_num(short))
			"Entertainment":
				target_info_label.text = "Pang-Weekend Barkada at Pamilya (Rec: ₱" + UITheme.format_num(target) + ")"
			"Credit Card":
				target_info_label.text = "Card Balance: ₱" + UITheme.format_num(target) + (" — Handa" if short == 0 else " — Kulang: ₱" + UITheme.format_num(short))
			"Savings":
				target_info_label.text = "1-Year Life Goal: ₱" + UITheme.format_num(target) + " (Digital Bank 6%/yr Compounding)"
			_:
				target_info_label.text = "Target: ₱" + UITheme.format_num(target)
	if fill_target_btn:
		if short > 0:
			var fill_amt: int = min(StatManager.current_balance, short)
			fill_target_btn.text = "Fill Target (+₱" + UITheme.format_num(fill_amt) + ")"
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
			
		var before := LedgerManager.capture_state_snapshot()
		StatManager.current_balance -= value
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] += value
				break
		amount += value
		update_display()
		StatManager.on_stats_changed.emit()
		LedgerManager.totals["total_envelope_allocations"] = int(LedgerManager.totals.get("total_envelope_allocations", 0)) + value
		LedgerManager.record_transaction(
			"Budgeting",
			"budgeting",
			"Envelope Deposit: " + category,
			"Allocated PHP " + str(value) + " from Pocket Cash into " + category + " envelope (New Balance: PHP " + str(amount) + ").",
			0,
			LedgerManager.compute_deltas(before, LedgerManager.capture_state_snapshot()),
			{"envelope": category, "amount": value, "direction": "deposit"}
		)

func remove_money(value: int) -> void:
	if amount >= value and value > 0:
		if category == "Savings":
			StatManager.withdraw_savings(value)
			amount = StatManager.savings
			update_display()
			return
			
		var before := LedgerManager.capture_state_snapshot()
		StatManager.current_balance += value
		for envelope in StatManager.envelopes:
			if envelope["category"] == category:
				envelope["amount"] -= value
				break
		amount -= value
		update_display()
		StatManager.on_stats_changed.emit()
		LedgerManager.record_transaction(
			"Budgeting",
			"budgeting",
			"Envelope Withdraw: " + category,
			"Returned PHP " + str(value) + " from " + category + " envelope back to Pocket Cash (Remaining: PHP " + str(amount) + ").",
			0,
			LedgerManager.compute_deltas(before, LedgerManager.capture_state_snapshot()),
			{"envelope": category, "amount": value, "direction": "withdraw"}
		)

func _ready() -> void:
	_apply_visual_styles()
	if money_edit:
		money_edit.gui_input.connect(_on_money_edit_gui_input)

func _on_money_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_submit_money_pressed()
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()

func _on_submit_money_pressed() -> void:
	var parsed_amount = money_edit.text.strip_edges().to_int()
	if parsed_amount > 0:
		add_money(parsed_amount)
		AudioManager.play_sfx("coin")
		money_edit.text = ""

func _on_withdraw_money_pressed() -> void:
	var parsed_amount = money_edit.text.strip_edges().to_int()
	if parsed_amount > 0:
		remove_money(parsed_amount)
		AudioManager.play_sfx("spend")
		money_edit.text = ""

func _on_plus_500_pressed() -> void:
	var to_add: int = min(500, StatManager.current_balance)
	if to_add > 0:
		add_money(to_add)
		AudioManager.play_sfx("coin")

func _on_plus_1000_pressed() -> void:
	var to_add: int = min(1000, StatManager.current_balance)
	if to_add > 0:
		add_money(to_add)
		AudioManager.play_sfx("coin")

func _on_minus_500_pressed() -> void:
	var to_rem: int = min(500, amount)
	if to_rem > 0:
		remove_money(to_rem)
		AudioManager.play_sfx("spend")

func _on_fill_target_pressed() -> void:
	var added := StatManager.fill_envelope_to_target(category)
	if added > 0:
		AudioManager.play_sfx("coin")
		amount = StatManager.get_envelope_amount(category)
		update_display()
