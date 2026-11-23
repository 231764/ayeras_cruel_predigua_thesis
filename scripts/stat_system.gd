extends Node2D

const UITheme = preload("res://scripts/ui_theme.gd")
const GameMenus = preload("res://scripts/game_menus.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

@export var happy_bar: ProgressBar
@export var social_bar: ProgressBar
@export var current_balance: Label
@export var savings: Label
@export var credit_balance: Label
@export var credit_score: Label
@export var debt_balance: Label
@export var date_label: Label
@export var status_report_label: RichTextLabel

@onready var happy_icon: TextureRect = $"Happiness Bar/Icon"

# Preload happiness assets
const JOYFUL = preload("res://assets/happy90.png")
const HAPPY = preload("res://assets/happy 60.png")
const NEUTRAL = preload("res://assets/neutral.png")
const SAD = preload("res://assets/sad40.png")
const DESPAIRED = preload("res://assets/sad10.png")

@onready var next_phase_button: Button = $NextPhaseButton
@onready var auto_advance_button: Button = get_node_or_null("AutoAdvanceButton")
@onready var goal_button: Button = $GoalButton
@onready var goal_icon: TextureButton = $GoalIcon
@onready var savings_jar_button: Button = $SavingsJarButton
@onready var envelope_runway_label: RichTextLabel = get_node_or_null("EnvelopeRunwayPanel/HBoxContainer/EnvelopeRunwayLabel")
@onready var baldo_avatar: TextureRect = get_node_or_null("BaldoToastPanel/HBoxContainer/TopRow/BaldoAvatar")
@onready var baldo_toast_label: RichTextLabel = get_node_or_null("BaldoToastPanel/HBoxContainer/TopRow/BaldoToastLabel")
@onready var baldo_smart_btn: Button = get_node_or_null("BaldoToastPanel/HBoxContainer/ActionRow/BaldoSmartActionButton")
@onready var ask_baldo_btn: Button = get_node_or_null("BaldoToastPanel/HBoxContainer/ActionRow/AskBaldoButton")
@onready var food_option: OptionButton = $DailyRoutinePanel/VBoxContainer/FoodHBox/FoodOption
@onready var commute_option: OptionButton = $DailyRoutinePanel/VBoxContainer/CommuteHBox/CommuteOption

var modal_queue: Array[Callable] = []
var is_modal_open: bool = false
var is_game_over: bool = false
var pending_desk_tool_to_open: String = ""

var is_auto_advancing: bool = false
var auto_advance_timer: Timer = null
var auto_pause_override_reason: String = ""
var _auto_started_with_food_env: bool = false
var _auto_started_with_trans_env: bool = false
var _auto_started_with_healthy_happy: bool = false
var _auto_started_with_healthy_social: bool = false

var _stats_baseline_initialized: bool = false
var _prev_balance: int = 0
var _prev_savings: int = 0
var _prev_credit_balance: int = 0
var _prev_credit_score: int = 0
var _prev_debt: int = 0
var _prev_happy: int = 0
var _prev_social: int = 0
var recent_floating_popups_count: int = 0
var last_floating_popup_text: String = ""
var _ach_toast_queue: Array[Dictionary] = []
var _is_showing_ach_toast: bool = false
var _ach_toast_layer: CanvasLayer = null
var _menu_button: Button = null
var _phone_badge: Label = null
var _goal_progress_card: PanelContainer = null
var _goal_progress_bar: ProgressBar = null
var _goal_progress_lbl: Label = null
var _pause_modal: CanvasLayer = null
var _last_tinted_phase: int = -1

func _ready() -> void:
	auto_advance_timer = Timer.new()
	auto_advance_timer.wait_time = AudioManager.get_autoplay_wait_time()
	auto_advance_timer.one_shot = false
	auto_advance_timer.timeout.connect(_on_auto_advance_tick)
	add_child(auto_advance_timer)
	_create_menu_and_desk_badges()
	_setup_shortcut_tooltips()
	_apply_hud_visual_theme()
	
	update_ui()
	StatManager.on_stats_changed.connect(update_ui)
	StatManager.on_mission_completed.connect(_on_mission_completed)
	StatManager.on_goal_milestone_reached.connect(_on_goal_milestone_reached)
	LedgerManager.on_achievement_unlocked.connect(_on_achievement_unlocked)
	
	EventManager.on_direct_event_triggered.connect(func(event_data):
		stop_auto_advance()
		AudioManager.play_sfx(_get_direct_event_sfx(event_data))
		_update_next_button_visibility()
	)
	
	EventManager.on_indirect_event_triggered.connect(func(_event_data):
		stop_auto_advance()
		AudioManager.play_sfx("phone_ding")
		update_ui()
	)
	
	EventManager.on_event_resolved.connect(func(_id):
		auto_pause_override_reason = ""
		AudioManager.play_sfx(_get_event_resolved_sfx())
		update_ui()
		_update_next_button_visibility()
	)
	
	# Initial day setup (salary + fallback goal modal) ONLY for a fresh unstarted run (not a loaded save!)
	if not StatManager.initial_day_started and StatManager.current_day == 1 and StatManager.current_month == 0 and StatManager.current_phase == 0:
		call_deferred("_start_initial_day")
	else:
		EventManager.call_deferred("evaluate_daily_events")

func _create_menu_and_desk_badges() -> void:
	_menu_button = Button.new()
	_menu_button.name = "PauseMenuButton"
	_menu_button.text = "Menu"
	_menu_button.tooltip_text = "Pause, Settings, Save & How to Play [Shortcut: Esc]"
	_menu_button.offset_left = 716.0
	_menu_button.offset_top = 10.0
	_menu_button.offset_right = 808.0
	_menu_button.offset_bottom = 48.0
	UITheme.apply_type(_menu_button, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.style_Button(_menu_button, UITheme.PAPER_CREAM, 8, 5, 10.0, 6.0)
	UITheme.set_button_icon(_menu_button, UITheme.ICON_MENU, false)
	_menu_button.pressed.connect(open_pause_menu)
	add_child(_menu_button)
	
	_phone_badge = Label.new()
	_phone_badge.name = "PhoneUnreadBadge"
	_phone_badge.offset_left = 955.0
	_phone_badge.offset_top = 312.0
	_phone_badge.offset_right = 1078.0
	_phone_badge.offset_bottom = 338.0
	_phone_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phone_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phone_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_type(_phone_badge, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	_phone_badge.add_theme_color_override("font_color", Color(1.0, 0.98, 0.94, 1.0))
	var pb_sb := UITheme.make_card_style(Color(0.76, 0.18, 0.14, 1.0), UITheme.INK_BORDER, 8, 2, 3, 6.0, 2.0)
	_phone_badge.add_theme_stylebox_override("normal", pb_sb)
	_phone_badge.visible = false
	add_child(_phone_badge)
	
	_goal_progress_card = PanelContainer.new()
	_goal_progress_card.name = "GoalProgressCard"
	_goal_progress_card.offset_left = 466.0
	_goal_progress_card.offset_top = 176.0
	_goal_progress_card.offset_right = 674.0
	_goal_progress_card.offset_bottom = 212.0
	_goal_progress_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_progress_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_STICKY, UITheme.INK_BORDER, 8, 2, 3, 6.0, 5.0))
	add_child(_goal_progress_card)

	_goal_progress_bar = ProgressBar.new()
	_goal_progress_bar.name = "GoalProgressBar"
	_goal_progress_bar.max_value = 100.0
	_goal_progress_bar.value = 0.0
	_goal_progress_bar.show_percentage = false
	_goal_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_progress_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_goal_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_progress_bar(_goal_progress_bar, UITheme.BTN_SAGE, 5)
	_goal_progress_card.add_child(_goal_progress_bar)

	_goal_progress_lbl = Label.new()
	_goal_progress_lbl.name = "GoalProgressLabel"
	_goal_progress_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goal_progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_progress_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_progress_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_type(_goal_progress_lbl, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	_goal_progress_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	_goal_progress_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.94, 0.92))
	_goal_progress_lbl.add_theme_constant_override("outline_size", 3)
	_goal_progress_bar.add_child(_goal_progress_lbl)

func open_pause_menu() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over or is_instance_valid(_pause_modal):
		return
	stop_auto_advance()
	AudioManager.play_sfx("click")
	_pause_modal = GameMenus.spawn_pause_modal(
		self,
		func():
			_pause_modal = null
			if auto_advance_timer:
				auto_advance_timer.wait_time = AudioManager.get_autoplay_wait_time(),
		func():
			_pause_modal = null
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)

func _get_direct_event_sfx(event_data: Dictionary) -> String:
	var eid := str(event_data.get("id", "")).to_lower()
	for urgent_kw in ["layoff", "health", "medical", "hospital", "condition_worsens", "debt", "crash", "downturn", "collector", "emergency", "late", "scam", "predatory"]:
		if urgent_kw in eid:
			return "alert"
	for opp_kw in ["job", "side_income", "sideline", "bonus", "invest", "final_goal", "rebate", "salary", "promotion"]:
		if opp_kw in eid:
			return "opportunity"
	return "event_pop"

func _get_event_resolved_sfx() -> String:
	if EventManager.event_history.is_empty():
		return "click"
	var last_rec: Dictionary = EventManager.event_history.back()
	var cost_val: int = int(last_rec.get("cost", 0))
	var cc_val: int = int(last_rec.get("credit_cost", 0))
	var stat_sum: int = int(last_rec.get("happy_change", 0)) + int(last_rec.get("social_change", 0)) + int(last_rec.get("credit_score_change", 0))
	if cost_val < 0:
		return "coin"
	if cost_val > 0 or cc_val > 0:
		return "spend"
	if stat_sum > 0:
		return "stat_up"
	if stat_sum < 0:
		return "stat_down"
	return "click"

func _start_initial_day() -> void:
	StatManager.initial_day_started = true
	if not StatManager.has_selected_goal:
		trigger_goal_selection()
	receive_salary()

func _update_next_button_visibility() -> void:
	var can_advance := (not EventManager.is_direct_event_active) and (not is_modal_open) and (not is_game_over)
	if next_phase_button:
		next_phase_button.visible = can_advance
		next_phase_button.text = "Susunod"
		UITheme.set_button_icon(next_phase_button, UITheme.ICON_ARROW_RIGHT, true)
	if auto_advance_button:
		auto_advance_button.visible = can_advance
		if is_auto_advancing:
			auto_advance_button.text = "Pause"
			UITheme.set_button_icon(auto_advance_button, UITheme.ICON_PAUSE, false)
			auto_advance_button.modulate = Color(1.0, 0.92, 0.55, 1.0)
		else:
			auto_advance_button.text = "Auto-Play"
			UITheme.set_button_icon(auto_advance_button, UITheme.ICON_FAST_FORWARD, true)
			auto_advance_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func enqueue_modal(task: Callable) -> void:
	stop_auto_advance()
	modal_queue.append(task)
	if not is_modal_open:
		_run_next_modal()

