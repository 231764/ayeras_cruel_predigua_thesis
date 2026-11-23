extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

signal goal_modal_closed

@onready var modal_panel: Panel = $Backdrop/Panel
@onready var title_label: Label = $Backdrop/Panel/VBoxContainer/TitleLabel
@onready var subtitle_label: RichTextLabel = $Backdrop/Panel/VBoxContainer/SubtitleLabel
@onready var goal_progress_bar: ProgressBar = $Backdrop/Panel/VBoxContainer/GoalProgressBar
@onready var options_container: VBoxContainer = $Backdrop/Panel/VBoxContainer/OptionsContainer
@onready var savings_controls: VBoxContainer = $Backdrop/Panel/VBoxContainer/SavingsControls
@onready var dep_500: Button = $Backdrop/Panel/VBoxContainer/SavingsControls/QuickDepositRow/Dep500
@onready var dep_1000: Button = $Backdrop/Panel/VBoxContainer/SavingsControls/QuickDepositRow/Dep1000
@onready var dep_2500: Button = $Backdrop/Panel/VBoxContainer/SavingsControls/QuickDepositRow/Dep2500
@onready var with_500: Button = $Backdrop/Panel/VBoxContainer/SavingsControls/QuickWithdrawRow/With500
@onready var with_1000: Button = $Backdrop/Panel/VBoxContainer/SavingsControls/QuickWithdrawRow/With1000
@onready var amount_input: LineEdit = $Backdrop/Panel/VBoxContainer/SavingsControls/CustomRow/AmountInput
@onready var custom_deposit_btn: Button = $Backdrop/Panel/VBoxContainer/SavingsControls/CustomRow/CustomDepositBtn
@onready var custom_withdraw_btn: Button = $Backdrop/Panel/VBoxContainer/SavingsControls/CustomRow/CustomWithdrawBtn
@onready var close_button: Button = $Backdrop/Panel/VBoxContainer/CloseButton

var is_selection_mode: bool = true
var _prog_overlay_lbl: Label = null

func _ready() -> void:
	visible = false
	_apply_visual_styles()
	if amount_input and not amount_input.text_submitted.is_connected(_on_amount_submitted):
		amount_input.text_submitted.connect(_on_amount_submitted)

func _animate_modal_in() -> void:
	if modal_panel:
		modal_panel.pivot_offset = modal_panel.size * 0.5
		modal_panel.scale = Vector2(0.96, 0.96)
		modal_panel.modulate = Color(1, 1, 1, 0.0)
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(modal_panel, "scale", Vector2(1.0, 1.0), 0.16)
		tw.tween_property(modal_panel, "modulate:a", 1.0, 0.14)

func _style_btn(btn: Button, bg: Color, radius: int = 8) -> void:
	UITheme.style_Button(btn, bg, radius, 4)

