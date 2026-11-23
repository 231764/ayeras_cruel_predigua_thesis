extends Node2D

const UITheme = preload("res://scripts/ui_theme.gd")

@onready var top_budget_bar: Panel = get_node_or_null("TopBudgetBar")
@onready var available_cash_label: Label = get_node_or_null("TopBudgetBar/HBoxContainer/AvailableCashLabel")
@onready var fund_bills_btn: Button = get_node_or_null("TopBudgetBar/HBoxContainer/FundBillsButton")
@onready var auto_budget_btn: Button = get_node_or_null("TopBudgetBar/HBoxContainer/AutoBudgetButton")
@onready var action_feedback_label: Label = get_node_or_null("ActionFeedbackLabel")
@onready var category_tabs_hbox: HBoxContainer = get_node_or_null("CategoryTabsHBox")
@onready var left_btn: Button = get_node_or_null("LeftButton")
@onready var right_btn: Button = get_node_or_null("RightButton")

var current_envelope = 0
var _tab_buttons: Array[Button] = []

const TAB_LABELS := {
	"Food": "Pagkain",
	"Transportation": "Byahe",
	"Entertainment": "Libangan",
	"Rent": "Upa",
	"Utilities": "Bills",
	"Credit Card": "Credit",
	"Savings": "Ipon"
}

func _apply_budget_theme() -> void:
	if top_budget_bar:
		top_budget_bar.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 10, 3, 5, 14.0, 6.0))
	if available_cash_label:
		UITheme.apply_type(available_cash_label, UITheme.TYPE_SUBHEAD, UITheme.FONT_UI)
	UITheme.style_Button(fund_bills_btn, UITheme.BTN_SAGE, 8, 4, 10.0, 5.0)
	UITheme.apply_type(fund_bills_btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.style_Button(auto_budget_btn, UITheme.BTN_GOLD, 8, 4, 10.0, 5.0)
	UITheme.apply_type(auto_budget_btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.style_Button(left_btn, UITheme.PAPER_CREAM, 10, 5, 10.0, 6.0)
	UITheme.set_button_icon(left_btn, UITheme.ICON_ARROW_LEFT, false, true)
	UITheme.style_Button(right_btn, UITheme.PAPER_CREAM, 10, 5, 10.0, 6.0)
	UITheme.set_button_icon(right_btn, UITheme.ICON_ARROW_RIGHT, false, true)
	if action_feedback_label:
		UITheme.apply_type(action_feedback_label, UITheme.TYPE_BODY, UITheme.FONT_UI)

func select_envelope(idx: int) -> void:
	if idx >= 0 and idx < StatManager.envelopes.size():
		if idx != current_envelope:
			AudioManager.play_sfx("paper")
		current_envelope = idx
		update_envelope()

func next_envelope() -> void:
	AudioManager.play_sfx("paper")
	current_envelope += 1
	if current_envelope >= StatManager.envelopes.size():
		current_envelope = 0
	update_envelope()
	
func previous_envelope() -> void:
	AudioManager.play_sfx("paper")
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
		btn.add_theme_font_size_override("font_size", 14)
		var idx := i
		btn.pressed.connect(func(): select_envelope(idx))
		category_tabs_hbox.add_child(btn)
		_tab_buttons.append(btn)

func _refresh_top_bar_and_tabs() -> void:
	if available_cash_label:
		available_cash_label.text = "Hawak na Cash: ₱" + UITheme.format_num(StatManager.current_balance)
	if fund_bills_btn:
		var bill_short := StatManager.get_envelope_shortfall_to_target("Rent") + StatManager.get_envelope_shortfall_to_target("Utilities")
		if bill_short > 0:
			var can_add: int = min(StatManager.current_balance, bill_short)
			fund_bills_btn.text = "Pondohan Bills (+₱" + UITheme.format_num(can_add) + ")"
			fund_bills_btn.disabled = (can_add <= 0)
		else:
			fund_bills_btn.text = "Upa at Bills Handa (100%)"
			fund_bills_btn.disabled = false
	if auto_budget_btn:
		auto_budget_btn.disabled = (StatManager.current_balance <= 0)
		
	if _tab_buttons.size() != StatManager.envelopes.size():
		_build_category_tabs()
	for i in range(_tab_buttons.size()):
		var env: Dictionary = StatManager.envelopes[i]
		var cat: String = str(env["category"])
		var amt: int = int(env["amount"])
		var short_lbl: String = TAB_LABELS.get(cat, cat)
		_tab_buttons[i].text = short_lbl + "\n₱" + UITheme.format_num(amt)
		UITheme.apply_type(_tab_buttons[i], UITheme.TYPE_BODY, UITheme.FONT_UI)
		if i == current_envelope:
			UITheme.style_Button(_tab_buttons[i], UITheme.BTN_GOLD, 8, 5, 6.0, 4.0)
		else:
			UITheme.style_Button(_tab_buttons[i], UITheme.PAPER_CREAM, 8, 3, 6.0, 4.0)

func _ready() -> void:
	_apply_budget_theme()
	_build_category_tabs()
	StatManager.on_stats_changed.connect(update_envelope)
	visibility_changed.connect(func():
		if visible:
			update_envelope()
	)
	update_envelope()

func _on_fund_bills_pressed() -> void:
	var added := StatManager.fund_fixed_bills_envelopes()
	if added > 0:
		AudioManager.play_sfx("coin")
	else:
		AudioManager.play_sfx("click")
	# Jump to Rent envelope (index 3) so the player immediately sees the funded Fixed Bill envelope
	select_envelope(3)
	if action_feedback_label:
		if added > 0:
			action_feedback_label.text = "Nailaan ang +₱" + UITheme.format_num(added) + " sa Upa at Bills Envelopes."
		elif StatManager.get_envelope_shortfall_to_target("Rent") == 0 and StatManager.get_envelope_shortfall_to_target("Utilities") == 0:
			action_feedback_label.text = "Kumpleto na ang pondo sa Upa (₱" + UITheme.format_num(StatManager.monthly_rent) + ") at Bills!"
		else:
			action_feedback_label.text = "Kulang ang hawak na cash para pondohan ang Upa at Bills."

func _on_auto_budget_pressed() -> void:
	var res := StatManager.auto_budget_paycheck()
	var alloc := int(res.get("total_allocated", 0))
	if alloc > 0:
		AudioManager.play_sfx("coin")
	else:
		AudioManager.play_sfx("click")
	update_envelope()
	if action_feedback_label:
		if alloc > 0:
			action_feedback_label.text = "Na-split ang ₱" + UITheme.format_num(alloc) + " sa Upa, Bills, 15 araw na Pagkain/Byahe, Libangan, at Ipon."
		else:
			action_feedback_label.text = "Naka-budget na ang lahat ng Envelopes o kulang na ang hawak na cash."

func _on_left_button_pressed() -> void:
	previous_envelope()

func _on_right_button_pressed() -> void:
	next_envelope()
