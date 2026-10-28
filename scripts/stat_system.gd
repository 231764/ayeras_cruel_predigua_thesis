extends Node2D

@export var happy_bar: ProgressBar
@export var social_bar: ProgressBar
@export var current_balance: Label
@export var savings: Label
@export var credit_balance: Label
@export var credit_score: Label
@export var debt_balance: Label
@export var date_label: Label
@export var status_report_label: RichTextLabel

@onready var next_phase_button: Button = $NextPhaseButton
@onready var auto_advance_button: Button = get_node_or_null("AutoAdvanceButton")
@onready var goal_button: Button = $GoalButton
@onready var savings_jar_button: Button = $SavingsJarButton
@onready var envelope_runway_label: RichTextLabel = get_node_or_null("EnvelopeRunwayPanel/HBoxContainer/EnvelopeRunwayLabel")
@onready var baldo_toast_label: RichTextLabel = get_node_or_null("BaldoToastPanel/HBoxContainer/BaldoToastLabel")
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

func _ready() -> void:
	auto_advance_timer = Timer.new()
	auto_advance_timer.wait_time = 0.22
	auto_advance_timer.one_shot = false
	auto_advance_timer.timeout.connect(_on_auto_advance_tick)
	add_child(auto_advance_timer)
	_setup_shortcut_tooltips()
	
	update_ui()
	StatManager.on_stats_changed.connect(update_ui)
	
	EventManager.on_direct_event_triggered.connect(func(_event_data):
		stop_auto_advance()
		_update_next_button_visibility()
	)
	
	EventManager.on_indirect_event_triggered.connect(func(_event_data):
		stop_auto_advance()
		update_ui()
	)
	
	EventManager.on_event_resolved.connect(func(_id):
		auto_pause_override_reason = ""
		update_ui()
		_update_next_button_visibility()
	)
	
	# Initial goal selection, salary, and event check for the very first day
	if StatManager.current_day == 1 and StatManager.current_month == 0 and StatManager.current_phase == 0:
		call_deferred("_start_initial_day")
	else:
		EventManager.call_deferred("evaluate_daily_events")

func _start_initial_day() -> void:
	if not StatManager.has_selected_goal:
		trigger_goal_selection()
	receive_salary()

func _update_next_button_visibility() -> void:
	var can_advance := (not EventManager.is_direct_event_active) and (not is_modal_open) and (not is_game_over)
	if next_phase_button:
		next_phase_button.visible = can_advance
		if StatManager.current_phase > 0:
			next_phase_button.text = "▶ Finish Day"
		else:
			next_phase_button.text = "▶ Next Day"
	if auto_advance_button:
		auto_advance_button.visible = can_advance
		if is_auto_advancing:
			auto_advance_button.text = "⏸ Pause"
			auto_advance_button.modulate = Color(1.0, 0.9, 0.4, 1.0)
		else:
			auto_advance_button.text = "⏩ Auto-Play"
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

func _setup_shortcut_tooltips() -> void:
	if next_phase_button:
		next_phase_button.tooltip_text = "Advance 1 Full Day [Shortcut: Space]"
	if auto_advance_button:
		auto_advance_button.tooltip_text = "Toggle Fast-Forward Auto-Play [Shortcut: F]"
	var parent_desk = get_parent()
	if parent_desk:
		var s_btn = parent_desk.get_node_or_null("Status Button")
		if s_btn:
			s_btn.tooltip_text = "Player Status & Victory Report [Shortcut: 1]"
		var p_btn = parent_desk.get_node_or_null("Planner Button")
		if p_btn:
			p_btn.tooltip_text = "Calendar Planner & Milestones [Shortcut: 2]"
		var b_btn = parent_desk.get_node_or_null("Budget Button")
		if b_btn:
			b_btn.tooltip_text = "Cash Envelopes & Smart Budget [Shortcut: 3]"
		var ph_btn = parent_desk.get_node_or_null("Phone Button")
		if ph_btn:
			ph_btn.tooltip_text = "Smartphone, Apps & Baldo AI [Shortcut: 4]"
		var back_btn = parent_desk.get_node_or_null("Back Button")
		if back_btn:
			back_btn.tooltip_text = "Return to Main Desk [Shortcut: Esc]"

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
			if sub_open and back_btn.has_method("_on_pressed"):
				back_btn._on_pressed()
				return true
			if is_auto_advancing:
				stop_auto_advance()
				return true
			return false
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
	elif tool_name == "phone" or tool_name == "baldo_chat":
		var ph_btn = parent_desk.get_node_or_null("Phone Button")
		if ph_btn and ph_btn.has_method("_button_pressed"):
			ph_btn._button_pressed()
		if tool_name == "baldo_chat":
			var ph_ui = parent_desk.get_node_or_null("Phone Node/Phone Interface")
			if ph_ui and ph_ui.has_method("open_baldo_chat_direct"):
				ph_ui.open_baldo_chat_direct()