func _apply_visual_styles() -> void:
	UITheme.style_header_banner(title_label, UITheme.BTN_GOLD, 8, 6.0, UITheme.TYPE_HEADING)
	for d_btn in [dep_500, dep_1000, dep_2500, custom_deposit_btn]:
		_style_btn(d_btn, UITheme.BTN_SAGE, 8)
		UITheme.apply_type(d_btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	for w_btn in [with_500, with_1000, custom_withdraw_btn]:
		_style_btn(w_btn, UITheme.BTN_CORAL, 8)
		UITheme.apply_type(w_btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
	_style_btn(close_button, UITheme.BTN_GOLD, 8)
	UITheme.apply_type(close_button, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.set_button_icon(close_button, UITheme.ICON_ARROW_LEFT, false)
	UITheme.style_progress_bar(goal_progress_bar, UITheme.BTN_SAGE)
	if goal_progress_bar:
		goal_progress_bar.show_percentage = false
		_prog_overlay_lbl = Label.new()
		_prog_overlay_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		_prog_overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prog_overlay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_prog_overlay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.apply_type(_prog_overlay_lbl, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
		_prog_overlay_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
		_prog_overlay_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.94, 0.92))
		_prog_overlay_lbl.add_theme_constant_override("outline_size", 3)
		goal_progress_bar.add_child(_prog_overlay_lbl)
	if amount_input:
		var in_sb := UITheme.make_card_style(Color(0.98, 0.96, 0.91, 1.0), UITheme.INK_BORDER, 8, 2, 3, 8.0)
		var foc_sb := UITheme.make_card_style(Color(1.0, 0.99, 0.95, 1.0), Color(0.18, 0.44, 0.25, 1.0), 8, 2, 3, 8.0)
		amount_input.add_theme_stylebox_override("normal", in_sb)
		amount_input.add_theme_stylebox_override("focus", foc_sb)
		amount_input.add_theme_color_override("font_color", UITheme.INK_DARK)
		amount_input.add_theme_color_override("font_placeholder_color", UITheme.INK_MUTED)
		amount_input.add_theme_color_override("caret_color", UITheme.INK_DARK)

func show_goal_selection() -> void:
	is_selection_mode = true
	visible = true
	_animate_modal_in()
	goal_progress_bar.visible = false
	savings_controls.visible = false
	close_button.visible = false
	options_container.visible = true
	
	title_label.text = "Piliin ang Iyong 1-Year Life Goal"
	subtitle_label.text = "[center]Abutin ang [b]Life Goal[/b] bago mag-Dec 31 habang pinapanatili: [color=#1c7033]Happy & Social 50+[/color], [color=#1c7033]Credit Score 70+[/color], at [color=#94520d]₱0 Utang[/color].[/center]"
	
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
		
	for i in range(StatManager.life_goals.size()):
		var g: Dictionary = StatManager.life_goals[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 102)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_btn(btn, UITheme.PAPER_KRAFT if i == 0 else UITheme.PAPER_CREAM, 10)
		
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 14.0
		hbox.offset_top = 8.0
		hbox.offset_right = -14.0
		hbox.offset_bottom = -8.0
		hbox.add_theme_constant_override("separation", 14)
		btn.add_child(hbox)
		
		# Illustrated Goal Icon frame
		if g.has("icon") and g["icon"] != null:
			var icon_frame := PanelContainer.new()
			icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_frame.custom_minimum_size = Vector2(76, 76)
			icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_frame.add_theme_stylebox_override("panel", UITheme.make_card_style(Color(0.99, 0.97, 0.92, 1.0), UITheme.INK_BORDER, 8, 2, 3, 4.0, 4.0))
			var tex_rect := TextureRect.new()
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.texture = g["icon"]
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_frame.add_child(tex_rect)
			hbox.add_child(icon_frame)
			
		var rtf := RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.fit_content = true
		rtf.scroll_active = false
		rtf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rtf.add_theme_color_override("default_color", UITheme.INK_DARK)
		rtf.add_theme_font_override("normal_font", UITheme.FONT_BODY)
		rtf.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
		rtf.add_theme_font_size_override("normal_font_size", UITheme.TYPE_BODY)
		rtf.add_theme_font_size_override("bold_font_size", UITheme.TYPE_SUBHEAD)
		
		var diff_str: String = str(g["difficulty"])
		var diff_color := "#1c7033" if diff_str == "Balanced" else ("#94520d" if diff_str == "Challenging" else "#a8261f")
		var rec_tag := "  •  [color=#1c7033]Recommended[/color]" if bool(g.get("recommended", false)) else ""
		rtf.text = "[b]" + str(g["title"]) + "[/b]\n[color=#94520d][b]₱" + UITheme.format_num(int(g["cost"])) + "[/b][/color]  •  [color=" + diff_color + "][b]" + diff_str + "[/b][/color]" + rec_tag + "\n[color=#423830]" + str(g["description"]) + "[/color]"
		hbox.add_child(rtf)
		
		btn.pressed.connect(func(idx = i): _on_goal_chosen(idx))
		options_container.add_child(btn)

func _on_goal_chosen(index: int) -> void:
	AudioManager.play_sfx("opportunity")
	StatManager.select_life_goal(index)
	var chosen: Dictionary = StatManager.get_current_goal()
	PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Piniling Life Goal: " + str(chosen["title"]) + " — Target ₱" + UITheme.format_num(int(chosen["cost"])))
	visible = false
	goal_modal_closed.emit()

func show_savings_and_goal_inspector() -> void:
	is_selection_mode = false
	visible = true
	_animate_modal_in()
	options_container.visible = false
	goal_progress_bar.visible = true
	savings_controls.visible = true
	close_button.visible = true
	_refresh_inspector_ui()

func _refresh_inspector_ui() -> void:
	var g: Dictionary = StatManager.get_current_goal()
	var target: int = StatManager.get_goal_target()
	var pct: int = StatManager.get_goal_progress_percent()
	var next_interest: int = int(round(float(StatManager.savings) * StatManager.savings_monthly_interest_rate)) if StatManager.savings > 0 else 0
	var rem: int = max(0, target - StatManager.savings)
	
	title_label.text = "Ipon (Savings) & Life Goal Tracker"
	goal_progress_bar.max_value = max(1, target)
	goal_progress_bar.value = min(StatManager.savings, target)
	if _prog_overlay_lbl:
		_prog_overlay_lbl.text = "₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(target) + "  •  " + str(pct) + "%"
	
	var txt := "[center][b]Piniling Life Goal:[/b] " + str(g["title"]) + " — [color=#94520d]₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(target) + " (" + str(pct) + "%)[/color]\n"
	txt += "Kulang pa: [b]₱" + UITheme.format_num(rem) + "[/b]  |  Hawak na Cash: [color=#1c7033][b]₱" + UITheme.format_num(StatManager.current_balance) + "[/b][/color]\n"
	txt += "[color=#1a4b7c]Digital Bank Interest (0.5%/buwan • 6%/yr): Susunod na tubo +₱" + UITheme.format_num(next_interest) + "  |  Kabuuang tubo: ₱" + UITheme.format_num(StatManager.total_savings_interest_earned) + "[/color][/center]"
	subtitle_label.text = txt
	
	if dep_500:
		dep_500.disabled = (StatManager.current_balance < 500)
	if dep_1000:
		dep_1000.disabled = (StatManager.current_balance < 1000)
	if dep_2500:
		dep_2500.disabled = (StatManager.current_balance < 2500)
	if with_500:
		with_500.disabled = (StatManager.savings < 500)
	if with_1000:
		with_1000.disabled = (StatManager.savings < 1000)

func _on_amount_submitted(_new_text: String) -> void:
	_on_custom_deposit_pressed()

func _on_quick_deposit(amount: int) -> void:
	if StatManager.deposit_savings(amount):
		AudioManager.play_sfx("coin")
		_refresh_inspector_ui()

func _on_quick_withdraw(amount: int) -> void:
	if StatManager.withdraw_savings(amount):
		AudioManager.play_sfx("spend")
		_refresh_inspector_ui()

func _on_custom_deposit_pressed() -> void:
	var val: int = amount_input.text.to_int()
	if val > 0 and StatManager.deposit_savings(val):
		AudioManager.play_sfx("coin")
		amount_input.text = ""
		_refresh_inspector_ui()

func _on_custom_withdraw_pressed() -> void:
	var val: int = amount_input.text.to_int()
	if val > 0 and StatManager.withdraw_savings(val):
		AudioManager.play_sfx("spend")
		amount_input.text = ""
		_refresh_inspector_ui()

func _on_close_button_pressed() -> void:
	AudioManager.play_sfx("tool_close")
	visible = false
	goal_modal_closed.emit()