func _run_next_modal() -> void:
	if modal_queue.is_empty():
		is_modal_open = false
		_update_next_button_visibility()
		if not is_game_over:
			EventManager.evaluate_daily_events()
			if pending_desk_tool_to_open != "" and not EventManager.is_direct_event_active:
				var tool_to_open = pending_desk_tool_to_open
				pending_desk_tool_to_open = ""
				_open_desk_tool_by_name(tool_to_open)
		return
		
	is_modal_open = true
	_update_next_button_visibility()
	var next_task: Callable = modal_queue.pop_front()
	next_task.call()

func _make_hud_btn_style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	return UITheme.make_tactile_btn_style(bg, border, radius, 4, 10.0, 5.0)

func _style_hud_button(btn: Button, bg: Color, _border: Color = UITheme.INK_BORDER) -> void:
	UITheme.style_Button(btn, bg, 8, 4, 10.0, 5.0)

func _apply_hud_visual_theme() -> void:
	UITheme.style_Button(next_phase_button, UITheme.BTN_SAGE, 8, 5, 12.0, 6.0)
	UITheme.apply_type(next_phase_button, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.set_button_icon(next_phase_button, UITheme.ICON_ARROW_RIGHT, true)
	UITheme.style_Button(auto_advance_button, UITheme.BTN_GOLD, 8, 5, 12.0, 6.0)
	UITheme.apply_type(auto_advance_button, UITheme.TYPE_BODY, UITheme.FONT_UI)
	UITheme.set_button_icon(auto_advance_button, UITheme.ICON_FAST_FORWARD, true)
	UITheme.style_Button(goal_button, UITheme.BTN_GOLD, 7, 4, 8.0, 4.0)
	UITheme.style_Button(savings_jar_button, UITheme.BTN_GOLD, 7, 4, 10.0, 4.0)
	var qb_btn: Button = get_node_or_null("EnvelopeRunwayPanel/HBoxContainer/QuickBudgetButton")
	UITheme.style_Button(qb_btn, UITheme.BTN_GOLD, 6, 3, 8.0, 3.0)
	UITheme.apply_type(qb_btn, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	UITheme.style_Button(baldo_smart_btn, UITheme.BTN_SAGE, 7, 3, 8.0, 3.0)
	UITheme.apply_type(baldo_smart_btn, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	UITheme.style_Button(ask_baldo_btn, UITheme.PAPER_CREAM, 7, 3, 8.0, 3.0)
	UITheme.apply_type(ask_baldo_btn, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	
	if date_label:
		var hdr_sb := StyleBoxFlat.new()
		hdr_sb.bg_color = UITheme.BTN_GOLD
		hdr_sb.border_width_left = 3
		hdr_sb.border_width_top = 3
		hdr_sb.border_width_right = 3
		hdr_sb.border_width_bottom = 3
		hdr_sb.border_color = UITheme.INK_BORDER
		hdr_sb.corner_radius_top_left = 10
		hdr_sb.corner_radius_top_right = 10
		hdr_sb.content_margin_left = 12.0
		hdr_sb.content_margin_right = 12.0
		date_label.add_theme_stylebox_override("normal", hdr_sb)
		UITheme.apply_type(date_label, UITheme.TYPE_SUBHEAD, UITheme.FONT_UI)
		date_label.add_theme_color_override("font_color", UITheme.INK_DARK)
	
	var baldo_panel: Panel = get_node_or_null("BaldoToastPanel")
	if baldo_panel:
		var bp_sb := UITheme.make_card_style(UITheme.PAPER_STICKY, UITheme.INK_BORDER, 10, 3, 5, 10.0, 8.0)
		bp_sb.border_width_top = 5
		baldo_panel.add_theme_stylebox_override("panel", bp_sb)
	if baldo_toast_label:
		baldo_toast_label.add_theme_font_override("normal_font", UITheme.FONT_BODY)
		baldo_toast_label.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
		baldo_toast_label.add_theme_font_size_override("normal_font_size", 13)
		baldo_toast_label.add_theme_font_size_override("bold_font_size", 13)
	if envelope_runway_label:
		envelope_runway_label.add_theme_font_override("normal_font", UITheme.FONT_BODY)
		envelope_runway_label.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
		envelope_runway_label.add_theme_font_size_override("normal_font_size", UITheme.TYPE_CAPTION)
		envelope_runway_label.add_theme_font_size_override("bold_font_size", UITheme.TYPE_CAPTION)
	var routine_panel: Panel = get_node_or_null("DailyRoutinePanel")
	if routine_panel:
		routine_panel.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 10, 3, 5, 12.0, 8.0))
	var routine_title: Label = get_node_or_null("DailyRoutinePanel/VBoxContainer/Title")
	if routine_title:
		UITheme.style_header_banner(routine_title, UITheme.BTN_GOLD, 6, 3.0, UITheme.TYPE_SUBHEAD)
		
	UITheme.style_stat_badge(current_balance, UITheme.BTN_SAGE)
	UITheme.style_stat_badge(savings, UITheme.BTN_BLUE)
	UITheme.style_stat_badge(credit_balance, UITheme.BTN_GOLD)
	UITheme.style_stat_badge(debt_balance, UITheme.BTN_CORAL)
	UITheme.style_stat_badge(credit_score, UITheme.BTN_GOLD)
	
	UITheme.style_option_button(food_option)
	UITheme.style_option_button(commute_option)
	UITheme.style_progress_bar(happy_bar, UITheme.BTN_SAGE, 9)
	UITheme.style_progress_bar(social_bar, UITheme.BTN_GOLD, 9)
	_ensure_bar_overlay_label(happy_bar, "BarTextLabel")
	_ensure_bar_overlay_label(social_bar, "BarTextLabel")

func _ensure_bar_overlay_label(bar: ProgressBar, lbl_name: String) -> void:
	if not bar:
		return
	bar.show_percentage = false
	var lbl := bar.get_node_or_null(lbl_name) as Label
	if not lbl:
		lbl = Label.new()
		lbl.name = lbl_name
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", UITheme.FONT_UI)
		lbl.add_theme_font_size_override("font_size", UITheme.TYPE_CAPTION)
		lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
		lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.94, 0.92))
		lbl.add_theme_constant_override("outline_size", 3)
		bar.add_child(lbl)

func _setup_shortcut_tooltips() -> void:
	if next_phase_button:
		next_phase_button.tooltip_text = "Susunod na Bahagi ng Araw  [Space]"
	if auto_advance_button:
		auto_advance_button.tooltip_text = "Auto-Play  [F]"
	if _menu_button:
		_menu_button.tooltip_text = "Menu at Settings  [Esc]"
	if goal_icon:
		goal_icon.tooltip_text = "Ipon at Life Goal Tracker"
	var parent_desk = get_parent()
	if parent_desk:
		var s_btn = parent_desk.get_node_or_null("Status Button")
		if s_btn:
			s_btn.tooltip_text = "Status, Ledger at Badges  [1]"
		var p_btn = parent_desk.get_node_or_null("Planner Button")
		if p_btn:
			p_btn.tooltip_text = "Kalendaryo at Tala  [2]"
		var b_btn = parent_desk.get_node_or_null("Budget Button")
		if b_btn:
			b_btn.tooltip_text = "Cash Envelopes  [3]"
		var ph_btn = parent_desk.get_node_or_null("Phone Button")
		if ph_btn:
			ph_btn.tooltip_text = "PaldoPhone at Baldo Coach  [4]"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if handle_shortcut_key(event.keycode):
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()

func handle_shortcut_key(keycode: Key) -> bool:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return false
	var vp := get_viewport()
	if vp:
		var focus_owner := vp.gui_get_focus_owner()
		if (focus_owner is LineEdit or focus_owner is TextEdit) and keycode != KEY_ESCAPE:
			return false
	var parent_desk = get_parent()
	var back_btn = parent_desk.get_node_or_null("Back Button") if parent_desk else null
	var sub_open: bool = (back_btn != null and back_btn.visible)
	
	match keycode:
		KEY_ESCAPE:
			if is_instance_valid(_pause_modal):
				_pause_modal.visible = false
				_pause_modal.queue_free()
				_pause_modal = null
				return true
			if sub_open and back_btn.has_method("_on_pressed"):
				back_btn._on_pressed()
				return true
			if is_auto_advancing:
				stop_auto_advance()
				return true
			open_pause_menu()
			return true
		KEY_SPACE:
			if not sub_open:
				advance_day()
				return true
			return false
		KEY_F:
			if not sub_open:
				toggle_auto_advance()
				return true
			return false
		KEY_1:
			_open_desk_tool_by_name("status")
			return true
		KEY_2:
			_open_desk_tool_by_name("planner")
			return true
		KEY_3:
			_open_desk_tool_by_name("budget")
			return true
		KEY_4:
			_open_desk_tool_by_name("phone")
			return true
		_:
			return false

func _open_desk_tool_by_name(tool_name: String) -> void:
	stop_auto_advance()
	var parent_desk = get_parent()
	if not parent_desk:
		return
	var back_btn = parent_desk.get_node_or_null("Back Button")
	if back_btn and back_btn.visible and back_btn.has_method("_on_pressed"):
		back_btn._on_pressed()
	if tool_name == "status":
		var s_btn = parent_desk.get_node_or_null("Status Button")
		if s_btn and s_btn.has_method("_button_pressed"):
			s_btn._button_pressed()
	elif tool_name == "budget":
		var b_btn = parent_desk.get_node_or_null("Budget Button")
		if b_btn and b_btn.has_method("_button_pressed"):
			b_btn._button_pressed()
	elif tool_name == "planner":
		var p_btn = parent_desk.get_node_or_null("Planner Button")
		if p_btn and p_btn.has_method("_button_pressed"):
			p_btn._button_pressed()
	elif tool_name in ["phone", "baldo_chat", "phone_loans", "phone_inbox"]:
		var ph_btn = parent_desk.get_node_or_null("Phone Button")
		if ph_btn and ph_btn.has_method("_button_pressed"):
			ph_btn._button_pressed()
		var ph_ui = parent_desk.get_node_or_null("Phone Node/Phone Interface")
		if ph_ui:
			if tool_name == "baldo_chat" and ph_ui.has_method("open_baldo_chat_direct"):
				ph_ui.open_baldo_chat_direct()
			elif tool_name == "phone_loans" and ph_ui.has_method("open_loans_direct"):
				ph_ui.open_loans_direct()
			elif tool_name == "phone_inbox" and ph_ui.has_method("open_first_unread_direct"):
				ph_ui.open_first_unread_direct()