func _on_quick_budget_pressed() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return
	_open_desk_tool_by_name("budget")

func _on_ask_baldo_pressed() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return
	_open_desk_tool_by_name("baldo_chat")

func spawn_dialog(dialog: AcceptDialog) -> void:
	enqueue_modal(func():
		add_child(dialog)
		dialog.popup_centered()
		var closed := false
		var on_close = func():
			if closed:
				return
			closed = true
			dialog.hide()
			dialog.queue_free()
			_run_next_modal()
		dialog.confirmed.connect(on_close)
		dialog.canceled.connect(on_close)
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

func open_savings_and_goal_inspector() -> void:
	if is_modal_open or EventManager.is_direct_event_active or is_game_over:
		return
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

func update_ui() -> void:
	if happy_bar:
		happy_bar.value = StatManager.happy
	if social_bar:
		social_bar.value = StatManager.social
	if current_balance:
		current_balance.text = "PHP " + str(StatManager.current_balance)
	if savings:
		savings.text = "PHP " + str(StatManager.savings)
	if credit_balance:
		credit_balance.text = "PHP " + str(StatManager.credit_balance)
	if credit_score:
		credit_score.text = str(StatManager.credit_score)
	if debt_balance:
		debt_balance.text = "PHP " + str(StatManager.get_total_debt_and_loans())
	
	var phase_names = ["Morning", "Afternoon", "Evening"]
	if date_label:
		var notif_badge = ""
		if EventManager.active_events.size() > 0:
			notif_badge = "  [📱 " + str(EventManager.active_events.size()) + " Unread]"
		date_label.text = StatManager.year[StatManager.current_month].month + " " + str(StatManager.current_day) + " - " + phase_names[StatManager.current_phase] + notif_badge
		
	if goal_button:
		var g = StatManager.get_current_goal()
		var pct = StatManager.get_goal_progress_percent()
		goal_button.text = "🎯 " + str(g["title"]) + ": PHP " + str(StatManager.savings) + " / " + str(g["cost"]) + " (" + str(pct) + "%)"
		
	if savings_jar_button:
		savings_jar_button.text = "🏺 Ipon: PHP " + str(StatManager.savings) + " (+2%/mo)\n[Maghulog / Kumuha]"
		
	if food_option:
		var cook_cost = max(0, StatManager.food_costs[0] + StatManager.daily_food_modifier)
		var eatout_cost = max(0, StatManager.food_costs[1] + StatManager.daily_food_modifier)
		food_option.set_item_text(0, "Magluto (PHP " + str(cook_cost) + ")")
		food_option.set_item_text(1, "Mag-order (PHP " + str(eatout_cost) + ")")
		if food_option.selected != StatManager.daily_food_choice:
			food_option.selected = StatManager.daily_food_choice
			
	if commute_option:
		var pub_cost = max(0, StatManager.commute_costs[0] + StatManager.daily_commute_modifier)
		var moto_cost = max(0, StatManager.commute_costs[1] + StatManager.daily_commute_modifier)
		commute_option.set_item_text(0, "Jeep/Bus (PHP " + str(pub_cost) + ")")
		commute_option.set_item_text(1, "Angkas/Joyride (PHP " + str(moto_cost) + ")")
		if commute_option.selected != StatManager.daily_commute_choice:
			commute_option.selected = StatManager.daily_commute_choice
			
	_check_and_spawn_floating_deltas()
	_update_envelope_runway_ui()
	_update_baldo_toast_ui()
	_update_next_button_visibility()
	_update_status_report()

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
		spawn_floating_delta(current_balance, ("+PHP " if diff > 0 else "-PHP ") + str(abs(diff)), Color(0.25, 1.0, 0.35) if diff > 0 else Color(1.0, 0.35, 0.35))
		
	if StatManager.savings != _prev_savings:
		var diff := StatManager.savings - _prev_savings
		_prev_savings = StatManager.savings
		spawn_floating_delta(savings, ("+PHP " if diff > 0 else "-PHP ") + str(abs(diff)) + " Ipon", Color(0.3, 0.9, 1.0) if diff > 0 else Color(1.0, 0.75, 0.3))
		
	if StatManager.credit_balance != _prev_credit_balance:
		var diff := StatManager.credit_balance - _prev_credit_balance
		_prev_credit_balance = StatManager.credit_balance
		spawn_floating_delta(credit_balance, ("+PHP " if diff > 0 else "-PHP ") + str(abs(diff)) + " Credit", Color(1.0, 0.65, 0.25) if diff > 0 else Color(0.3, 1.0, 0.5))
		
	if StatManager.credit_score != _prev_credit_score:
		var diff := StatManager.credit_score - _prev_credit_score
		_prev_credit_score = StatManager.credit_score
		spawn_floating_delta(credit_score, ("+" if diff > 0 else "") + str(diff) + " CS", Color(0.3, 1.0, 0.4) if diff > 0 else Color(1.0, 0.3, 0.3))
		
	if cur_debt_total != _prev_debt:
		var diff := cur_debt_total - _prev_debt
		_prev_debt = cur_debt_total
		spawn_floating_delta(debt_balance, ("+PHP " if diff > 0 else "-PHP ") + str(abs(diff)) + " Debt", Color(1.0, 0.25, 0.25) if diff > 0 else Color(0.3, 1.0, 0.4))
		
	if StatManager.happy != _prev_happy:
		var diff := StatManager.happy - _prev_happy
		_prev_happy = StatManager.happy
		spawn_floating_delta(happy_bar, ("+" if diff > 0 else "") + str(diff) + " Happy", Color(0.3, 1.0, 0.4) if diff > 0 else Color(1.0, 0.4, 0.4))
		
	if StatManager.social != _prev_social:
		var diff := StatManager.social - _prev_social
		_prev_social = StatManager.social
		spawn_floating_delta(social_bar, ("+" if diff > 0 else "") + str(diff) + " Social", Color(0.3, 0.9, 1.0) if diff > 0 else Color(1.0, 0.45, 0.35))

func spawn_floating_delta(target_node: Control, text_str: String, color: Color) -> void:
	recent_floating_popups_count += 1
	last_floating_popup_text = text_str
	if not target_node or not is_inside_tree():
		return
	var lbl := Label.new()
	lbl.text = text_str
	lbl.z_index = 25
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _update_envelope_runway_ui() -> void:
	if not envelope_runway_label:
		return
	var daily_food: int = max(1, StatManager.get_daily_food_cost())
	var food_env: int = StatManager.get_envelope_amount("Food")
	var food_days: int = int(food_env / daily_food)
	var food_col := "green" if food_days >= 5 else ("yellow" if food_env > 0 else "red")
	
	var daily_trans: int = max(1, StatManager.get_daily_commute_cost())
	var trans_env: int = StatManager.get_envelope_amount("Transportation")
	var trans_days: int = int(trans_env / daily_trans)
	var trans_col := "green" if trans_days >= 5 else ("yellow" if trans_env > 0 else "red")
	
	var ent_env: int = StatManager.get_envelope_amount("Entertainment")
	var rent_env: int = StatManager.get_envelope_amount("Rent")
	var rent_ok: bool = (rent_env >= StatManager.monthly_rent)
	var rent_col := "green" if rent_ok else "orange"
	var rent_icon := "✅" if rent_ok else "⚠️"
	
	var total_util: int = StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
	var util_env: int = StatManager.get_envelope_amount("Utilities")
	var util_ok: bool = (util_env >= total_util)
	var util_col := "green" if util_ok else "orange"
	var util_icon := "✅" if util_ok else "⚠️"
	
	envelope_runway_label.text = (
		"🍔 Pagkain: [color=" + food_col + "]PHP " + str(food_env) + " (" + str(food_days) + "d)[/color] | " +
		"🚌 Byahe: [color=" + trans_col + "]PHP " + str(trans_env) + " (" + str(trans_days) + "d)[/color] | " +
		"🎉 Libangan: PHP " + str(ent_env) + " | " +
		"🏠 Upa: [color=" + rent_col + "]PHP " + str(rent_env) + "/" + str(StatManager.monthly_rent) + " " + rent_icon + "[/color] | " +
		"⚡ Bills: [color=" + util_col + "]PHP " + str(util_env) + "/" + str(total_util) + " " + util_icon + "[/color]"
	)

func get_live_baldo_desk_tip() -> String:
	if auto_pause_override_reason != "":
		return "⏸️ [b][color=yellow]Baldo (Auto-Paused):[/color][/b] " + auto_pause_override_reason
		
	if EventManager.active_events.size() > 0:
		var ev_title := str(EventManager.active_events[0].get("title", "New Message"))
		return "📱 [b][color=orange]Baldo:[/color][/b] Uy par, may unread notification ka sa Phone ([i]\"" + ev_title + "\"[/i])! Buksan ang Phone bago matapos ang araw."
		
	if StatManager.happy < 40 or StatManager.social < 40:
		return "⚠️ [b][color=red]Baldo:[/color][/b] Mababa na ang Happiness (" + str(StatManager.happy) + ") o Social (" + str(StatManager.social) + ") mo! Mag-Angkas/Mag-order muna para iwas Burnout!"
		
	var food_env := StatManager.get_envelope_amount("Food")
	var trans_env := StatManager.get_envelope_amount("Transportation")
	var rent_env := StatManager.get_envelope_amount("Rent")
	var util_env := StatManager.get_envelope_amount("Utilities")
	var total_util := StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
	
	if StatManager.employment_status == "laid_off":
		return "🛡️ [b][color=yellow]Baldo:[/color][/b] Laid Off tayo ngayon par—gamitin ang Severance/Emergency Fund sa Ipon at Todo Tipid Mode para di mabaon sa utang!"
		
	if (StatManager.current_day == 1 or StatManager.current_day == 15) and (rent_env < StatManager.monthly_rent or food_env < StatManager.get_daily_food_cost() * 5):
		return "💰 [b][color=lightblue]Baldo:[/color][/b] Sahod Day ngayon! I-click ang [b]'📂 Budget Now'[/b] para pondohan ang Upa, Bills, at 15-day Pagkain/Byahe envelopes!"
		
	if food_env == 0 or trans_env == 0:
		return "🍔 [b][color=orange]Baldo:[/color][/b] Walang laman ang Pagkain o Byahe envelope mo! Bumabawas na tayo direkta sa Pocket Cash—mag-allocate sa Budget Envelopes."
		
	if StatManager.current_day >= 23 and (rent_env < StatManager.monthly_rent or util_env < total_util):
		var short_amt: int = max(0, StatManager.monthly_rent - rent_env) + max(0, total_util - util_env)
		return "🏠 [b][color=orange]Baldo:[/color][/b] Malapit na ang Katapusan! Kulang pa ng PHP " + str(short_amt) + " ang Upa/Bills envelopes mo para sa auto-pay (+2 Credit Score)."
		
	if StatManager.credit_balance > 0 and StatManager.current_day >= 20:
		return "💳 [b][color=yellow]Baldo:[/color][/b] May PHP " + str(StatManager.credit_balance) + " Credit Card balance ka! Bayaran nang buo sa Statement (Day 25) para iwas 5% interest."
		
	return "🔥 [b][color=lightgreen]Baldo:[/color][/b] Solid ang envelope runway mo par! Pwede kang mag-[b]⏩ Auto-Play[/b] o maghulog ng sobrang cash sa Ipon (+2%/mo)!"

func _update_baldo_toast_ui() -> void:
	if baldo_toast_label:
		baldo_toast_label.text = get_live_baldo_desk_tip()

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
	
	var goal_ok = "[color=green]REACHED (PHP " + str(StatManager.savings) + " / PHP " + str(target) + ")[/color]" if StatManager.savings >= target else "[color=yellow]PHP " + str(StatManager.savings) + " / PHP " + str(target) + " (" + str(pct) + "%)[/color]"
	var happy_ok = "[color=green]GOOD (" + str(StatManager.happy) + "/100)[/color]" if StatManager.happy >= 50 else "[color=red]LOW (" + str(StatManager.happy) + "/100 - Need >=50)[/color]"
	var social_ok = "[color=green]GOOD (" + str(StatManager.social) + "/100)[/color]" if StatManager.social >= 50 else "[color=red]LOW (" + str(StatManager.social) + "/100 - Need >=50)[/color]"
	var credit_ok = "[color=green]GOOD (" + str(StatManager.credit_score) + "/100)[/color]" if StatManager.credit_score >= 70 else "[color=red]POOR (" + str(StatManager.credit_score) + "/100 - Need >=70)[/color]"
	var debt_ok = "[color=green]DEBT-FREE (PHP 0)[/color]" if total_debt_and_loans == 0 and StatManager.credit_balance == 0 else "[color=red]HAS OBLIGATIONS (Debt/Loans: PHP " + str(total_debt_and_loans) + ", Credit: PHP " + str(StatManager.credit_balance) + ")[/color]"
	
	var txt = "[b][font_size=22]" + stage_info["name"] + "[/font_size][/b]\n"
	txt += "[i]\"" + stage_info["theme"] + "\"[/i]\n\n"
	txt += "[b]1. Year-End Victory Conditions Status:[/b]\n"
	txt += "• Employment Status: [color=yellow]" + StatManager.get_employment_display_text() + "[/color]\n"
	txt += "• Life Goal (" + str(g["title"]) + "): " + goal_ok + "\n"
	txt += "• Well-Being (Happiness): " + happy_ok + "\n"
	txt += "• Relationships (Sociability): " + social_ok + "\n"
	txt += "• Credit Standing: " + credit_ok + "\n"
	txt += "• Debt, Loans & Credit Status: " + debt_ok + "\n"
	txt += "• Savings Interest Earned: [color=lightblue]PHP " + str(StatManager.total_savings_interest_earned) + "[/color] | Investments: [color=aqua]PHP " + str(StatManager.get_total_investments()) + "[/color] (P&L: PHP " + str(StatManager.total_investment_gains) + ")\n\n"
	txt += "[b]2. Monthly Bills, Loans, Installments & Allocated Envelopes:[/b]\n"
	txt += "• Upa (Rent): PHP " + str(rent_env) + " / PHP " + str(StatManager.monthly_rent) + "\n"
	txt += "• Utilities + Installments + Family Support: PHP " + str(util_env) + " / PHP " + str(total_util) + " (Installments: " + StatManager.get_installments_summary_text() + ", Family Padala: PHP " + str(StatManager.monthly_family_support) + "/mo)\n"
	txt += "• Credit Card Envelope: PHP " + str(cc_env) + " (Card Balance: PHP " + str(StatManager.credit_balance) + " / Limit: PHP " + str(StatManager.credit_limit) + ")\n"
	txt += "• Active Simple Interest Loans: " + StatManager.get_loans_summary_text() + "\n"
	txt += "• Pagkain (Food): PHP " + str(food_env) + " | Pamasahe: PHP " + str(trans_env) + " | Libangan: PHP " + str(ent_env) + "\n"
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
	_auto_started_with_trans_env = (StatManager.get_envelope_amount("Transportation") > 0)
	_auto_started_with_healthy_happy = (StatManager.happy >= 35)
	_auto_started_with_healthy_social = (StatManager.social >= 35)
	is_auto_advancing = true
	if auto_advance_timer:
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
		stop_auto_advance("Ubos na ang Pagkain Envelope mo! Mag-reload sa '📂 Budget Now' para di mabawasan ang Pocket Cash.")
		return
	if _auto_started_with_trans_env and StatManager.get_envelope_amount("Transportation") == 0:
		stop_auto_advance("Ubos na ang Byahe Envelope mo! Mag-reload sa '📂 Budget Now' para di mabawasan ang Pocket Cash.")
		return
	if (_auto_started_with_healthy_happy and StatManager.happy < 35) or (_auto_started_with_healthy_social and StatManager.social < 35):
		stop_auto_advance("Bumaba na sa <35 ang Happiness o Social mo! Mag-order/Mag-Angkas muna para iwas Burnout.")
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
	spawn_dialog(dialog)
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
		yee_instance.show_year_end_evaluation()
		yee_instance.play_again_requested.connect(func():
			yee_instance.visible = false
			yee_instance.queue_free()
			restart_new_year_run()
		)
		yee_instance.evaluation_closed.connect(func():
			yee_instance.visible = false
			yee_instance.queue_free()
			get_tree().quit()
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
	StatManager.reset_for_new_run()
	update_ui()
	_update_next_button_visibility()
	_start_initial_day()
	
func receive_salary() -> void:
	var base_salary = StatManager.base_biweekly_salary
	var side_bonus = StatManager.side_income_biweekly if StatManager.has_side_income else 0
	var total_gross = base_salary + side_bonus
	var salary_amount = total_gross
	var garnished_amount = 0
	
	if StatManager.debt_balance > 0 and total_gross > 0:
		var max_garnish = int(total_gross * 0.5)
		if StatManager.debt_balance <= max_garnish:
			garnished_amount = StatManager.debt_balance
		else:
			garnished_amount = max_garnish
			
		StatManager.debt_balance -= garnished_amount
		salary_amount -= garnished_amount

	StatManager.current_balance += salary_amount
	StatManager.weekly_income += salary_amount
	StatManager.on_stats_changed.emit()
	
	var salary_month = StatManager.current_month
	var salary_day = StatManager.current_day
	var dialog = AcceptDialog.new()
	var text := ""
	var log_text := ""
	if base_salary == 0 and side_bonus == 0:
		dialog.title = "Walang Sahod (Laid Off)"
		text = "Kasalukuyan kang walang regular na trabaho (Laid Off), kaya PHP 0 ang pumasok ngayong araw ng sahod. Gamitin nang maingat ang iyong Severance Pay at Ipon!"
		log_text = "Payday Notice: PHP 0 (Laid Off)"
	elif base_salary == 0 and side_bonus > 0:
		dialog.title = "Side Hustle Payday!"
		text = "Walang regular na sahod dahil sa Layoff, pero kumita ka ng PHP " + str(side_bonus) + " mula sa iyong Freelance Side Hustle!"
		log_text = "Side Hustle Payday! (+ PHP " + str(side_bonus) + ")"
	else:
		dialog.title = "Sahod Day!"
		text = "Pumasok na ang sahod mo na PHP " + str(base_salary) + " (" + StatManager.get_employment_display_text() + ")!"
		log_text = "Sahod Day! (+ PHP " + str(base_salary) + ")"
		if side_bonus > 0:
			text += "\n+ PHP " + str(side_bonus) + " mula sa iyong Freelance Side Hustle (Total: PHP " + str(total_gross) + ")!"
			log_text += "\n[font_size=12][color=green]+PHP " + str(side_bonus) + " Side Hustle[/color][/font_size]"
	if garnished_amount > 0:
		text += "\n\nPero kinuha ng banko ang PHP " + str(garnished_amount) + " para pambayad sa utang mo!"
		text += "\nAng natira sa iyo ay PHP " + str(salary_amount) + "."
		log_text += "\n[font_size=12][color=red]-" + str(garnished_amount) + " PHP Kaltas Utang[/color][/font_size]"
		
	dialog.dialog_text = text
	PlannerManager.record_event(salary_month, salary_day, log_text)
	spawn_dialog(dialog)
	
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
	
	# 1. Apply 2% compounding monthly interest to Bank Savings (GDD Section 4.4)
	var savings_interest = StatManager.apply_monthly_savings_interest()
	
	# 2. Apply 5% compounding monthly interest to unpaid Credit Card balance (GDD Section 4.4)
	var cc_interest = StatManager.apply_monthly_credit_card_interest()
	
	# 3. Apply 5% compounding monthly interest to existing Overdue Debt
	var debt_interest = int(StatManager.debt_balance * 0.05)
	if debt_interest > 0:
		StatManager.debt_balance += debt_interest
		
	# 4. Process monthly Simple Interest Loan installments & Investment returns
	var loan_res = StatManager.process_monthly_loan_installments()
	var inv_delta := 0
	if StatManager.get_total_investments() > 0:
		var inv_res = StatManager.apply_investment_fluctuation(0.04, 0.08)
		inv_delta = int(inv_res.get("total_delta", 0))
		
	var installments_due = StatManager.get_total_monthly_installments()
	var rent_amount = StatManager.monthly_rent
	var utilities_amount = max(0, StatManager.monthly_utilities + StatManager.extra_utilities_this_month + installments_due + StatManager.monthly_family_support)
	StatManager.extra_utilities_this_month = 0
	StatManager.advance_installments_one_month()
	var total_bills = rent_amount + utilities_amount
	
	var rent_env = StatManager.get_envelope_amount("Rent")
	var util_env = StatManager.get_envelope_amount("Utilities")
	
	# GDD Section 3.3: Auto-settle without touching current_balance if envelopes cover both bills!
	if rent_env >= rent_amount and util_env >= utilities_amount:
		StatManager.spend_from_category("Rent", rent_amount)
		StatManager.spend_from_category("Utilities", utilities_amount)
		StatManager.modify_credit_score(2)
		
		var dialog = AcceptDialog.new()
		dialog.title = "Auto-Paid na ang Monthly Bills!"
		var text = "Dahil kumpleto ang naka-budget mo sa Cash Envelopes, automatic nang nabayaran ang bills nang hindi nabawasan ang hawak mong cash!\n\n• Upa: PHP " + str(rent_amount) + "\n• Kuryente/Tubig + Installments + Family Padala: PHP " + str(utilities_amount) + "\n• +2 Credit Score!"
		var log_text = "Monthly Bills Auto-Paid via Envelopes! [- PHP " + str(total_bills) + "] (+2 Credit Score)"
		if savings_interest > 0:
			text += "\n\nKumita rin ang Ipon mo sa bangko ng +PHP " + str(savings_interest) + " (2% Compounding Interest)!"
			log_text += "\n[font_size=12][color=green]Savings Compounding Interest +" + str(savings_interest) + " PHP[/color][/font_size]"
		if inv_delta != 0:
			var inv_sign = "+" if inv_delta > 0 else ""
			text += "\n\nInvestments Monthly Update: " + inv_sign + "PHP " + str(inv_delta)
			log_text += "\n[font_size=12][color=aqua]Investments Return " + inv_sign + str(inv_delta) + " PHP[/color][/font_size]"
		if int(loan_res.get("paid_cash", 0)) > 0:
			text += "\n\nNabayaran din ang Loan Installment: -PHP " + str(loan_res["paid_cash"])
		if cc_interest > 0:
			text += "\n\n⚠ Pumatong ang +PHP " + str(cc_interest) + " (5% Compounding Interest) sa hindi nabayarang Credit Card balance!"
			log_text += "\n[font_size=12][color=orange]Credit Card Interest +" + str(cc_interest) + " PHP[/color][/font_size]"
		if debt_interest > 0:
			text += "\n\nPero nadagdagan ng PHP " + str(debt_interest) + " (5% Interest) ang dati mong utang."
			log_text += "\n[font_size=12][color=red]Debt Interest Penalty -" + str(debt_interest) + " PHP[/color][/font_size]"
		dialog.dialog_text = text
		PlannerManager.record_event(bill_month, bill_day, log_text)
		spawn_dialog(dialog)
	else:
		# GDD Section 3.3: Cost Mismatch or Unallocated Budget -> Prompt player to manually settle!
		enqueue_modal(func():
			var mbs_scene = preload("res://scenes/monthly_bill_settlement.tscn")
			var mbs_instance = mbs_scene.instantiate()
			add_child(mbs_instance)
			mbs_instance.setup_settlement(bill_month, bill_day, rent_amount, utilities_amount, savings_interest, debt_interest + cc_interest)
			mbs_instance.settlement_completed.connect(func():
				mbs_instance.visible = false
				mbs_instance.queue_free()
				update_ui()
				_run_next_modal()
			)
		)
	
func process_daily_expenses() -> void:
	var food_idx = clamp(StatManager.daily_food_choice, 0, 1)
	var food_cost = StatManager.get_daily_food_cost()
	var food_happy = StatManager.food_happy_deltas[food_idx]
	var food_env_before = StatManager.get_envelope_amount("Food")
	StatManager.spend_from_category("Food", food_cost)
	
	var comm_idx = clamp(StatManager.daily_commute_choice, 0, 1)
	var comm_cost = StatManager.get_daily_commute_cost()
	var comm_happy = StatManager.commute_happy_deltas[comm_idx]
	var comm_env_before = StatManager.get_envelope_amount("Transportation")
	StatManager.spend_from_category("Transportation", comm_cost)
	
	StatManager.record_daily_routine_envelope_coverage(food_env_before >= food_cost and comm_env_before >= comm_cost)
	StatManager.modify_happy(food_happy + comm_happy)
	
func check_game_over_conditions() -> bool:
	if StatManager.get_total_debt_and_loans() > 50000:
		trigger_game_over("GAME OVER: Baon sa utang! (Lagpas PHP 50,000 na ang utang mo)")
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
		trigger_game_over("GAME OVER: Na-burnout ka dahil 5 days ka nang walang happiness. Need mo mag-unwind!")
		return true
		
	if StatManager.days_at_zero_social >= 5:
		trigger_game_over("GAME OVER: Na-isolate mo na sarili mo for 5 days. Ingatan ang mental health!")
		return true
		
	return false

func trigger_game_over(reason: String) -> void:
	is_game_over = true
	modal_queue.clear()
	_update_next_button_visibility()
	var dialog = ConfirmationDialog.new()
	dialog.title = "GAME OVER"
	dialog.dialog_text = reason + "\n\nGusto mo bang maglaro ulit (New 1-Year Run)?"
	dialog.ok_button_text = "Maglaro Ulit (Restart)"
	dialog.cancel_button_text = "Lumabas (Quit)"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		restart_new_year_run()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
		get_tree().quit()
	)
	
func _on_food_option_selected(index: int) -> void:
	StatManager.daily_food_choice = index
	StatManager.on_stats_changed.emit()

func _on_commute_option_selected(index: int) -> void:
	StatManager.daily_commute_choice = index
	StatManager.on_stats_changed.emit()

func _process(_delta: float) -> void:
	pass

func _on_button_pressed() -> void:
	happy_calc(5)
