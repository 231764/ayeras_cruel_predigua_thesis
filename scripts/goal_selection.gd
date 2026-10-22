extends CanvasLayer

signal goal_modal_closed

@onready var title_label: Label = $Backdrop/Panel/VBoxContainer/TitleLabel
@onready var subtitle_label: RichTextLabel = $Backdrop/Panel/VBoxContainer/SubtitleLabel
@onready var goal_progress_bar: ProgressBar = $Backdrop/Panel/VBoxContainer/GoalProgressBar
@onready var options_container: VBoxContainer = $Backdrop/Panel/VBoxContainer/OptionsContainer
@onready var savings_controls: VBoxContainer = $Backdrop/Panel/VBoxContainer/SavingsControls
@onready var amount_input: LineEdit = $Backdrop/Panel/VBoxContainer/SavingsControls/CustomRow/AmountInput
@onready var close_button: Button = $Backdrop/Panel/VBoxContainer/CloseButton

var is_selection_mode: bool = true

func _ready() -> void:
	visible = false

func show_goal_selection() -> void:
	is_selection_mode = true
	visible = true
	goal_progress_bar.visible = false
	savings_controls.visible = false
	close_button.visible = false
	options_container.visible = true
	
	title_label.text = "Piliin ang Iyong 1-Year Life Goal!"
	subtitle_label.text = "[center]Bilang breadwinner, kailangan mong maabot ang iyong [b]Life Goal[/b] bago matapos ang December 31 habang pinapanatiling [color=green]Happy >= 50[/color], [color=green]Social >= 50[/color], [color=green]Credit Score >= 70[/color], at [color=yellow]Zero Debt (PHP 0)[/color]![/center]"
	
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
		
	for i in range(StatManager.life_goals.size()):
		var g = StatManager.life_goals[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 72)
		
		var rtf = RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtf.set_anchors_preset(Control.PRESET_FULL_RECT)
		rtf.text = "[center][b]" + str(g["title"]) + " — PHP " + str(g["cost"]) + "[/b] [color=yellow](" + str(g["difficulty"]) + ")[/color]\n[font_size=13]" + str(g["description"]) + "[/font_size][/center]"
		btn.add_child(rtf)
		btn.pressed.connect(func(idx = i): _on_goal_chosen(idx))
		options_container.add_child(btn)

func _on_goal_chosen(index: int) -> void:
	StatManager.select_life_goal(index)
	var chosen = StatManager.get_current_goal()
	PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Piniling Life Goal: " + str(chosen["title"]) + " (Target: PHP " + str(chosen["cost"]) + ")")
	visible = false
	goal_modal_closed.emit()

func show_savings_and_goal_inspector() -> void:
	is_selection_mode = false
	visible = true
	options_container.visible = false
	goal_progress_bar.visible = true
	savings_controls.visible = true
	close_button.visible = true
	_refresh_inspector_ui()

func _refresh_inspector_ui() -> void:
	var g = StatManager.get_current_goal()
	var target = StatManager.get_goal_target()
	var pct = StatManager.get_goal_progress_percent()
	var next_interest = int(round(float(StatManager.savings) * StatManager.savings_monthly_interest_rate)) if StatManager.savings > 0 else 0
	var rem = max(0, target - StatManager.savings)
	
	title_label.text = "Ipon (Savings) & Life Goal Tracker"
	goal_progress_bar.max_value = target
	goal_progress_bar.value = min(StatManager.savings, target)
	
	var txt = "[center][b]Life Goal:[/b] " + str(g["title"]) + " ([color=yellow]PHP " + str(StatManager.savings) + " / PHP " + str(target) + " — " + str(pct) + "%[/color])\n"
	txt += "Kulang pa para sa Goal: [b]PHP " + str(rem) + "[/b] | Hawak na Cash: [color=green][b]PHP " + str(StatManager.current_balance) + "[/b][/color]\n"
	txt += "[color=lightblue]Bank Compounding Interest: +2% kada katapusan ng buwan (Susunod na tubo: +PHP " + str(next_interest) + " | Kabuuang tubo: PHP " + str(StatManager.total_savings_interest_earned) + ")[/color][/center]"
	subtitle_label.text = txt

func _on_quick_deposit(amount: int) -> void:
	if StatManager.deposit_savings(amount):
		_refresh_inspector_ui()

func _on_quick_withdraw(amount: int) -> void:
	if StatManager.withdraw_savings(amount):
		_refresh_inspector_ui()

func _on_custom_deposit_pressed() -> void:
	var val = amount_input.text.to_int()
	if val > 0 and StatManager.deposit_savings(val):
		amount_input.text = ""
		_refresh_inspector_ui()

func _on_custom_withdraw_pressed() -> void:
	var val = amount_input.text.to_int()
	if val > 0 and StatManager.withdraw_savings(val):
		amount_input.text = ""
		_refresh_inspector_ui()

func _on_close_button_pressed() -> void:
	visible = false
	goal_modal_closed.emit()