func _on_quick_budget_pressed() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return
	_open_desk_tool_by_name("budget")

func _on_ask_baldo_pressed() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return
	_open_desk_tool_by_name("baldo_chat")

func get_baldo_smart_action() -> Dictionary:
	var food_env := StatManager.get_envelope_amount("Food")
	var trans_env := StatManager.get_envelope_amount("Transportation")
	var rent_env := StatManager.get_envelope_amount("Rent")
	var total_debt := StatManager.get_total_debt_and_loans()
	if auto_pause_override_reason != "":
		return {"label": "Mag-Budget", "action": "budget", "color": UITheme.BTN_GOLD, "mood": SAD}
	if EventManager.active_events.size() > 0:
		return {"label": "Basahin Text (" + str(EventManager.active_events.size()) + ")", "action": "phone_inbox", "color": UITheme.BTN_CORAL, "mood": NEUTRAL}
	if StatManager.happy < 40 or StatManager.social < 40:
		return {"label": "Comfort Mode", "action": "comfort_mode", "color": UITheme.BTN_GOLD, "mood": SAD}
	if total_debt > 0 and StatManager.current_balance >= 1000:
		return {"label": "Bayaran Utang", "action": "phone_loans", "color": UITheme.BTN_CORAL, "mood": NEUTRAL}
	var needs_trans := (StatManager.employment_status != "laid_off" and trans_env == 0)
	if ((StatManager.current_day == 1 or StatManager.current_day == 15) and (rent_env < StatManager.monthly_rent or food_env < StatManager.get_daily_food_cost() * 5) and StatManager.current_balance >= 2000) or ((food_env == 0 or needs_trans) and StatManager.current_balance >= 1000):
		return {"label": "Smart Split Sahod", "action": "smart_split", "color": UITheme.BTN_SAGE, "mood": HAPPY}
	if StatManager.current_balance >= 3500 and StatManager.savings < StatManager.get_goal_target():
		return {"label": "Hulog ₱1,000 Ipon", "action": "quick_save_1000", "color": UITheme.BTN_BLUE, "mood": JOYFUL}
	return {"label": "Check Mission", "action": "status", "color": UITheme.BTN_GOLD, "mood": HAPPY}

func _on_baldo_smart_action_pressed() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return
	var act := get_baldo_smart_action()
	var code := str(act.get("action", "status"))
	match code:
		"smart_split":
			var res: Dictionary = StatManager.auto_budget_paycheck()
			var alloc: int = int(res.get("total_allocated", 0))
			if alloc > 0:
				AudioManager.play_sfx("cash_register")
				StatManager.set_baldo_lesson("Smart Split", "Na-allocate na ang ₱" + UITheme.format_num(alloc) + " across Bills, Food, Byahe, at Ipon!")
			else:
				AudioManager.play_sfx("click")
				_open_desk_tool_by_name("budget")
			update_ui()
		"quick_save_1000":
			if StatManager.deposit_savings(1000):
				AudioManager.play_sfx("coin")
				StatManager.set_baldo_lesson("Pay Yourself First", "Nakahulog ka ng ₱1,000 sa Ipon (0.5%/buwan Digital Bank compounding)!")
				update_ui()
		"comfort_mode":
			StatManager.daily_food_choice = 1
			StatManager.daily_commute_choice = 1
			StatManager.set_baldo_lesson("Self-Care", "Naka-comfort routine ka muna (Mag-order + Mototaxi) para mabawi ang Happy at iwas Burnout.")
			AudioManager.play_sfx("click")
			update_ui()
		"budget", "status", "phone_loans", "phone_inbox":
			AudioManager.play_sfx("click")
			_open_desk_tool_by_name(code)
		_:
			AudioManager.play_sfx("click")
			_open_desk_tool_by_name("status")

func spawn_dialog(dialog: AcceptDialog, open_sfx: String = "") -> void:
	var title_str: String = dialog.title if dialog.title != "" else "Paalala"
	var body_str: String = dialog.dialog_text
	dialog.queue_free()
	var banner_col: Color = UITheme.BTN_SAGE if ("Sahod" in title_str or "Auto-Paid" in title_str) else UITheme.BTN_GOLD
	enqueue_modal(func():
		UITheme.spawn_game_notice(self, title_str, body_str, banner_col, "OK, Tuloy!", func():
			_run_next_modal()
		, open_sfx)
	)

func trigger_goal_selection() -> void:
	enqueue_modal(func():
		var goal_scene = preload("res://scenes/goal_selection.tscn")
		var goal_instance = goal_scene.instantiate()
		add_child(goal_instance)
		goal_instance.show_goal_selection()
		goal_instance.goal_modal_closed.connect(func():
			goal_instance.visible = false
			goal_instance.queue_free()
			update_ui()
			_run_next_modal()
		)
	)

func _on_goal_icon_pressed() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return
	AudioManager.play_sfx("tool_open")
	enqueue_modal(func():
		var goal_scene = preload("res://scenes/goal_selection.tscn")
		var goal_instance = goal_scene.instantiate()
		add_child(goal_instance)
		goal_instance.show_savings_and_goal_inspector()
		goal_instance.goal_modal_closed.connect(func():
			goal_instance.visible = false
			goal_instance.queue_free()
			update_ui()
			_run_next_modal()
		)
	)
	pass # Replace with function body.

func update_ui() -> void:
	if happy_bar:
		happy_bar.value = StatManager.happy
		if happy_icon:
			if StatManager.happy >= 90:
				happy_icon.texture = JOYFUL
			elif StatManager.happy > 60:
				happy_icon.texture = HAPPY
			elif StatManager.happy > 40:
				happy_icon.texture = NEUTRAL
			elif StatManager.happy > 10:
				happy_icon.texture = SAD
			else:
				happy_icon.texture = DESPAIRED
			
		var h_lbl := happy_bar.get_node_or_null("BarTextLabel") as Label
		if h_lbl:
			h_lbl.text = "Happiness: " + str(StatManager.happy) + " / 100"
	if social_bar:
		social_bar.value = StatManager.social
		var s_lbl := social_bar.get_node_or_null("BarTextLabel") as Label
		if s_lbl:
			s_lbl.text = "Social: " + str(StatManager.social) + " / 100"
	if current_balance:
		current_balance.text = "Hawak na Cash\n₱" + UITheme.format_num(StatManager.current_balance)
	if savings:
		savings.text = "Ipon sa Bangko\n₱" + UITheme.format_num(StatManager.savings)
	if credit_balance:
		credit_balance.text = "Credit Balance\n₱" + UITheme.format_num(StatManager.credit_balance)
	if credit_score:
		credit_score.text = "Credit Score\n" + str(StatManager.credit_score) + " / 100"
	if debt_balance:
		debt_balance.text = "Utang / Loans\n₱" + UITheme.format_num(StatManager.get_total_debt_and_loans())
	
	var phase_names := ["Morning", "Afternoon", "Evening"]
	if date_label:
		var wk_full: String = StatManager.get_weekday_name(StatManager.current_month, StatManager.current_day, false)
		var m_name: String = str(StatManager.year[StatManager.current_month].month)
		date_label.text = wk_full + ", " + m_name + " " + str(StatManager.current_day) + "  •  " + phase_names[StatManager.current_phase]
	
	if goal_icon:
		var goal = StatManager.get_current_goal()
		if goal and goal.has("icon"):
			goal_icon.texture_normal = goal["icon"]
		
	if goal_button:
		var g = StatManager.get_current_goal()
		var pct = StatManager.get_goal_progress_percent()
		goal_button.text = "₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(int(g["cost"])) + " — " + str(pct) + "%"
		goal_button.tooltip_text = "Goal: " + str(g["title"]) + " • ₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(int(g["cost"])) + " — " + str(pct) + "%"
		
	if savings_jar_button:
		savings_jar_button.text = "Ipon: ₱" + UITheme.format_num(StatManager.savings) + " • 6%/yr"
		
	if food_option:
		var cook_cost = max(0, StatManager.food_costs[0] + StatManager.daily_food_modifier)
		var eatout_cost = max(0, StatManager.food_costs[1] + StatManager.daily_food_modifier)
		food_option.set_item_text(0, "Magluto (₱" + UITheme.format_num(cook_cost) + ")")
		food_option.set_item_text(1, "Mag-order (₱" + UITheme.format_num(eatout_cost) + ")")
		if food_option.selected != StatManager.daily_food_choice:
			food_option.selected = StatManager.daily_food_choice
			
	if commute_option:
		if StatManager.employment_status == "laid_off":
			commute_option.set_item_text(0, "Walang Pasok (₱0)")
			commute_option.set_item_text(1, "Walang Pasok (₱0)")
			commute_option.disabled = true
			commute_option.tooltip_text = "Walang pasok ngayon kaya ₱0 ang araw-araw na byahe."
		else:
			commute_option.disabled = false
			commute_option.tooltip_text = "Piliin ang pang-araw-araw na byahe sa trabaho."
			var pub_cost = max(0, StatManager.commute_costs[0] + StatManager.daily_commute_modifier)
			var moto_cost = max(0, StatManager.commute_costs[1] + StatManager.daily_commute_modifier)
			commute_option.set_item_text(0, "Public Transit (₱" + UITheme.format_num(pub_cost) + ")")
			commute_option.set_item_text(1, "Mototaxi (₱" + UITheme.format_num(moto_cost) + ")")
			if commute_option.selected != StatManager.daily_commute_choice:
				commute_option.selected = StatManager.daily_commute_choice
			
	_update_desk_lighting()
	_check_and_spawn_floating_deltas()
	_update_envelope_runway_ui()
	_update_baldo_toast_ui()
	_update_desk_badges()
	_update_next_button_visibility()
	_update_status_report()

func _update_desk_lighting() -> void:
	if StatManager.current_phase == _last_tinted_phase:
		return
	_last_tinted_phase = StatManager.current_phase
	var parent_desk = get_parent()
	if not parent_desk:
		return
	var desk_bg: CanvasItem = parent_desk.get_node_or_null("Desk Background")
	if not desk_bg:
		return
	var target_tint := Color(1.0, 0.99, 0.96, 1.0)
	if StatManager.current_phase == 1:
		target_tint = Color(1.0, 0.92, 0.78, 1.0)
	elif StatManager.current_phase >= 2:
		target_tint = Color(0.76, 0.78, 0.93, 1.0)
	if is_inside_tree():
		var bg_tw := create_tween()
		bg_tw.tween_property(desk_bg, "modulate", target_tint, 0.35)
	else:
		desk_bg.modulate = target_tint

func _update_desk_badges() -> void:
	if _phone_badge:
		var unread: int = EventManager.active_events.size()
		_phone_badge.visible = (unread > 0)
		if unread > 0:
			_phone_badge.text = str(unread) + " Bagong Text"
	if _goal_progress_bar and _goal_progress_lbl:
		var g: Dictionary = StatManager.get_current_goal()
		var target: int = max(1, int(g.get("cost", 40000)))
		var pct: int = StatManager.get_goal_progress_percent()
		_goal_progress_bar.max_value = float(target)
		_goal_progress_bar.value = float(clamp(StatManager.savings, 0, target))
		var streak: int = StatManager.envelope_discipline_streak
		var detail := ("  •  Streak " + str(streak) + "w") if streak > 0 else ("  •  ₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(target))
		_goal_progress_lbl.text = "Goal: " + str(pct) + "%" + detail

func _check_and_spawn_floating_deltas() -> void:
	var cur_debt_total := StatManager.get_total_debt_and_loans()
	if not _stats_baseline_initialized:
		_prev_balance = StatManager.current_balance
		_prev_savings = StatManager.savings
		_prev_credit_balance = StatManager.credit_balance
		_prev_credit_score = StatManager.credit_score
		_prev_debt = cur_debt_total
		_prev_happy = StatManager.happy
		_prev_social = StatManager.social
		_stats_baseline_initialized = true
		return
		
	if StatManager.current_balance != _prev_balance:
		var diff := StatManager.current_balance - _prev_balance
		_prev_balance = StatManager.current_balance
		spawn_floating_delta(current_balance, ("+₱" if diff > 0 else "-₱") + UITheme.format_num(abs(diff)), Color(0.25, 1.0, 0.35) if diff > 0 else Color(1.0, 0.35, 0.35))
		
	if StatManager.savings != _prev_savings:
		var diff := StatManager.savings - _prev_savings
		_prev_savings = StatManager.savings
		spawn_floating_delta(savings, ("+₱" if diff > 0 else "-₱") + UITheme.format_num(abs(diff)) + " Ipon", Color(0.3, 0.9, 1.0) if diff > 0 else Color(1.0, 0.75, 0.3))
		
	if StatManager.credit_balance != _prev_credit_balance:
		var diff := StatManager.credit_balance - _prev_credit_balance
		_prev_credit_balance = StatManager.credit_balance
		spawn_floating_delta(credit_balance, ("+₱" if diff > 0 else "-₱") + UITheme.format_num(abs(diff)) + " Credit", Color(1.0, 0.65, 0.25) if diff > 0 else Color(0.3, 1.0, 0.5))
		
	if StatManager.credit_score != _prev_credit_score:
		var diff := StatManager.credit_score - _prev_credit_score
		_prev_credit_score = StatManager.credit_score
		spawn_floating_delta(credit_score, ("+" if diff > 0 else "") + str(diff) + " CS", Color(0.3, 1.0, 0.4) if diff > 0 else Color(1.0, 0.3, 0.3))
		
	if cur_debt_total != _prev_debt:
		var diff := cur_debt_total - _prev_debt
		_prev_debt = cur_debt_total
		spawn_floating_delta(debt_balance, ("+₱" if diff > 0 else "-₱") + UITheme.format_num(abs(diff)) + " Debt", Color(1.0, 0.25, 0.25) if diff > 0 else Color(0.3, 1.0, 0.4))
		
	if StatManager.happy != _prev_happy:
		var diff := StatManager.happy - _prev_happy
		_prev_happy = StatManager.happy
		spawn_floating_delta(happy_bar, ("+" if diff > 0 else "") + str(diff) + " Happy", Color(0.3, 1.0, 0.4) if diff > 0 else Color(1.0, 0.4, 0.4))
		
	if StatManager.social != _prev_social:
		var diff := StatManager.social - _prev_social
		_prev_social = StatManager.social
		spawn_floating_delta(social_bar, ("+" if diff > 0 else "") + str(diff) + " Social", Color(0.3, 0.9, 1.0) if diff > 0 else Color(1.0, 0.45, 0.35))

func _pulse_control(ctrl: Control) -> void:
	if not ctrl or not is_inside_tree():
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var ptw := create_tween()
	ptw.tween_property(ctrl, "scale", Vector2(1.05, 1.05), 0.1)
	ptw.tween_property(ctrl, "scale", Vector2(1.0, 1.0), 0.14)

func spawn_floating_delta(target_node: Control, text_str: String, color: Color) -> void:
	recent_floating_popups_count += 1
	last_floating_popup_text = text_str
	if not target_node or not is_inside_tree():
		return
	_pulse_control(target_node)
	var lbl := Label.new()
	lbl.text = text_str
	lbl.z_index = 25
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", UITheme.FONT_BOLD)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 16)
	var base_pos := target_node.global_position + Vector2(20, -6)
	lbl.global_position = base_pos
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", base_pos + Vector2(0, -26), 0.75)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75)
	tw.chain().tween_callback(lbl.queue_free)

func _enqueue_banner_toast(banner_title: String, banner_sub: String, banner_color: Color, sfx_name: String = "toast_slide") -> void:
	_ach_toast_queue.append({
		"banner_title": banner_title,
		"banner_sub": banner_sub,
		"banner_color": banner_color,
		"sfx_name": sfx_name
	})
	if not _is_showing_ach_toast:
		_show_next_achievement_toast()

func _on_achievement_unlocked(achievement: Dictionary) -> void:
	_enqueue_banner_toast(
		"ACHIEVEMENT UNLOCKED: " + str(achievement.get("title", "")),
		str(achievement.get("subtitle", "")) + " — Check STATUS Laptop Ledger",
		UITheme.BTN_GOLD,
		"achievement"
	)

func _on_mission_completed(mission: Dictionary) -> void:
	var r_cash := int(mission.get("reward_cash", 0))
	var r_cs := int(mission.get("reward_cs", 0))
	var r_happy := int(mission.get("reward_happy", 0))
	_enqueue_banner_toast(
		"MONTHLY MISSION COMPLETE: " + str(mission.get("title", "")),
		"Bonus: +₱" + UITheme.format_num(r_cash) + " Cash • +" + str(r_cs) + " Credit • +" + str(r_happy) + " Happy!",
		UITheme.BTN_SAGE,
		"milestone"
	)

func _on_goal_milestone_reached(pct: int, happy_bonus: int) -> void:
	_enqueue_banner_toast(
		"LIFE GOAL " + str(pct) + "% REACHED!",
		"Milestone unlocked! +" + str(happy_bonus) + " Happy bonus sa progreso ng ipon mo.",
		UITheme.BTN_BLUE,
		"milestone"
	)

func _show_next_achievement_toast() -> void:
	if _ach_toast_queue.is_empty() or not is_inside_tree():
		_is_showing_ach_toast = false
		return
	_is_showing_ach_toast = true
	var ach: Dictionary = _ach_toast_queue.pop_front()
	var sfx_id: String = str(ach.get("sfx_name", "toast_slide"))
	if sfx_id != "":
		AudioManager.play_sfx(sfx_id)
	
	if not _ach_toast_layer:
		_ach_toast_layer = CanvasLayer.new()
		_ach_toast_layer.name = "AchievementToastLayer"
		_ach_toast_layer.layer = 130
		add_child(_ach_toast_layer)
		
	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -230.0
	banner.offset_right = 230.0
	banner.offset_top = -64.0
	banner.offset_bottom = -8.0
	banner.modulate.a = 0.0
	var b_col: Color = ach.get("banner_color", UITheme.BTN_GOLD)
	banner.add_theme_stylebox_override("panel", UITheme.make_card_style(b_col, UITheme.INK_BORDER, 10, 3, 5, 14.0, 8.0))
	
	var rtf := RichTextLabel.new()
	rtf.bbcode_enabled = true
	rtf.fit_content = true
	rtf.scroll_active = false
	rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtf.add_theme_font_override("normal_font", UITheme.FONT_BODY)
	rtf.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
	rtf.add_theme_color_override("default_color", UITheme.INK_DARK)
	rtf.add_theme_font_size_override("normal_font_size", 12)
	rtf.add_theme_font_size_override("bold_font_size", 13)
	var t_line: String = str(ach.get("banner_title", ach.get("title", "")))
	var s_line: String = str(ach.get("banner_sub", ach.get("subtitle", "")))
	rtf.text = "[center][b]" + t_line + "[/b]\n[color=#3b2f24]" + s_line + "[/color][/center]"
	banner.add_child(rtf)
	_ach_toast_layer.add_child(banner)
	
	var tw := create_tween()
	tw.tween_property(banner, "offset_top", 12.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(banner, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.4)
	tw.tween_property(banner, "offset_top", -24.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(banner, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(banner):
			banner.queue_free()
		_show_next_achievement_toast()
	)

func _update_envelope_runway_ui() -> void:
	if not envelope_runway_label:
		return
	var daily_food: int = max(1, StatManager.get_daily_food_cost())
	var food_env: int = StatManager.get_envelope_amount("Food")
	var food_days: int = int(food_env / daily_food)
	var food_col := "#1c7033" if food_days >= 5 else ("#94520d" if food_env > 0 else "#a8261f")
	
	var trans_str := ""
	if StatManager.employment_status == "laid_off":
		trans_str = "[b]Byahe:[/b] [color=#1a4b7c][b]Walang Pasok[/b][/color]"
	else:
		var daily_trans: int = max(1, StatManager.get_daily_commute_cost())
		var trans_env: int = StatManager.get_envelope_amount("Transportation")
		var trans_days: int = int(trans_env / daily_trans)
		var trans_col := "#1c7033" if trans_days >= 5 else ("#94520d" if trans_env > 0 else "#a8261f")
		trans_str = "[b]Byahe:[/b] [color=" + trans_col + "][b]" + str(trans_days) + " araw[/b][/color]"
	
	var rent_env: int = StatManager.get_envelope_amount("Rent")
	var total_util: int = StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
	var util_env: int = StatManager.get_envelope_amount("Utilities")
	var bills_ok: bool = (rent_env >= StatManager.monthly_rent and util_env >= total_util)
	var bills_col := "#1c7033" if bills_ok else "#94520d"
	var bills_tag := "Handa" if bills_ok else "Kulang"
	
	envelope_runway_label.text = (
		"[b]Pagkain:[/b] [color=" + food_col + "][b]" + str(food_days) + " araw[/b][/color]  |  " +
		trans_str + "  |  " +
		"[b]Bills:[/b] [color=" + bills_col + "][b]" + bills_tag + "[/b][/color]"
	)

func get_live_baldo_desk_tip() -> String:
	if auto_pause_override_reason != "":
		return "[b][color=#94520d]Baldo:[/color][/b] " + auto_pause_override_reason
		
	if EventManager.active_events.size() > 0:
		var ev_title := str(EventManager.active_events[0].get("title", "New Message"))
		return "[b][color=#a8261f]Baldo:[/color][/b] May unread text sa Phone — [i]\"" + ev_title + "\"[/i]. Sagutin bago matapos ang araw."
		
	if StatManager.happy < 40 or StatManager.social < 40:
		return "[b][color=#a8261f]Baldo:[/color][/b] Mababa ang well-being mo ngayon (Happy " + str(StatManager.happy) + ", Social " + str(StatManager.social) + "). Mag-Comfort Mode para iwas Burnout."
		
	if StatManager.last_baldo_lesson != "":
		var topic := StatManager.last_baldo_lesson_topic if StatManager.last_baldo_lesson_topic != "" else "Tip"
		return "[b][color=#1a4b7c]Baldo — " + topic + ":[/color][/b] " + StatManager.last_baldo_lesson
		
	var food_env := StatManager.get_envelope_amount("Food")
	var trans_env := StatManager.get_envelope_amount("Transportation")
	var rent_env := StatManager.get_envelope_amount("Rent")
	var util_env := StatManager.get_envelope_amount("Utilities")
	var total_util := StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
	
	if StatManager.employment_status == "laid_off":
		return "[b][color=#94520d]Baldo:[/color][/b] Walang work commute habang laid off. Tipirin ang Pagkain at Emergency Fund habang naghahanap ng bagong trabaho."
		
	if (StatManager.current_day == 1 or StatManager.current_day == 15) and (rent_env < StatManager.monthly_rent or food_env < StatManager.get_daily_food_cost() * 5):
		return "[b][color=#1c7033]Baldo:[/color][/b] Sahod Day! I-click ang [b]'Smart Split Sahod'[/b] para automatic naka-set ang Bills at Pagkain."
		
	if food_env == 0 or (trans_env == 0 and StatManager.employment_status != "laid_off"):
		return "[b][color=#94520d]Baldo:[/color][/b] Ubos na ang Pagkain o Byahe envelope! Mag-allocate para di mabawasan ang Pocket Cash."
		
	if StatManager.current_day >= 23 and (rent_env < StatManager.monthly_rent or util_env < total_util):
		var short_amt: int = max(0, StatManager.monthly_rent - rent_env) + max(0, total_util - util_env)
		return "[b][color=#94520d]Baldo:[/color][/b] Malapit na Katapusan! Kulang pa ng ₱" + UITheme.format_num(short_amt) + " ang Upa at Bills para sa auto-pay."
		
	if StatManager.credit_balance > 0 and StatManager.current_day >= 20:
		return "[b][color=#94520d]Baldo:[/color][/b] May ₱" + UITheme.format_num(StatManager.credit_balance) + " Credit balance ka. Bayaran nang buo sa Day 25 para iwas 3% interest."
		
	var m_info: Dictionary = StatManager.get_active_monthly_mission()
	var m_name: String = str(StatManager.year[StatManager.current_month].month)
	if not bool(m_info.get("completed", false)):
		return "[b][color=#1c7033]" + m_name + " Mission — " + str(int(m_info.get("pct", 0))) + "%:[/color][/b] " + str(m_info.get("title", "")) + ". " + str(m_info.get("desc", ""))
	return "[b][color=#1c7033]Baldo:[/color][/b] Solid runway par! Pwede mag-[b]Auto-Play[/b] o maghulog ng extra sa Digital Bank Ipon (6%/yr)."

func _update_baldo_toast_ui() -> void:
	if baldo_toast_label:
		baldo_toast_label.text = get_live_baldo_desk_tip()
	var act := get_baldo_smart_action()
	if baldo_avatar and act.has("mood"):
		baldo_avatar.texture = act["mood"]
	if baldo_smart_btn:
		baldo_smart_btn.text = str(act.get("label", "Action"))
		UITheme.style_Button(baldo_smart_btn, act.get("color", UITheme.BTN_SAGE), 7, 3, 8.0, 3.0)

func _update_status_report() -> void:
	if not status_report_label:
		return
	var stage_info = StatManager.get_stage_info()
	var g = StatManager.get_current_goal()
	var target = StatManager.get_goal_target()
	var pct = StatManager.get_goal_progress_percent()
	var total_util = StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
	var rent_env = StatManager.get_envelope_amount("Rent")
	var util_env = StatManager.get_envelope_amount("Utilities")
	var cc_env = StatManager.get_envelope_amount("Credit Card")
	var food_env = StatManager.get_envelope_amount("Food")
	var trans_env = StatManager.get_envelope_amount("Transportation")
	var ent_env = StatManager.get_envelope_amount("Entertainment")
	var total_debt_and_loans = StatManager.get_total_debt_and_loans()
	
	var goal_ok = "[color=#1c7033][b]REACHED — ₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(target) + "[/b][/color]" if StatManager.savings >= target else "[color=#94520d][b]₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(target) + " (" + str(pct) + "%)[/b][/color]"
	var happy_ok = "[color=#1c7033][b]GOOD (" + str(StatManager.happy) + "/100)[/b][/color]" if StatManager.happy >= 50 else "[color=#a8261f][b]LOW (" + str(StatManager.happy) + "/100 — Need 50+)[/b][/color]"
	var social_ok = "[color=#1c7033][b]GOOD (" + str(StatManager.social) + "/100)[/b][/color]" if StatManager.social >= 50 else "[color=#a8261f][b]LOW (" + str(StatManager.social) + "/100 — Need 50+)[/b][/color]"
	var credit_ok = "[color=#1c7033][b]GOOD (" + str(StatManager.credit_score) + "/100)[/b][/color]" if StatManager.credit_score >= 70 else "[color=#a8261f][b]POOR (" + str(StatManager.credit_score) + "/100 — Need 70+)[/b][/color]"
	var debt_ok = "[color=#1c7033][b]DEBT-FREE (₱0)[/b][/color]" if total_debt_and_loans == 0 and StatManager.credit_balance == 0 else "[color=#a8261f][b]MAY UTANG — Debt: ₱" + UITheme.format_num(total_debt_and_loans) + ", Credit: ₱" + UITheme.format_num(StatManager.credit_balance) + "[/b][/color]"
	
	var txt = "[b][font_size=22]" + stage_info["name"] + "[/font_size][/b]\n"
	txt += "[i][color=#5c4f45]\"" + stage_info["theme"] + "\"[/color][/i]\n\n"
	txt += "[b]1. Year-End Victory Conditions Status:[/b]\n"
	txt += "- Employment Status: [color=#94520d][b]" + StatManager.get_employment_display_text() + "[/b][/color]\n"
	txt += "- Life Goal (" + str(g["title"]) + "): " + goal_ok + "\n"
	txt += "- Well-Being (Happiness): " + happy_ok + "\n"
	txt += "- Relationships (Sociability): " + social_ok + "\n"
	txt += "- Credit Standing: " + credit_ok + "\n"
	txt += "- Debt, Loans & Credit Status: " + debt_ok + "\n"
	txt += "- Savings Interest Earned: [color=#1c7033][b]₱" + UITheme.format_num(StatManager.total_savings_interest_earned) + "[/b][/color] | Investments: [color=#1a4b7c][b]₱" + UITheme.format_num(StatManager.get_total_investments()) + "[/b][/color] (P&L: ₱" + UITheme.format_num(StatManager.total_investment_gains) + ")\n\n"
	txt += "[b]2. Monthly Bills, Loans, Installments & Envelopes:[/b]\n"
	txt += "- Upa (Rent): ₱" + UITheme.format_num(rent_env) + " / ₱" + UITheme.format_num(StatManager.monthly_rent) + "\n"
	txt += "- Utilities + Installments + Family Support: ₱" + UITheme.format_num(util_env) + " / ₱" + UITheme.format_num(total_util) + " • Installments: " + StatManager.get_installments_summary_text() + " • Family Padala: ₱" + UITheme.format_num(StatManager.monthly_family_support) + "/mo\n"
	txt += "- Credit Card Envelope: ₱" + UITheme.format_num(cc_env) + " • Balance: ₱" + UITheme.format_num(StatManager.credit_balance) + " / Limit: ₱" + UITheme.format_num(StatManager.credit_limit) + "\n"
	txt += "- Active Simple Interest Loans: " + StatManager.get_loans_summary_text() + "\n"
	txt += "- Pagkain: ₱" + UITheme.format_num(food_env) + " | Byahe: ₱" + UITheme.format_num(trans_env) + " | Libangan: ₱" + UITheme.format_num(ent_env) + "\n"
	status_report_label.text = txt

func happy_calc(amount: int) -> void:
	StatManager.modify_happy(amount)
	
func social_calc(amount: int) -> void:
	StatManager.modify_social(amount)
	
func current_balance_calc(amount: int) -> void:
	StatManager.spend_direct(-amount)
	
func savings_calc(amount: int) -> void:
	StatManager.savings = max(0, StatManager.savings + amount)
	StatManager.sync_savings_envelope()
	StatManager.on_stats_changed.emit()
	
func credit_balance_calc(amount: int) -> void:
	StatManager.credit_balance = max(0, StatManager.credit_balance + amount)
	StatManager.on_stats_changed.emit()
	
func credit_score_calc(amount: int) -> void:
	StatManager.modify_credit_score(amount)

func debt_calc(amount: int) -> void:
	StatManager.debt_balance = max(0, StatManager.debt_balance + amount)
	StatManager.on_stats_changed.emit()

func toggle_auto_advance() -> void:
	AudioManager.play_sfx("click")
	if is_auto_advancing:
		stop_auto_advance()
		return
	if EventManager.is_direct_event_active or is_modal_open or is_game_over:
		return
	if EventManager.active_events.size() > 0:
		_show_notification_warning()
		return
	auto_pause_override_reason = ""
	_auto_started_with_food_env = (StatManager.get_envelope_amount("Food") > 0)
	_auto_started_with_trans_env = (StatManager.employment_status != "laid_off" and StatManager.get_envelope_amount("Transportation") > 0)
	_auto_started_with_healthy_happy = (StatManager.happy >= 35)
	_auto_started_with_healthy_social = (StatManager.social >= 35)
	is_auto_advancing = true
	if auto_advance_timer:
		auto_advance_timer.wait_time = AudioManager.get_autoplay_wait_time()
		auto_advance_timer.start()
	_update_next_button_visibility()
	_on_auto_advance_tick()

func stop_auto_advance(reason: String = "") -> void:
	if reason != "":
		auto_pause_override_reason = reason
	if is_auto_advancing:
		is_auto_advancing = false
		if auto_advance_timer:
			auto_advance_timer.stop()
		_update_next_button_visibility()
		_update_baldo_toast_ui()
	elif reason != "":
		_update_baldo_toast_ui()

func _on_auto_advance_tick() -> void:
	if not is_auto_advancing:
		return
	if EventManager.is_direct_event_active or is_modal_open or is_game_over or EventManager.active_events.size() > 0:
		stop_auto_advance()
		return
	advance_day(true)
	# Smart Safety Auto-Pause Checks
	if _auto_started_with_food_env and StatManager.get_envelope_amount("Food") == 0:
		stop_auto_advance("Ubos na ang Pagkain Envelope mo! Mag-reload sa Mag-Budget para di mabawasan ang Pocket Cash.")
		return
	if StatManager.employment_status != "laid_off" and _auto_started_with_trans_env and StatManager.get_envelope_amount("Transportation") == 0:
		stop_auto_advance("Ubos na ang Byahe Envelope mo! Mag-reload sa Mag-Budget para di mabawasan ang Pocket Cash.")
		return
	if (_auto_started_with_healthy_happy and StatManager.happy < 35) or (_auto_started_with_healthy_social and StatManager.social < 35):
		stop_auto_advance("Bumaba na sa <35 ang Happiness o Social mo! Mag-order o mag-Mototaxi muna para iwas Burnout.")
		return

func advance_day(from_auto: bool = false) -> void:
	if not from_auto:
		auto_pause_override_reason = ""
	if EventManager.is_direct_event_active or is_modal_open or is_game_over:
		stop_auto_advance()
		return
		
	# If already in Evening (phase 2) with unread notifications and player explicitly clicks Finish Day, show warning dialog
	if StatManager.current_phase == 2 and EventManager.active_events.size() > 0:
		stop_auto_advance()
		_show_notification_warning()
		return
		
	# Step through remaining intra-day phases (Morning -> Afternoon -> Evening), stopping only if an event triggers
	while StatManager.current_phase < 2:
		var prev_indirect_count := EventManager.active_events.size()
		StatManager.current_phase += 1
		update_ui()
		EventManager.evaluate_daily_events()
		
		if EventManager.is_direct_event_active or is_modal_open or is_game_over:
			stop_auto_advance()
			update_ui()
			return
			
		if EventManager.active_events.size() > prev_indirect_count:
			stop_auto_advance()
			
	# At Evening (phase 2), if an Indirect Notification is pending on the Phone, pause cleanly at Evening and flash Phone
	if EventManager.active_events.size() > 0:
		stop_auto_advance()
		_flash_phone_button()
		update_ui()
		return
		
	# Complete the day rollover into tomorrow Morning (phase 0)
	AudioManager.play_sfx("day_tick")
	StatManager.current_phase = 0
	daily_cycle()
	update_ui()
	if not is_modal_open and not is_game_over:
		var prev_ind := EventManager.active_events.size()
		EventManager.evaluate_daily_events()
		if EventManager.is_direct_event_active or EventManager.active_events.size() > prev_ind:
			stop_auto_advance()
			if EventManager.active_events.size() > prev_ind:
				_flash_phone_button()
	else:
		stop_auto_advance()
	update_ui()

func advance_phase() -> void:
	if EventManager.is_direct_event_active or is_modal_open or is_game_over:
		print("Cannot advance phase while an event or modal is active!")
		return
		
	if StatManager.current_phase == 2: # Evening
		# Check if there are active indirect events
		if EventManager.active_events.size() > 0:
			print("Cannot end day. You have unread notifications!")
			_show_notification_warning()
			return
		
		# Move to next day
		StatManager.current_phase = 0
		daily_cycle()
		update_ui()
		if not is_modal_open and not is_game_over:
			EventManager.evaluate_daily_events()
	else:
		StatManager.current_phase += 1
		update_ui()
		print("Phase advanced. Current Phase: ", StatManager.current_phase)
		EventManager.evaluate_daily_events()

func _flash_phone_button() -> void:
	var parent_desk = get_parent()
	if parent_desk:
		var phone_btn = parent_desk.find_child("Phone Button", true, false)
		if phone_btn:
			var tween = create_tween()
			tween.tween_property(phone_btn, "modulate", Color(1, 0.25, 0.25, 1), 0.18)
			tween.tween_property(phone_btn, "modulate", Color(1, 1, 1, 1), 0.18)
			tween.tween_property(phone_btn, "modulate", Color(1, 0.25, 0.25, 1), 0.18)
			tween.tween_property(phone_btn, "modulate", Color(1, 1, 1, 1), 0.18)

func _show_notification_warning() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Unread Notifications"
	dialog.dialog_text = "Hindi pwedeng matapos ang araw nang may unread notifications ka sa phone! Buksan ang Phone sa desk para basahin at sagutin."
	spawn_dialog(dialog, "error_bump")
	_flash_phone_button()

func daily_cycle() -> void:
	# Process daily living costs before moving to the next day
	process_daily_expenses()
	
	# Stop immediately if a Game Over condition was met
	if check_game_over_conditions():
		return
	
	# Check for Weekly Summary BEFORE incrementing day
	if StatManager.current_day == 7 or StatManager.current_day == 14 or StatManager.current_day == 21 or StatManager.current_day == 28:
		if StatManager.has_side_income:
			StatManager.modify_happy(-3)
			StatManager.modify_social(-2)
		trigger_weekly_summary(int(StatManager.current_day / 7))
		
	# Check for Monthly Bills on the last day of the month
	if StatManager.current_day == StatManager.year[StatManager.current_month].days:
		trigger_monthly_bills()
	
	StatManager.current_day += 1
	if StatManager.year[StatManager.current_month].days < StatManager.current_day:
		StatManager.current_day = 1
		if StatManager.year[StatManager.current_month].month == "December":
			trigger_year_end_evaluation()
			return
		else:
			StatManager.current_month += 1
		
	StatManager.last_baldo_lesson = ""
	StatManager.last_baldo_lesson_topic = ""
	# Check for Salary (Day 1 and Day 15)
	if StatManager.current_day == 1 or StatManager.current_day == 15:
		receive_salary()
		
	print("New Day: " + StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day))
	update_ui()

func trigger_year_end_evaluation() -> void:
	enqueue_modal(func():
		is_game_over = true
		_update_next_button_visibility()
		var yee_scene = preload("res://scenes/year_end_evaluation.tscn")
		var yee_instance = yee_scene.instantiate()
		add_child(yee_instance)
		var eval_data: Dictionary = yee_instance.show_year_end_evaluation()
		SaveManager.save_completed_run(eval_data, false)
		yee_instance.play_again_requested.connect(func():
			yee_instance.visible = false
			yee_instance.queue_free()
			restart_new_year_run()
		)
		yee_instance.evaluation_closed.connect(func():
			yee_instance.visible = false
			yee_instance.queue_free()
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		)
	)

func restart_new_year_run() -> void:
	stop_auto_advance()
	auto_pause_override_reason = ""
	modal_queue.clear()
	is_modal_open = false
	is_game_over = false
	pending_desk_tool_to_open = ""
	_stats_baseline_initialized = false
	_ach_toast_queue.clear()
	_is_showing_ach_toast = false
	StatManager.reset_for_new_run()
	update_ui()
	_update_next_button_visibility()
	_start_initial_day()
	
func receive_salary() -> void:
	var before := LedgerManager.capture_state_snapshot()
	var base_salary = StatManager.base_biweekly_salary
	var side_bonus = StatManager.side_income_biweekly if StatManager.has_side_income else 0
	var is_13th_month_day: bool = (StatManager.current_month == 11 and StatManager.current_day == 15)
	var bonus_13th: int = StatManager.calculate_13th_month_pay() if is_13th_month_day else 0
	var total_gross = base_salary + side_bonus + bonus_13th
	var salary_amount = total_gross
	var garnished_amount = 0
	
	if StatManager.debt_balance > 0 and total_gross > 0:
		var max_garnish = int(total_gross * 0.25)
		if StatManager.debt_balance <= max_garnish:
			garnished_amount = StatManager.debt_balance
		else:
			garnished_amount = max_garnish
			
		StatManager.debt_balance -= garnished_amount
		salary_amount -= garnished_amount

	StatManager.current_balance += salary_amount
	StatManager.weekly_income += salary_amount
	StatManager.on_stats_changed.emit()
	
	var after := LedgerManager.capture_state_snapshot()
	var sal_title := "13th Month + Sahod Day" if bonus_13th > 0 else ("Sahod Day (" + StatManager.get_employment_display_text() + ")")
	var sal_sum := "Gross: ₱" + UITheme.format_num(total_gross) + " | Net Received: ₱" + UITheme.format_num(salary_amount)
	if side_bonus > 0:
		sal_sum += " (includes +₱" + UITheme.format_num(side_bonus) + " Side Hustle)"
	if bonus_13th > 0:
		sal_sum += " (includes +₱" + UITheme.format_num(bonus_13th) + " 13th Month Pay)"
	if garnished_amount > 0:
		sal_sum += " | Debt Garnished (25% cap): -₱" + UITheme.format_num(garnished_amount)
	LedgerManager.record_transaction(
		"Income",
		"stat_system",
		sal_title,
		sal_sum,
		salary_amount,
		LedgerManager.compute_deltas(before, after),
		{"base_salary": base_salary, "side_bonus": side_bonus, "bonus_13th": bonus_13th, "garnished_amount": garnished_amount, "employment_status": StatManager.employment_status}
	)
	if salary_amount > 0:
		LedgerManager.unlock_achievement("first_paycheck", "stat_system")
	SaveManager.save_game()
	
	var salary_month = StatManager.current_month
	var salary_day = StatManager.current_day
	var rows: Array = []
	var statutory_ded: int = 0
	match StatManager.employment_status:
		"regular":
			statutory_ded = 1000
		"new_stable_job":
			statutory_ded = 1300
		"temporary_job":
			statutory_ded = 500
	
	if base_salary > 0:
		rows.append({"label": "Gross Basic Pay", "value": "₱" + UITheme.format_num(base_salary + statutory_ded), "color": UITheme.INK_DARK})
		if statutory_ded > 0:
			rows.append({"label": "SSS / PhilHealth / Pag-IBIG", "value": "-₱" + UITheme.format_num(statutory_ded), "color": UITheme.TEXT_DANGER})
	else:
		rows.append({"label": "Regular Job Pay", "value": "₱0 (Laid Off)", "color": UITheme.INK_MUTED})
	if side_bonus > 0:
		rows.append({"label": "Freelance Side Hustle", "value": "+₱" + UITheme.format_num(side_bonus), "color": UITheme.TEXT_SUCCESS})
	if bonus_13th > 0:
		rows.append({"label": "13th Month Pay (Tax-Free)", "value": "+₱" + UITheme.format_num(bonus_13th), "color": UITheme.TEXT_SUCCESS})
	if garnished_amount > 0:
		rows.append({"label": "Kaltas sa Overdue Utang (25% Cap)", "value": "-₱" + UITheme.format_num(garnished_amount), "color": UITheme.TEXT_DANGER})
	rows.append({"divider": true, "bold": true, "label": "Hawak na Cash Ngayon", "value": "₱" + UITheme.format_num(StatManager.current_balance), "color": UITheme.TEXT_SUCCESS if StatManager.current_balance > 0 else UITheme.INK_DARK})

	var modal_title := "Walang Sahod Ngayon"
	var banner_col: Color = UITheme.BTN_CORAL
	var note_txt := "Gamitin nang maingat ang Emergency Fund at bawasan ang unnecessary gastos."
	var log_text := "Payday Notice: ₱0 — Laid Off"
	if base_salary == 0 and side_bonus > 0:
		modal_title = "Side Hustle Payday!"
		banner_col = UITheme.BTN_GOLD
		note_txt = "Walang regular na sahod dahil sa layoff, pero malaking tulong ang Side Hustle."
		log_text = "Side Hustle Payday: +₱" + UITheme.format_num(side_bonus)
	elif base_salary > 0:
		modal_title = "13th Month + Sahod Day!" if bonus_13th > 0 else "Sahod Day!"
		banner_col = UITheme.BTN_GOLD if bonus_13th > 0 else UITheme.BTN_SAGE
		if bonus_13th > 0:
			note_txt = "Batay sa PH TRAIN Law, tax-free ang 13th Month Pay hanggang ₱90,000!"
		elif garnished_amount > 0:
			note_txt = "May auto-kaltas (25% cap) para sa overdue debt. Bayaran ang natira sa Utang App."
		else:
			note_txt = "Payo ni Baldo: I-Smart Split agad para sigurado ang Upa, Bills, at Ipon!"
		log_text = "Sahod Day: +₱" + UITheme.format_num(salary_amount)
		if bonus_13th > 0:
			log_text += "\n[font_size=12][color=teal]+₱" + UITheme.format_num(bonus_13th) + " 13th Month Pay[/color][/font_size]"
		if side_bonus > 0:
			log_text += "\n[font_size=12][color=green]+₱" + UITheme.format_num(side_bonus) + " Side Hustle[/color][/font_size]"
	if garnished_amount > 0:
		log_text += "\n[font_size=12][color=red]-₱" + UITheme.format_num(garnished_amount) + " Kaltas Utang[/color][/font_size]"

	PlannerManager.record_event(salary_month, salary_day, log_text)
	var payslip_data := {
		"title": modal_title,
		"subtitle": StatManager.get_employment_display_text(),
		"hero_label": "Net Take-Home Pay",
		"net_received": salary_amount,
		"banner_color": banner_col,
		"rows": rows,
		"note": note_txt,
		"ok_text": "OK, Tuloy!"
	}
	var split_cb := Callable()
	if salary_amount > 0:
		split_cb = func():
			var res: Dictionary = StatManager.auto_budget_paycheck()
			var alloc: int = int(res.get("total_allocated", 0))
			if alloc > 0:
				AudioManager.play_sfx("cash_register")
				StatManager.set_baldo_lesson("Smart Split", "Na-allocate na ang ₱" + UITheme.format_num(alloc) + " across Bills, Food, Byahe, at Ipon!")
				_enqueue_banner_toast("SMART SPLIT COMPLETE", "Na-budget na ang ₱" + UITheme.format_num(alloc) + " sa Envelopes at Ipon!", UITheme.BTN_SAGE, "")
			else:
				AudioManager.play_sfx("click")
			update_ui()
			_run_next_modal()

	var payday_sfx: String = "payday" if salary_amount > 0 else "alert"
	enqueue_modal(func():
		AudioManager.play_sfx(payday_sfx)
		UITheme.spawn_payslip_modal(self, payslip_data, func():
			_run_next_modal()
		, split_cb)
	)
	
func trigger_weekly_summary(week_num: int) -> void:
	# Snapshot the weekly numbers and stat deltas at the moment the week ends
	var snap = StatManager.snapshot_weekly_summary(week_num)
	
	enqueue_modal(func():
		var weekly_summary_scene = preload("res://scenes/weekly_summary.tscn")
		var summary_instance = weekly_summary_scene.instantiate()
		add_child(summary_instance)
		summary_instance.show_summary_from_snapshot(snap)
		summary_instance.summary_action_requested.connect(func(action_name: String):
			pending_desk_tool_to_open = action_name
		)
		summary_instance.summary_closed.connect(func():
			summary_instance.visible = false
			summary_instance.queue_free()
			_run_next_modal()
		)
	)

func trigger_monthly_bills() -> void:
	var bill_month = StatManager.current_month
	var bill_day = StatManager.current_day
	var before_month_end := LedgerManager.capture_state_snapshot()
	LedgerManager.begin_composite()
	
	# 1. Apply 0.5%/mo (~6% p.a.) compounding monthly interest to Digital Bank Savings
	var savings_interest = StatManager.apply_monthly_savings_interest()
	
	# 2. Apply 3% compounding monthly interest to unpaid Credit Card balance (BSP cap)
	var cc_interest = StatManager.apply_monthly_credit_card_interest()
	
	# 3. Apply 5% compounding monthly interest to existing Overdue Debt
	var debt_interest = int(StatManager.debt_balance * 0.05)
	if debt_interest > 0:
		StatManager.debt_balance += debt_interest
		
	# 4. Process monthly Simple Interest Loan installments & Market-Mood Investment returns
	var loan_res = StatManager.process_monthly_loan_installments()
	var inv_delta := 0
	if StatManager.get_total_investments() > 0:
		var market_mood: Dictionary = StatManager.get_current_market_mood()
		var inv_res = StatManager.apply_investment_fluctuation(
			float(market_mood.get("low_rate", 0.018)),
			float(market_mood.get("high_rate", 0.06))
		)
		inv_delta = int(inv_res.get("total_delta", 0))
		
	var installments_due = StatManager.get_total_monthly_installments()
	var rent_amount = StatManager.monthly_rent
	var utilities_amount = max(0, StatManager.monthly_utilities + StatManager.extra_utilities_this_month + installments_due + StatManager.monthly_family_support)
	StatManager.extra_utilities_this_month = 0
	StatManager.advance_installments_one_month()
	var total_bills = rent_amount + utilities_amount
	
	var rent_env = StatManager.get_envelope_amount("Rent")
	var util_env = StatManager.get_envelope_amount("Utilities")
	
	if savings_interest > 0:
		LedgerManager.totals["total_interest_earned"] = int(LedgerManager.totals.get("total_interest_earned", 0)) + savings_interest
	if (cc_interest + debt_interest) > 0:
		LedgerManager.totals["total_interest_paid"] = int(LedgerManager.totals.get("total_interest_paid", 0)) + cc_interest + debt_interest
	
	if savings_interest > 0:
		StatManager.check_goal_milestones()
		StatManager.check_monthly_mission_completion()
	# GDD Section 3.3: Auto-settle without touching current_balance if envelopes cover both bills!
	if rent_env >= rent_amount and util_env >= utilities_amount:
		StatManager.spend_from_category("Rent", rent_amount)
		StatManager.spend_from_category("Utilities", utilities_amount)
		StatManager.modify_credit_score(2)
		var m_grade: Dictionary = StatManager.evaluate_monthly_grade(true, (cc_interest + debt_interest) > 0, bill_month)
		var grade_str: String = str(m_grade.get("grade", "B"))
		var grade_lbl: String = str(m_grade.get("label", ""))
		if grade_str == "S":
			StatManager.modify_happy(3)
			StatManager.modify_credit_score(1)
		LedgerManager.end_composite()
		
		LedgerManager.totals["bills_autopaid_count"] = int(LedgerManager.totals.get("bills_autopaid_count", 0)) + 1
		var bill_summary := "Rent: ₱" + UITheme.format_num(rent_amount) + " + Utilities/Installments: ₱" + UITheme.format_num(utilities_amount) + " (Auto-Paid, +2 CS, Grade " + grade_str + ")"
		if savings_interest > 0:
			bill_summary += " | Savings Interest: +₱" + UITheme.format_num(savings_interest)
		if inv_delta != 0:
			bill_summary += " | Investment Return: " + ("+" if inv_delta > 0 else "-") + "₱" + UITheme.format_num(abs(inv_delta))
		if (cc_interest + debt_interest) > 0:
			bill_summary += " | Interest Penalty: +₱" + UITheme.format_num(cc_interest + debt_interest)
		LedgerManager.record_transaction(
			"Bills",
			"stat_system",
			"Monthly Bills Auto-Paid",
			bill_summary,
			-total_bills - int(loan_res.get("paid_cash", 0)),
			LedgerManager.compute_deltas(before_month_end, LedgerManager.capture_state_snapshot()),
			{
				"auto_paid": true,
				"monthly_grade": grade_str,
				"rent_due": rent_amount,
				"utilities_due": utilities_amount,
				"savings_interest": savings_interest,
				"cc_interest": cc_interest,
				"debt_interest": debt_interest,
				"investment_delta": inv_delta
			}
		)
		LedgerManager.autosave_ledger()
		var grade_col: Color = UITheme.BTN_GOLD if grade_str == "S" else (UITheme.BTN_SAGE if grade_str == "A" else UITheme.PAPER_WARM)
		var grade_sub: String = str(m_grade.get("month", "")) + " Report Card — " + grade_lbl + (" (+3 Happy, +1 CS Bonus!)" if grade_str == "S" else "")
		_enqueue_banner_toast("MONTHLY GRADE: " + grade_str, grade_sub, grade_col, "grade_s" if grade_str == "S" else "toast_slide")
		
		var dialog = AcceptDialog.new()
		dialog.title = "Auto-Paid ang Monthly Bills!"
		var text = "Kumpleto ang iyong Cash Envelopes kaya automatic nang nabayaran ang bills:\n• Upa: ₱" + UITheme.format_num(rent_amount) + "\n• Utilities, Installments at Padala: ₱" + UITheme.format_num(utilities_amount) + "\n• Bonus: +2 Credit Score"
		var log_text = "Monthly Bills Auto-Paid: -₱" + UITheme.format_num(total_bills) + " • +2 Credit Score • Grade " + grade_str
		if savings_interest > 0:
			text += "\n\nTubo sa Ipon: +₱" + UITheme.format_num(savings_interest) + " mula sa 0.5%/buwan (6%/yr) Digital Bank interest."
			log_text += "\n[font_size=12][color=green]Savings Interest: +₱" + UITheme.format_num(savings_interest) + "[/color][/font_size]"
		if inv_delta != 0:
			var inv_sign = "+" if inv_delta > 0 else "-"
			text += "\nGalaw ng Investments: " + inv_sign + "₱" + UITheme.format_num(abs(inv_delta))
			log_text += "\n[font_size=12][color=aqua]Investments: " + inv_sign + "₱" + UITheme.format_num(abs(inv_delta)) + "[/color][/font_size]"
		if int(loan_res.get("paid_cash", 0)) > 0:
			text += "\nLoan Installment Paid: -₱" + UITheme.format_num(int(loan_res["paid_cash"]))
		if cc_interest > 0:
			text += "\nCredit Card Interest: +₱" + UITheme.format_num(cc_interest) + " sa natitirang balanse."
			log_text += "\n[font_size=12][color=orange]Credit Card Interest: +₱" + UITheme.format_num(cc_interest) + "[/color][/font_size]"
		if debt_interest > 0:
			text += "\nDebt Penalty: +₱" + UITheme.format_num(debt_interest) + " sa overdue utang."
			log_text += "\n[font_size=12][color=red]Debt Penalty: +₱" + UITheme.format_num(debt_interest) + "[/color][/font_size]"
		text += "\n\nReport Card: Grade " + grade_str + " — " + grade_lbl + (" (+3 Happy, +1 CS)" if grade_str == "S" else "")
		dialog.dialog_text = text
		PlannerManager.record_event(bill_month, bill_day, log_text)
		spawn_dialog(dialog, "cash_register")
	else:
		LedgerManager.end_composite()
		if savings_interest > 0 or (cc_interest + debt_interest) > 0 or inv_delta != 0:
			LedgerManager.record_transaction(
				"Interest & Returns",
				"stat_system",
				"Month-End Interest & Portfolio Update",
				"Savings Interest: +₱" + UITheme.format_num(savings_interest) + " | Debt/CC Interest: +₱" + UITheme.format_num(cc_interest + debt_interest) + " | Investments: " + ("+" if inv_delta >= 0 else "-") + "₱" + UITheme.format_num(abs(inv_delta)),
				-int(loan_res.get("paid_cash", 0)),
				LedgerManager.compute_deltas(before_month_end, LedgerManager.capture_state_snapshot()),
				{"savings_interest": savings_interest, "cc_interest": cc_interest, "debt_interest": debt_interest, "investment_delta": inv_delta}
			)
		# GDD Section 3.3: Cost Mismatch or Unallocated Budget -> Prompt player to manually settle!
		enqueue_modal(func():
			var mbs_scene = preload("res://scenes/monthly_bill_settlement.tscn")
			var mbs_instance = mbs_scene.instantiate()
			add_child(mbs_instance)
			mbs_instance.setup_settlement(bill_month, bill_day, rent_amount, utilities_amount, savings_interest, debt_interest + cc_interest)
			mbs_instance.settlement_completed.connect(func():
				mbs_instance.visible = false
				mbs_instance.queue_free()
				var m_grade: Dictionary = StatManager.evaluate_monthly_grade(false, (cc_interest + debt_interest) > 0, bill_month)
				var g_str: String = str(m_grade.get("grade", "B"))
				_enqueue_banner_toast("MONTHLY GRADE: " + g_str, str(m_grade.get("month", "")) + " Report Card — " + str(m_grade.get("label", "")), UITheme.BTN_SAGE if g_str == "A" else UITheme.PAPER_WARM)
				update_ui()
				_run_next_modal()
			)
		)
	
func process_daily_expenses() -> void:
	var before := LedgerManager.capture_state_snapshot()
	LedgerManager.begin_composite()
	var food_idx = clamp(StatManager.daily_food_choice, 0, 1)
	var food_cost = StatManager.get_daily_food_cost()
	var food_happy = StatManager.food_happy_deltas[food_idx]
	var food_env_before = StatManager.get_envelope_amount("Food")
	StatManager.spend_from_category("Food", food_cost)
	
	var has_commute := StatManager.is_commute_day()
	var comm_idx = clamp(StatManager.daily_commute_choice, 0, 1)
	var comm_cost := 0
	var comm_happy := 0
	var comm_env_before := 0
	if has_commute:
		comm_cost = StatManager.get_daily_commute_cost()
		comm_happy = StatManager.commute_happy_deltas[comm_idx]
		comm_env_before = StatManager.get_envelope_amount("Transportation")
		StatManager.spend_from_category("Transportation", comm_cost)
	
	var fully_covered: bool = (food_env_before >= food_cost) and ((not has_commute) or comm_env_before >= comm_cost)
	StatManager.record_daily_routine_envelope_coverage(fully_covered)
	StatManager.modify_happy(food_happy + comm_happy)
	LedgerManager.end_composite()
	
	var food_lbl := "Magluto" if food_idx == 0 else "Mag-order"
	var comm_lbl := "Walang Pasok" if StatManager.employment_status == "laid_off" else ("Weekend" if not has_commute else ("Public Transit" if comm_idx == 0 else "Mototaxi"))
	var tot_cost: int = food_cost + comm_cost
	LedgerManager.record_transaction(
		"Daily Routine",
		"stat_system",
		"Daily Living: " + food_lbl + " + " + comm_lbl,
		"Pagkain: ₱" + UITheme.format_num(food_cost) + " • Byahe: ₱" + UITheme.format_num(comm_cost) + " — " + ("Covered ng Envelopes" if fully_covered else "Nabawas sa Cash/Utang"),
		-tot_cost,
		LedgerManager.compute_deltas(before, LedgerManager.capture_state_snapshot()),
		{"food_choice": food_idx, "commute_choice": comm_idx, "food_cost": food_cost, "commute_cost": comm_cost, "envelopes_covered": fully_covered, "commute_active": has_commute}
	)
	
func check_game_over_conditions() -> bool:
	if StatManager.get_total_debt_and_loans() > 50000:
		trigger_game_over("Baon sa utang: lagpas ₱50,000 na ang kabuuang utang mo.")
		return true
		
	if StatManager.happy <= 0:
		StatManager.days_at_zero_happiness += 1
	else:
		StatManager.days_at_zero_happiness = 0
		
	if StatManager.social <= 0:
		StatManager.days_at_zero_social += 1
	else:
		StatManager.days_at_zero_social = 0
		
	if StatManager.days_at_zero_happiness >= 5:
		trigger_game_over("Na-burnout ka dahil 5 araw ka nang walang Happiness. Alagaan ang sarili sa susunod!")
		return true
		
	if StatManager.days_at_zero_social >= 5:
		trigger_game_over("Na-isolate mo ang sarili mo sa loob ng 5 araw. Mahalaga rin ang pakikipag-ugnayan!")
		return true
		
	return false

func trigger_game_over(reason: String) -> void:
	is_game_over = true
	AudioManager.play_sfx("alert")
	modal_queue.clear()
	_update_next_button_visibility()
	SaveManager.save_completed_run({}, true, reason)
	LedgerManager.record_milestone(
		"Game Over",
		"stat_system",
		"Game Over Triggered",
		reason,
		0,
		{},
		{"reason": reason}
	)
	LedgerManager.autosave_ledger()
	UITheme.spawn_game_confirm(
		self,
		"GAME OVER",
		reason + "\n\nGusto mo bang sumubok ulit ng bagong taon o bumalik sa Main Menu?",
		"Maglaro Ulit",
		"Bumalik sa Main Menu",
		UITheme.BTN_CORAL,
		func(): restart_new_year_run(),
		func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	
func _on_food_option_selected(index: int) -> void:
	if index == StatManager.daily_food_choice:
		return
	AudioManager.play_sfx("toggle")
	StatManager.daily_food_choice = index
	StatManager.on_stats_changed.emit()
	var cook_c: int = max(0, StatManager.food_costs[0] + StatManager.daily_food_modifier)
	var eat_c: int = max(0, StatManager.food_costs[1] + StatManager.daily_food_modifier)
	var chosen := "Magluto (₱" + UITheme.format_num(cook_c) + "/day, 0 Happy)" if index == 0 else "Mag-order (₱" + UITheme.format_num(eat_c) + "/day, +1 Happy)"
	var alt := "Mag-order (₱" + UITheme.format_num(eat_c) + "/day, +1 Happy)" if index == 0 else "Magluto (₱" + UITheme.format_num(cook_c) + "/day, 0 Happy)"
	var opp := "Saves ₱" + UITheme.format_num(abs(eat_c - cook_c)) + "/day by cooking instead of ordering out." if index == 0 else "Spends +₱" + UITheme.format_num(abs(eat_c - cook_c)) + "/day for +1 daily Happiness boost."
	LedgerManager.totals["routine_changes_count"] = int(LedgerManager.totals.get("routine_changes_count", 0)) + 1
	LedgerManager.record_tradeoff(
		"Routine Setting",
		"stat_system",
		"Changed Daily Food Routine",
		"Switched daily meal plan to " + chosen,
		chosen,
		[alt],
		opp,
		0,
		{},
		{"routine_type": "food", "choice_index": index}
	)

func _on_commute_option_selected(index: int) -> void:
	if index == StatManager.daily_commute_choice:
		return
	AudioManager.play_sfx("toggle")
	StatManager.daily_commute_choice = index
	StatManager.on_stats_changed.emit()
	var pub_c: int = max(0, StatManager.commute_costs[0] + StatManager.daily_commute_modifier)
	var moto_c: int = max(0, StatManager.commute_costs[1] + StatManager.daily_commute_modifier)
	var chosen := "Public Transit (₱" + UITheme.format_num(pub_c) + "/day, -1 Happy)" if index == 0 else "Mototaxi (₱" + UITheme.format_num(moto_c) + "/day, +1 Happy)"
	var alt := "Mototaxi (₱" + UITheme.format_num(moto_c) + "/day, +1 Happy)" if index == 0 else "Public Transit (₱" + UITheme.format_num(pub_c) + "/day, -1 Happy)"
	var opp := "Saves ₱" + UITheme.format_num(abs(moto_c - pub_c)) + "/day at the cost of -1 daily Happiness." if index == 0 else "Spends +₱" + UITheme.format_num(abs(moto_c - pub_c)) + "/day to avoid commute stress (+1 Happy vs -1 Happy)."
	LedgerManager.totals["routine_changes_count"] = int(LedgerManager.totals.get("routine_changes_count", 0)) + 1
	LedgerManager.record_tradeoff(
		"Routine Setting",
		"stat_system",
		"Changed Daily Commute Routine",
		"Switched daily commute to " + chosen,
		chosen,
		[alt],
		opp,
		0,
		{},
		{"routine_type": "commute", "choice_index": index}
	)

func _process(_delta: float) -> void:
	pass

func _on_button_pressed() -> void:
	happy_calc(5)

#### Goal Icon Modulation based on mouse activity 

func _on_goal_icon_mouse_entered() -> void:
	AudioManager.play_sfx("hover")
	# Slightly whiter/brighter on hover
	goal_icon.self_modulate = Color(1.3, 1.3, 1.3, 1.0)


func _on_goal_icon_mouse_exited() -> void:
	# Reset back to normal
	goal_icon.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
