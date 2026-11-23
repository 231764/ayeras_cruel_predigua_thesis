extends Control

const UITheme = preload("res://scripts/ui_theme.gd")

@onready var header_title: Label = $Header/Title
@onready var home_scroll: ScrollContainer = $ScrollContainer
@onready var baldo_btn: Button = $ScrollContainer/VBoxContainer/BaldoButton
@onready var loans_app_btn: Button = $ScrollContainer/VBoxContainer/AppsRow/LoansAppButton
@onready var invest_app_btn: Button = $ScrollContainer/VBoxContainer/AppsRow/InvestAppButton
@onready var notifications_container: VBoxContainer = $ScrollContainer/VBoxContainer/NotificationsContainer

@onready var event_detail_panel: Panel = $EventDetailPanel
@onready var event_title: Label = $EventDetailPanel/VBoxContainer/EventTitle
@onready var event_desc: Label = $EventDetailPanel/VBoxContainer/EventDescription
@onready var options_container: VBoxContainer = $EventDetailPanel/VBoxContainer/OptionsScroll/OptionsContainer
@onready var event_back_btn: Button = $EventDetailPanel/VBoxContainer/BackButton

@onready var chat_panel: Panel = $ChatPanel
@onready var chat_title: Label = get_node_or_null("ChatPanel/VBoxContainer/ChatTitle")
@onready var chat_history: RichTextLabel = $ChatPanel/VBoxContainer/ChatHistory
@onready var quick_budget_btn: Button = get_node_or_null("ChatPanel/VBoxContainer/QuickAskGrid/QuickBudgetBtn")
@onready var quick_savings_btn: Button = get_node_or_null("ChatPanel/VBoxContainer/QuickAskGrid/QuickSavingsBtn")
@onready var quick_debt_btn: Button = get_node_or_null("ChatPanel/VBoxContainer/QuickAskGrid/QuickDebtBtn")
@onready var quick_goal_btn: Button = get_node_or_null("ChatPanel/VBoxContainer/QuickAskGrid/QuickGoalBtn")
@onready var chat_input: LineEdit = $ChatPanel/VBoxContainer/HBoxContainer/ChatInput
@onready var send_button: Button = $ChatPanel/VBoxContainer/HBoxContainer/SendButton
@onready var close_chat_btn: Button = $ChatPanel/VBoxContainer/CloseChatButton
@onready var ai_http_request: HTTPRequest = $AIHTTPRequest

@onready var loans_panel: Panel = $LoansPanel
@onready var loans_info_label: RichTextLabel = $LoansPanel/VBoxContainer/LoansInfoLabel
@onready var borrow_5k_btn: Button = $LoansPanel/VBoxContainer/Borrow5kButton
@onready var borrow_10k_btn: Button = $LoansPanel/VBoxContainer/Borrow10kButton
@onready var pay_loan_inst_btn: Button = $LoansPanel/VBoxContainer/PayLoanInstallmentButton
@onready var pay_loan_full_btn: Button = $LoansPanel/VBoxContainer/PayLoanFullButton
@onready var pay_overdue_debt_btn: Button = $LoansPanel/VBoxContainer/PayOverdueDebtButton
@onready var close_loans_btn: Button = $LoansPanel/VBoxContainer/CloseLoansButton

@onready var invest_panel: Panel = $InvestPanel
@onready var invest_info_label: RichTextLabel = $InvestPanel/VBoxContainer/InvestInfoLabel
@onready var invest_low_btn: Button = $InvestPanel/VBoxContainer/InvestLowRiskButton
@onready var invest_high_btn: Button = $InvestPanel/VBoxContainer/InvestHighRiskButton
@onready var withdraw_cash_btn: Button = $InvestPanel/VBoxContainer/WithdrawCashButton
@onready var transfer_savings_btn: Button = $InvestPanel/VBoxContainer/TransferSavingsButton
@onready var close_invest_btn: Button = $InvestPanel/VBoxContainer/CloseInvestButton

var current_viewing_event_id: String = ""
var chat_messages: Array = []
var is_request_pending: bool = false
var is_lag_waiting: bool = false
var _phone_art_frame: PanelContainer = null
var _phone_art_texture: TextureRect = null
var _phone_cat_chip: PanelContainer = null
var _phone_cat_pill: Label = null
var _phone_art_tween: Tween = null
var _chat_presence_row: HBoxContainer = null
var _chat_dot: Panel = null
var _chat_status_lbl: Label = null
var _ai_last_status: String = "idle"
var _offline_turn_counter: int = 0
var _last_offline_reply: String = ""

func _ready() -> void:
	EventManager.on_indirect_event_triggered.connect(_on_event_triggered)
	EventManager.on_event_resolved.connect(_on_event_resolved)
	StatManager.on_stats_changed.connect(_on_stats_updated)
	ai_http_request.request_completed.connect(_on_ai_request_completed)
	
	if chat_input and not chat_input.text_submitted.is_connected(_on_chat_input_submitted):
		chat_input.text_submitted.connect(_on_chat_input_submitted)
	
	_apply_visual_styles()
	_ensure_phone_event_category_header()
	_ensure_chat_mode_bar()
	_refresh_chat_mode_indicator()
	_wire_quick_ask_buttons()
	_set_active_subpanel(null)
	
	# Initialize system prompt slot (dynamically refreshed with live context before every message)
	chat_messages.append({
		"role": "system",
		"content": _build_system_prompt()
	})
	
	add_chat_bubble("Baldo", "Yow par! Ako si Baldo, ang financial buddy mo. Tanong ka lang kung paano i-budget ang sahod mo, ano gagawin sa bills, o kung may gumugulo sa isip mo!")
	_on_stats_updated()
	refresh_notifications()

func _style_button(btn: Button, bg: Color, radius: int = 8) -> void:
	UITheme.style_Button(btn, bg, radius, 4)

func _apply_visual_styles() -> void:
	_style_button(baldo_btn, UITheme.BTN_SAGE, 10)
	_style_button(loans_app_btn, UITheme.BTN_GOLD, 10)
	_style_button(invest_app_btn, UITheme.BTN_BLUE, 10)
	UITheme.apply_type(header_title, UITheme.TYPE_SUBHEAD, UITheme.FONT_HEADING)
	UITheme.style_header_banner(event_title, UITheme.BTN_GOLD, 7, 5.0, UITheme.TYPE_SUBHEAD)
	UITheme.style_header_banner(get_node_or_null("ChatPanel/VBoxContainer/ChatTitle") as Label, UITheme.BTN_SAGE, 7, 5.0, UITheme.TYPE_SUBHEAD)
	UITheme.style_header_banner(get_node_or_null("LoansPanel/VBoxContainer/LoansTitle") as Label, UITheme.BTN_GOLD, 7, 5.0, UITheme.TYPE_SUBHEAD)
	UITheme.style_header_banner(get_node_or_null("InvestPanel/VBoxContainer/InvestTitle") as Label, UITheme.BTN_BLUE, 7, 5.0, UITheme.TYPE_SUBHEAD)
	
	for nav_btn in [event_back_btn, close_chat_btn, close_loans_btn, close_invest_btn]:
		_style_button(nav_btn, UITheme.PAPER_CREAM, 8)
		UITheme.set_button_icon(nav_btn, UITheme.ICON_ARROW_LEFT, false)
		
	_style_button(send_button, UITheme.BTN_SAGE, 8)
	if chat_input:
		var in_sb := UITheme.make_card_style(Color(0.98, 0.96, 0.91, 1.0), UITheme.INK_BORDER, 8, 2, 3, 8.0)
		var foc_sb := UITheme.make_card_style(Color(1.0, 0.99, 0.95, 1.0), Color(0.18, 0.44, 0.25, 1.0), 8, 2, 3, 8.0)
		chat_input.add_theme_stylebox_override("normal", in_sb)
		chat_input.add_theme_stylebox_override("focus", foc_sb)
		chat_input.add_theme_color_override("font_color", UITheme.INK_DARK)
		chat_input.add_theme_color_override("font_placeholder_color", UITheme.INK_MUTED)
		chat_input.add_theme_color_override("caret_color", UITheme.INK_DARK)
	
	for loan_btn in [borrow_5k_btn, borrow_10k_btn]:
		_style_button(loan_btn, UITheme.BTN_GOLD, 8)
	for pay_btn in [pay_loan_inst_btn, pay_loan_full_btn]:
		_style_button(pay_btn, UITheme.BTN_SAGE, 8)
	_style_button(pay_overdue_debt_btn, UITheme.BTN_CORAL, 8)
		
	for inv_btn in [invest_low_btn, invest_high_btn]:
		_style_button(inv_btn, UITheme.BTN_BLUE, 8)
	_style_button(withdraw_cash_btn, UITheme.PAPER_KRAFT, 8)
	_style_button(transfer_savings_btn, UITheme.BTN_SAGE, 8)

func _set_active_subpanel(panel: Control) -> void:
	if event_detail_panel:
		event_detail_panel.visible = (panel == event_detail_panel)
	if chat_panel:
		chat_panel.visible = (panel == chat_panel)
	if loans_panel:
		loans_panel.visible = (panel == loans_panel)
	if invest_panel:
		invest_panel.visible = (panel == invest_panel)
	if home_scroll:
		home_scroll.visible = (panel == null)
	if panel == chat_panel:
		if _ai_last_status != "thinking":
			_ai_last_status = "idle"
		_refresh_chat_mode_indicator()

func _ensure_chat_mode_bar() -> void:
	if _chat_presence_row or not chat_panel:
		return
	var vb := chat_panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if not vb:
		return
	_chat_presence_row = HBoxContainer.new()
	_chat_presence_row.name = "ChatPresenceRow"
	_chat_presence_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_chat_presence_row.add_theme_constant_override("separation", 6)
	vb.add_child(_chat_presence_row)
	vb.move_child(_chat_presence_row, 1)
	
	_chat_dot = Panel.new()
	_chat_dot.name = "ChatStatusDot"
	_chat_dot.custom_minimum_size = Vector2(10, 10)
	_chat_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chat_presence_row.add_child(_chat_dot)
	
	_chat_status_lbl = Label.new()
	_chat_status_lbl.name = "ChatStatusLabel"
	_chat_status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_type(_chat_status_lbl, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	_chat_status_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	_chat_presence_row.add_child(_chat_status_lbl)

func _style_presence_dot(dot_color: Color) -> void:
	if not _chat_dot:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = dot_color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = UITheme.INK_BORDER
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_right = 5
	sb.corner_radius_bottom_left = 5
	_chat_dot.add_theme_stylebox_override("panel", sb)

func _read_key_from_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("OPENAI_API_KEY="):
			var val: String = line.substr("OPENAI_API_KEY=".length()).strip_edges().trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
			if val != "":
				return val
		elif line.begins_with("sk-"):
			return line.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	return ""

func _get_api_key_info() -> Dictionary:
	var env_key: String = OS.get_environment("OPENAI_API_KEY").strip_edges().trim_prefix("\"").trim_suffix("\"")
	if env_key != "":
		return {"has_key": true, "key": env_key, "source_label": "System Env"}
	for env_path in ["res://.env", "user://.env"]:
		var f_key: String = _read_key_from_file(env_path)
		if f_key != "":
			return {"has_key": true, "key": f_key, "source_label": ".env File"}
	var cfg_key: String = _read_key_from_file("user://api_config.cfg")
	if cfg_key != "":
		return {"has_key": true, "key": cfg_key, "source_label": "Config File"}
	return {"has_key": false, "key": "", "source_label": "Offline"}

func _refresh_chat_mode_indicator() -> void:
	if not _chat_status_lbl:
		return
	var info := _get_api_key_info()
	var has_key: bool = bool(info.get("has_key", false))
	if _ai_last_status == "thinking":
		_style_presence_dot(Color(0.95, 0.72, 0.22, 1.0))
		_chat_status_lbl.text = "Typing..."
		_chat_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_WARN)
	elif has_key and _ai_last_status != "offline_error":
		_style_presence_dot(Color(0.20, 0.76, 0.36, 1.0))
		_chat_status_lbl.text = "Online"
		_chat_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_SUCCESS)
	else:
		_style_presence_dot(Color(0.62, 0.58, 0.54, 1.0))
		_chat_status_lbl.text = "Offline"
		_chat_status_lbl.add_theme_color_override("font_color", UITheme.INK_MUTED)

func _on_stats_updated() -> void:
	_update_header_status()
	_refresh_loans_panel()
	_refresh_invest_panel()

func _update_header_status() -> void:
	if not header_title or is_lag_waiting:
		return
	if StatManager.phone_is_slow:
		header_title.text = "PaldoPhone  |  Slow Connection (2s Lag)"
	elif StatManager.phone_upgraded:
		header_title.text = "PaldoPhone  |  Upgraded 5G"
	else:
		header_title.text = "PaldoPhone  |  Mga Text"

func _apply_phone_lag_if_needed() -> void:
	if StatManager.phone_is_slow and StatManager.phone_lag_seconds > 0.0:
		is_lag_waiting = true
		if header_title:
			header_title.text = "Loading... (Slow Phone 2s)"
		await get_tree().create_timer(StatManager.phone_lag_seconds).timeout
		is_lag_waiting = false
		_update_header_status()

func _build_system_prompt() -> String:
	var prompt = "You are Baldo, a wise, supportive, and trustworthy Filipino friend who acts as a personal financial coach for a young breadwinner working their first job in the city.\n"
	prompt += "IMPORTANT TONE RULES:\n"
	prompt += "- ALWAYS speak in a casual, warm, relatable Gen-Z Filipino 'Taglish' tone (use slang naturally like 'omsim', 'paldo', 'petsa de peligro', 'hustle', 'dasurv', 'par', 'lods').\n"
	prompt += "- Keep responses concise (3 to 5 sentences max) and actionable.\n"
	prompt += "- CRITICAL: You have LIVE access to the player's current financial stats, cash envelopes, active notifications, and past decisions below. ALWAYS tailor your advice specifically to their exact numbers, past choices, envelope shortfalls, and current situation!\n\n"
	prompt += StatManager.get_live_summary_for_ai() + "\n"
	prompt += EventManager.get_events_context_for_ai() + "\n"
	prompt += LedgerManager.get_ledger_summary_for_ai()
	return prompt

func _load_api_key() -> String:
	return str(_get_api_key_info().get("key", ""))

func _on_event_triggered(_event_data: Dictionary) -> void:
	refresh_notifications()

func _on_event_resolved(_event_id: String) -> void:
	refresh_notifications()
	_set_active_subpanel(null)

func refresh_notifications() -> void:
	if not notifications_container:
		return
	for child in notifications_container.get_children():
		notifications_container.remove_child(child)
		child.queue_free()
		
	if EventManager.active_events.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.name = "EmptyInboxLabel"
		empty_lbl.text = "Walang bagong text message ngayon."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.custom_minimum_size = Vector2(0, 44)
		empty_lbl.add_theme_color_override("font_color", UITheme.INK_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		notifications_container.add_child(empty_lbl)
		return
		
	for event in EventManager.active_events:
		var btn := Button.new()
		btn.text = str(event["title"])
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 56)
		UITheme.apply_type(btn, UITheme.TYPE_BODY, UITheme.FONT_UI)
		_style_button(btn, UITheme.PAPER_KRAFT, 8)
		btn.pressed.connect(func(): _on_notification_clicked(event))
		notifications_container.add_child(btn)

func _on_notification_clicked(event: Dictionary) -> void:
	if is_lag_waiting:
		return
	AudioManager.play_sfx("click")
	await _apply_phone_lag_if_needed()
	open_event_detail(event)

func _ensure_phone_event_category_header() -> void:
	if _phone_art_frame or not event_title:
		return
	var vb := event_title.get_parent() as VBoxContainer
	if not vb:
		return
	_phone_art_frame = PanelContainer.new()
	_phone_art_frame.name = "PhoneEventArtFrame"
	_phone_art_frame.clip_contents = true
	_phone_art_frame.custom_minimum_size = Vector2(0, 124)
	_phone_art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phone_art_frame.add_theme_stylebox_override("panel", UITheme.make_card_style(Color(0.953, 0.898, 0.855, 1.0), UITheme.INK_BORDER, 8, 2, 3, 4.0, 4.0))
	vb.add_child(_phone_art_frame)
	vb.move_child(_phone_art_frame, event_title.get_index() + 1)

	var art_wrap := Control.new()
	art_wrap.name = "PhoneArtWrapper"
	art_wrap.clip_contents = true
	art_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phone_art_frame.add_child(art_wrap)

	_phone_art_texture = TextureRect.new()
	_phone_art_texture.name = "PhoneEventArtTexture"
	_phone_art_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone_art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_phone_art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_phone_art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_wrap.add_child(_phone_art_texture)

	_phone_cat_chip = PanelContainer.new()
	_phone_cat_chip.name = "PhoneCategoryChip"
	_phone_cat_chip.offset_left = 6.0
	_phone_cat_chip.offset_top = 6.0
	_phone_cat_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_cat_chip.add_theme_stylebox_override("panel", UITheme.make_tactile_btn_style(UITheme.PAPER_KRAFT, UITheme.INK_BORDER, 5, 2, 9.0, 2.5))
	art_wrap.add_child(_phone_cat_chip)

	_phone_cat_pill = Label.new()
	_phone_cat_pill.name = "PhoneCatPill"
	_phone_cat_pill.text = "Gastos at Routine"
	UITheme.apply_type(_phone_cat_pill, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
	_phone_cat_pill.add_theme_color_override("font_color", UITheme.INK_DARK)
	_phone_cat_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_cat_chip.add_child(_phone_cat_pill)

func open_event_detail(event: Dictionary) -> void:
	current_viewing_event_id = str(event["id"])
	var meta: Dictionary = EventManager.get_event_category_meta(event)
	var cat_col: Color = meta.get("color", UITheme.BTN_GOLD)
	UITheme.style_header_banner(event_title, cat_col, 7, 5.0, UITheme.TYPE_SUBHEAD)
	if _phone_cat_pill:
		_phone_cat_pill.text = str(meta.get("label", "Message"))
	if _phone_cat_chip:
		_phone_cat_chip.add_theme_stylebox_override("panel", UITheme.make_tactile_btn_style(cat_col.lightened(0.28), UITheme.INK_BORDER, 5, 2, 9.0, 2.5))
	var ev_tex: Texture2D = EventManager.get_event_texture(current_viewing_event_id)
	if _phone_art_frame and _phone_art_texture:
		_phone_art_texture.texture = ev_tex
		_phone_art_texture.visible = (ev_tex != null)
		_phone_art_frame.custom_minimum_size = Vector2(0, 124) if ev_tex != null else Vector2(0, 38)
		if ev_tex != null:
			if _phone_art_tween and _phone_art_tween.is_valid():
				_phone_art_tween.kill()
			_phone_art_texture.pivot_offset = _phone_art_texture.size * 0.5
			_phone_art_texture.scale = Vector2(0.985, 0.985)
			_phone_art_texture.modulate.a = 0.0
			_phone_art_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_phone_art_tween.tween_property(_phone_art_texture, "scale", Vector2.ONE, 0.16)
			_phone_art_tween.tween_property(_phone_art_texture, "modulate:a", 1.0, 0.15)
	event_title.text = str(event["title"])
	event_desc.text = str(event["description"])
	
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
		
	var i = 0
	for option in event["options"]:
		var btn := Button.new()
		var choice_text := str(option["choice_text"])
		var can_select := EventManager.is_option_selectable(option)
		btn.custom_minimum_size = Vector2(0, 72)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not can_select
		_style_button(btn, UITheme.PAPER_CREAM, 8)
		
		var rtf := RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.fit_content = true
		rtf.scroll_active = false
		rtf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtf.add_theme_color_override("default_color", UITheme.INK_DARK)
		rtf.add_theme_font_override("normal_font", UITheme.FONT_BODY)
		rtf.add_theme_font_override("bold_font", UITheme.FONT_BOLD)
		rtf.add_theme_font_size_override("normal_font_size", UITheme.TYPE_BODY)
		rtf.add_theme_font_size_override("bold_font_size", UITheme.TYPE_BODY)
		rtf.set_anchors_preset(Control.PRESET_FULL_RECT)
		rtf.offset_left = 10.0
		rtf.offset_top = 8.0
		rtf.offset_right = -10.0
		rtf.offset_bottom = -8.0
		
		var stats_text := EventManager.format_option_Preview_bbcode(option)
		rtf.text = "[center][b]" + choice_text + "[/b]\n[font_size=14]" + stats_text + "[/font_size][/center]"
		btn.add_child(rtf)
		btn.pressed.connect(func(idx = i): resolve_current_event(idx))
		options_container.add_child(btn)
		i += 1
		
	_set_active_subpanel(event_detail_panel)

func resolve_current_event(option_index: int) -> void:
	if current_viewing_event_id != "":
		EventManager.resolve_event(current_viewing_event_id, option_index)

func _on_event_back_button_pressed() -> void:
	AudioManager.play_sfx("click")
	_set_active_subpanel(null)

func _on_baldo_button_pressed() -> void:
	if is_lag_waiting:
		return
	AudioManager.play_sfx("click")
	await _apply_phone_lag_if_needed()
	_set_active_subpanel(chat_panel)

func open_baldo_chat_direct() -> void:
	_set_active_subpanel(chat_panel)

func open_loans_direct() -> void:
	_refresh_loans_panel()
	_set_active_subpanel(loans_panel)

func open_first_unread_direct() -> void:
	if not EventManager.active_events.is_empty():
		open_event_detail(EventManager.active_events[0])
	else:
		_set_active_subpanel(null)

func _wire_quick_ask_buttons() -> void:
	var quick_pairs := [
		[quick_budget_btn, "Budget check: kumusta mga envelopes at bills ko?"],
		[quick_savings_btn, "Ipon at tubo: paano lumalago ang savings at investments ko?"],
		[quick_debt_btn, "Utang at credit: ano status ng credit score at utang ko?"],
		[quick_goal_btn, "Kaya pa goal? Magkano kailangan kong ipunin bawat buwan?"]
	]
	for qp in quick_pairs:
		var qbtn: Button = qp[0]
		var prompt_txt: String = str(qp[1])
		if qbtn:
			UITheme.apply_type(qbtn, UITheme.TYPE_CAPTION, UITheme.FONT_UI)
			UITheme.style_Button(qbtn, UITheme.PAPER_KRAFT, 6, 3, 8.0, 4.0)
			qbtn.pressed.connect(func():
				if is_request_pending:
					return
				AudioManager.play_sfx("chat_pop")
				add_chat_bubble("You", prompt_txt)
				chat_messages.append({"role": "user", "content": prompt_txt})
				send_ai_request(prompt_txt)
			)

func _on_close_chat_button_pressed() -> void:
	AudioManager.play_sfx("click")
	_set_active_subpanel(null)

func _on_loans_app_button_pressed() -> void:
	if is_lag_waiting:
		return
	AudioManager.play_sfx("toggle")
	await _apply_phone_lag_if_needed()
	_refresh_loans_panel()
	_set_active_subpanel(loans_panel)

func _on_close_loans_button_pressed() -> void:
	AudioManager.play_sfx("click")
	_set_active_subpanel(null)

func _on_invest_app_button_pressed() -> void:
	if is_lag_waiting:
		return
	AudioManager.play_sfx("toggle")
	await _apply_phone_lag_if_needed()
	_refresh_invest_panel()
	_set_active_subpanel(invest_panel)

func _on_close_invest_button_pressed() -> void:
	AudioManager.play_sfx("click")
	_set_active_subpanel(null)

func _refresh_loans_panel() -> void:
	if not loans_info_label:
		return
	var rate := StatManager.get_personal_loan_monthly_rate()
	var rate_pct := int(round(rate * 100.0))
	var can_borrow := StatManager.can_take_formal_loan()
	
	# 5k 2-month Simple Interest calculation (I = P * r * t)
	var int_5k := StatManager.calculate_simple_interest(5000, rate, 2)
	var tot_5k := 5000 + int_5k
	var mo_5k := int(ceil(float(tot_5k) / 2.0))
	var mat_5k := str(StatManager.year[(StatManager.current_month + 2) % StatManager.year.size()].month)
	
	# 10k 3-month Simple Interest calculation (I = P * r * t)
	var int_10k := StatManager.calculate_simple_interest(10000, rate, 3)
	var tot_10k := 10000 + int_10k
	var mo_10k := int(ceil(float(tot_10k) / 3.0))
	var mat_10k := str(StatManager.year[(StatManager.current_month + 3) % StatManager.year.size()].month)
	
	var txt := "[b]Credit Score:[/b] " + str(StatManager.credit_score) + "/100  •  [b]Cash:[/b] ₱" + UITheme.format_num(StatManager.current_balance) + "\n"
	txt += "[b]Simple Interest (I = P × r × t):[/b] Rate = [color=#94520d]" + str(rate_pct) + "%/mo[/color]\n\n"
	txt += "[b]1. QuickCash Loan:[/b] ₱5,000 • 2 Mos • Interest: ₱" + UITheme.format_num(int_5k) + " • Total: ₱" + UITheme.format_num(tot_5k) + " (₱" + UITheme.format_num(mo_5k) + "/mo) • Due " + mat_5k + "\n"
	txt += "[b]2. FlexiLoan:[/b] ₱10,000 • 3 Mos • Interest: ₱" + UITheme.format_num(int_10k) + " • Total: ₱" + UITheme.format_num(tot_10k) + " (₱" + UITheme.format_num(mo_10k) + "/mo) • Due " + mat_10k + "\n\n"
	txt += "[b]Active Loans (" + str(StatManager.active_loans.size()) + "):[/b] " + StatManager.get_loans_summary_text() + "\n"
	txt += "[b]Overdue Debt (5% Penalty/mo):[/b] [color=#a8261f]₱" + UITheme.format_num(StatManager.debt_balance) + "[/color]"
	loans_info_label.text = txt
	
	if borrow_5k_btn:
		borrow_5k_btn.text = "Hiram ₱5,000 (Repay ₱" + UITheme.format_num(tot_5k) + ", ₱" + UITheme.format_num(mo_5k) + "/mo)" if StatManager.credit_score >= 55 else "Locked (Need Credit Score >= 55)"
		borrow_5k_btn.disabled = not can_borrow
	if borrow_10k_btn:
		borrow_10k_btn.text = "Hiram ₱10,000 (Repay ₱" + UITheme.format_num(tot_10k) + ", ₱" + UITheme.format_num(mo_10k) + "/mo)" if StatManager.credit_score >= 55 else "Locked (Need Credit Score >= 55)"
		borrow_10k_btn.disabled = not can_borrow
		
	if StatManager.active_loans.size() > 0:
		var first_loan: Dictionary = StatManager.active_loans[0]
		var rem: int = int(first_loan.get("remaining_balance", 0))
		var due: int = min(rem, int(first_loan.get("monthly_payment", rem)))
		if pay_loan_inst_btn:
			pay_loan_inst_btn.text = "Bayaran Monthly Due: " + str(first_loan["name"]) + " (-₱" + UITheme.format_num(due) + ")"
			pay_loan_inst_btn.disabled = (StatManager.current_balance < due or due <= 0)
		if pay_loan_full_btn:
			pay_loan_full_btn.text = "Bayaran Buo: " + str(first_loan["name"]) + " (-₱" + UITheme.format_num(rem) + ", +2 CS)"
			pay_loan_full_btn.disabled = (StatManager.current_balance < rem or rem <= 0)
	else:
		if pay_loan_inst_btn:
			pay_loan_inst_btn.text = "Walang Active Loan Monthly Due"
			pay_loan_inst_btn.disabled = true
		if pay_loan_full_btn:
			pay_loan_full_btn.text = "Walang Active Loan na Babayaran"
			pay_loan_full_btn.disabled = true
			
	if pay_overdue_debt_btn:
		if StatManager.debt_balance > 0:
			var pay_amt: int = min(StatManager.current_balance, StatManager.debt_balance)
			pay_overdue_debt_btn.text = "Bayaran Overdue Debt (-₱" + UITheme.format_num(pay_amt) + " / ₱" + UITheme.format_num(StatManager.debt_balance) + ")"
			pay_overdue_debt_btn.disabled = (pay_amt <= 0)
		else:
			pay_overdue_debt_btn.text = "Walang Overdue Debt (₱0)"
			pay_overdue_debt_btn.disabled = true

func _on_borrow_5k_pressed() -> void:
	if not StatManager.can_take_formal_loan():
		return
	AudioManager.play_sfx("bill_due")
	var rate := StatManager.get_personal_loan_monthly_rate()
	var ln := StatManager.take_simple_interest_loan("quickcash_5k", "QuickCash 5k Loan", 5000, rate, 2)
	PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Borrowed QuickCash Loan (+₱5,000 Cash, Repay ₱" + UITheme.format_num(int(ln["total_repayment"])) + ")")
	_refresh_loans_panel()

func _on_borrow_10k_pressed() -> void:
	if not StatManager.can_take_formal_loan():
		return
	AudioManager.play_sfx("bill_due")
	var rate := StatManager.get_personal_loan_monthly_rate()
	var ln := StatManager.take_simple_interest_loan("flexiloan_10k", "FlexiLoan 10k", 10000, rate, 3)
	PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Borrowed FlexiLoan (+₱10,000 Cash, Repay ₱" + UITheme.format_num(int(ln["total_repayment"])) + ")")
	_refresh_loans_panel()

func _on_pay_loan_installment_pressed() -> void:
	if StatManager.active_loans.is_empty():
		return
	var first_loan: Dictionary = StatManager.active_loans[0]
	var due: int = min(int(first_loan.get("remaining_balance", 0)), int(first_loan.get("monthly_payment", 0)))
	var paid := StatManager.pay_active_loan(0, due)
	if paid > 0:
		AudioManager.play_sfx("spend")
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Paid Loan Installment (-₱" + UITheme.format_num(paid) + ")")
	_refresh_loans_panel()

func _on_pay_loan_full_pressed() -> void:
	if StatManager.active_loans.is_empty():
		return
	var first_loan: Dictionary = StatManager.active_loans[0]
	var rem: int = int(first_loan.get("remaining_balance", 0))
	var paid := StatManager.pay_active_loan(0, rem)
	if paid > 0:
		AudioManager.play_sfx("stat_up")
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Paid Full Loan Balance (-₱" + UITheme.format_num(paid) + ", +2 Credit Score)")
	_refresh_loans_panel()

func _on_pay_overdue_debt_pressed() -> void:
	var paid := StatManager.pay_overdue_debt(StatManager.debt_balance)
	if paid > 0:
		AudioManager.play_sfx("stat_up")
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Paid Overdue Debt (-₱" + UITheme.format_num(paid) + ")")
	_refresh_loans_panel()

func _refresh_invest_panel() -> void:
	if not invest_info_label:
		return
	var total_inv := StatManager.get_total_investments()
	var pnl := StatManager.total_investment_gains
	var pnl_sign := "+" if pnl >= 0 else "-"
	var pnl_color := "#1c7033" if pnl >= 0 else "#a8261f"
	var mood: Dictionary = StatManager.get_current_market_mood()
	
	var txt := "[b]Market Mood:[/b] [color=" + str(mood.get("hex", "#1a4b7c")) + "][b]" + str(mood.get("label", "Steady")) + "[/b][/color] — " + str(mood.get("hint", "")) + "\n"
	txt += "[b]Available Cash:[/b] [color=#1c7033]₱" + UITheme.format_num(StatManager.current_balance) + "[/color]  •  [b]Ipon:[/b] [color=#1a4b7c]₱" + UITheme.format_num(StatManager.savings) + "[/color]\n\n"
	txt += "[b]1. Low-Risk Mutual Fund (+1.5% to +2.5%/mo):[/b]\n   Current Value: [color=#1a4b7c]₱" + UITheme.format_num(StatManager.low_risk_investment) + "[/color]\n"
	txt += "[b]2. High-Risk Stock Market (-12% to +22%):[/b]\n   Current Value: [color=#94520d]₱" + UITheme.format_num(StatManager.high_risk_investment) + "[/color]\n\n"
	txt += "[b]Total Portfolio Value:[/b] ₱" + UITheme.format_num(total_inv) + "  •  [b]Net P&L:[/b] [color=" + pnl_color + "]" + pnl_sign + "₱" + UITheme.format_num(abs(pnl)) + "[/color]\n"
	txt += "[b]Side Hustle Status:[/b] " + ("[color=#1c7033]Active (+₱5,000/mo)[/color]" if StatManager.has_side_income else "Inactive")
	invest_info_label.text = txt
	
	if invest_low_btn:
		invest_low_btn.disabled = (StatManager.current_balance < 3000)
	if invest_high_btn:
		invest_high_btn.disabled = (StatManager.current_balance < 3000)
	if withdraw_cash_btn:
		withdraw_cash_btn.text = "Withdraw Investments to Cash (+₱" + UITheme.format_num(total_inv) + ")"
		withdraw_cash_btn.disabled = (total_inv <= 0)
	if transfer_savings_btn:
		transfer_savings_btn.text = "Transfer Investments to Ipon (+₱" + UITheme.format_num(total_inv) + ")"
		transfer_savings_btn.disabled = (total_inv <= 0)

func _on_invest_low_risk_pressed() -> void:
	if StatManager.invest_low_risk(3000):
		AudioManager.play_sfx("spend")
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Invested ₱3,000 in Low-Risk Mutual Fund")
		_refresh_invest_panel()

func _on_invest_high_risk_pressed() -> void:
	if StatManager.invest_high_risk(3000):
		AudioManager.play_sfx("spend")
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Invested ₱3,000 in High-Risk Stock")
		_refresh_invest_panel()

func _on_withdraw_cash_pressed() -> void:
	var amt := StatManager.withdraw_investments_to_cash()
	if amt > 0:
		AudioManager.play_sfx("cash_register")
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Withdrew Investments to Cash (+₱" + UITheme.format_num(amt) + ")")
		_refresh_invest_panel()

func _on_transfer_savings_pressed() -> void:
	var amt := StatManager.withdraw_investments_to_savings()
	if amt > 0:
		AudioManager.play_sfx("coin")
		PlannerManager.record_event(StatManager.current_month, StatManager.current_day, "Transferred Investments to Ipon (+₱" + UITheme.format_num(amt) + ")")
		_refresh_invest_panel()

func _on_chat_input_submitted(_submitted_text: String) -> void:
	_on_send_chat_button_pressed()

func _on_send_chat_button_pressed() -> void:
	if is_request_pending:
		return
	var text = chat_input.text.strip_edges()
	if text == "":
		return
		
	AudioManager.play_sfx("chat_pop")
	chat_input.text = ""
	add_chat_bubble("You", text)
	
	chat_messages.append({
		"role": "user",
		"content": text
	})
	
	send_ai_request(text)

func add_chat_bubble(sender: String, text: String) -> void:
	var color = "#211c1a"
	if sender == "Baldo":
		color = "#1c7033"
	elif sender == "System":
		color = "#5c4f45"
		
	if chat_history.text != "":
		chat_history.text += "\n\n"
	chat_history.text += "[b][color=" + color + "]" + sender + ":[/color][/b] " + text

func send_ai_request(latest_user_text: String = "") -> void:
	# Always refresh the system prompt at index 0 with the latest live StatManager & EventManager context
	if chat_messages.size() > 0:
		chat_messages[0] = {
			"role": "system",
			"content": _build_system_prompt()
		}
	
	# Keep system prompt + last 10 messages to stay well within token limits
	while chat_messages.size() > 11:
		chat_messages.remove_at(1)

	var api_key = _load_api_key()
	if api_key == "":
		_ai_last_status = "offline_no_key"
		_refresh_chat_mode_indicator()
		var reply = _generate_offline_baldo_reply(latest_user_text)
		add_chat_bubble("Baldo", reply)
		AudioManager.play_sfx_pitched("chat_pop", 1.12)
		chat_messages.append({"role": "assistant", "content": reply})
		return
		
	var url = "https://api.openai.com/v1/chat/completions"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var body = {
		"model": "gpt-4o-mini",
		"messages": chat_messages,
		"max_tokens": 250
	}
	
	is_request_pending = true
	_ai_last_status = "thinking"
	_refresh_chat_mode_indicator()
	if send_button:
		send_button.disabled = true
		
	var error = ai_http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		is_request_pending = false
		_ai_last_status = "offline_error"
		_refresh_chat_mode_indicator()
		if send_button:
			send_button.disabled = false
		var fallback = _generate_offline_baldo_reply(latest_user_text)
		add_chat_bubble("Baldo", fallback)
		AudioManager.play_sfx_pitched("chat_pop", 1.12)
		chat_messages.append({"role": "assistant", "content": fallback})

func _on_ai_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_request_pending = false
	if send_button:
		send_button.disabled = false
		
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response = json.get_data()
			if response is Dictionary and response.has("choices") and response["choices"].size() > 0:
				_ai_last_status = "online"
				_refresh_chat_mode_indicator()
				var reply = response["choices"][0]["message"]["content"]
				add_chat_bubble("Baldo", reply)
				AudioManager.play_sfx_pitched("chat_pop", 1.12)
				chat_messages.append({
					"role": "assistant",
					"content": reply
				})
				return
				
	# If API call fails (offline, rate limit, or key issue), surface Offline status cleanly and use local coaching
	_ai_last_status = "offline_error"
	_refresh_chat_mode_indicator()
	var last_user_msg = ""
	for i in range(chat_messages.size() - 1, -1, -1):
		if chat_messages[i].get("role") == "user":
			last_user_msg = str(chat_messages[i].get("content", ""))
			break
	var fallback_reply = _generate_offline_baldo_reply(last_user_msg)
	add_chat_bubble("Baldo", fallback_reply)
	AudioManager.play_sfx_pitched("chat_pop", 1.12)
	chat_messages.append({"role": "assistant", "content": fallback_reply})

func _tokenize_query(text: String) -> PackedStringArray:
	var re := RegEx.new()
	re.compile("[a-z0-9]+")
	var tokens: PackedStringArray = []
	for m in re.search_all(text.to_lower()):
		tokens.append(m.get_string())
	return tokens

func _has_any_word(tokens: PackedStringArray, words: Array) -> bool:
	for w in words:
		if str(w) in tokens:
			return true
	return false

func _pick_non_repeating(candidates: Array[String]) -> String:
	if candidates.is_empty():
		return ""
	var start_idx := _offline_turn_counter % candidates.size()
	var chosen := candidates[start_idx]
	if chosen == _last_offline_reply and candidates.size() > 1:
		chosen = candidates[(start_idx + 1) % candidates.size()]
	_offline_turn_counter += 1
	_last_offline_reply = chosen
	return chosen

func _generate_offline_baldo_reply(user_text: String) -> String:
	var q: String = user_text.to_lower()
	var tokens: PackedStringArray = _tokenize_query(q)
	var rent_env := StatManager.get_envelope_amount("Rent")
	var util_env := StatManager.get_envelope_amount("Utilities")
	var total_util_due := StatManager.monthly_utilities + StatManager.extra_utilities_this_month + StatManager.get_total_monthly_installments() + StatManager.monthly_family_support
	var rent_short: int = max(0, StatManager.monthly_rent - rent_env)
	var util_short: int = max(0, total_util_due - util_env)
	var total_short: int = rent_short + util_short
	var food_days: int = int(StatManager.get_envelope_amount("Food") / max(1, StatManager.get_daily_food_cost()))
	var trans_days: int = int(StatManager.get_envelope_amount("Transportation") / max(1, StatManager.get_daily_commute_cost()))
	var goal := StatManager.get_current_goal()
	var goal_target: int = StatManager.get_goal_target()
	var rem_goal: int = max(0, goal_target - StatManager.savings)
	var months_left: int = max(1, 12 - StatManager.current_month)
	var needed_per_mo: int = int(ceil(float(rem_goal) / float(months_left)))
	var next_sav_interest: int = int(round(float(StatManager.savings) * StatManager.savings_monthly_interest_rate))
	var tot_debt: int = StatManager.get_total_debt_and_loans() + StatManager.credit_balance
	var mood: Dictionary = StatManager.get_current_market_mood()
	var mission: Dictionary = StatManager.get_active_monthly_mission()
	var stage_info: Dictionary = StatManager.get_stage_info()
	
	# 1. Unread notifications / inbox
	if _has_any_word(tokens, ["notif", "notifications", "notification", "inbox", "unread", "message", "messages", "text"]):
		if EventManager.active_events.size() > 0:
			var titles: Array[String] = []
			for ev in EventManager.active_events:
				titles.append("\"" + str(ev.get("title", "Text")) + "\"")
			return _pick_non_repeating([
				"May " + str(EventManager.active_events.size()) + " unread message ka sa PaldoPhone Inbox: " + ", ".join(titles) + ". Buksan muna ito bago matapos ang araw!",
				"Check mo muna ang Inbox par — naghihintay ng reply ang " + ", ".join(titles) + "."
			])
		return _pick_non_repeating([
			"Malinis ang PaldoPhone Inbox mo ngayon — walang pending notifications! Pwede ka nang mag-plan ng budget o mag-Susunod.",
			"Zero unread texts ngayon par. Solid!"
		])
		
	# 2. Goal Pace & Victory Conditions
	if _has_any_word(tokens, ["goal", "kaya", "target", "pangarap", "manalo", "win", "ending", "graduation", "negosyo", "bahay"]):
		if rem_goal == 0:
			return _pick_non_repeating([
				"Panalo par! Naabot mo na ang 100% (₱" + UITheme.format_num(StatManager.savings) + ") para sa \"" + str(goal["title"]) + "\"! Siguraduhin lang na >= 50 ang Happy/Social, >= 70 ang Credit Score, at ₱0 ang utang bago mag-December 31.",
				"100% funded na ang \"" + str(goal["title"]) + "\" mo! Bantayan na lang ang Credit Score (" + str(StatManager.credit_score) + "/100) at zero debt para makuha ang Tunay na Paldo ending."
			])
		var pace_note := "Kaya pa!" if needed_per_mo <= 4500 else "Medyo mahigpit kaya gamitin ang Smart Split tuwing sahod at iwasan ang unnecessary gastos."
		return "Para sa \"" + str(goal["title"]) + "\", may ₱" + UITheme.format_num(rem_goal) + " ka pang kulang sa natitirang " + str(months_left) + " buwan (~₱" + UITheme.format_num(needed_per_mo) + "/buwan). " + pace_note + " Dagdag tulong din ang 0.5%/buwan (6%/yr) Digital Bank interest (+₱" + UITheme.format_num(next_sav_interest) + " ngayong buwan)."
		
	# 3. Savings, Interest & Investments
	if _has_any_word(tokens, ["ipon", "save", "savings", "tubo", "interest", "invest", "investments", "stock", "stocks", "mutual", "fund", "market", "portfolio"]):
		var tot_inv := StatManager.get_total_investments()
		return "Sa Digital Bank Ipon (₱" + UITheme.format_num(StatManager.savings) + "), kikita ka ng 0.5%/buwan (6%/yr) compounding (~+₱" + UITheme.format_num(next_sav_interest) + "). Sa Invest App ngayon, ang Market Mood ay " + str(mood.get("label", "Steady")) + ": steady ang Low-Risk (+1.5% to +2.5%/mo) habang maalon ang High-Risk Stocks (-12% to +22%). Portfolio mo: ₱" + UITheme.format_num(tot_inv) + "."
		
	# 4. Debt, Loans & Credit Standing
	if _has_any_word(tokens, ["utang", "loan", "loans", "hiram", "credit", "score", "card", "penalty", "overdue"]) or ("5-6" in q):
		if tot_debt > 0:
			return "May ₱" + UITheme.format_num(tot_debt) + " kang total obligations (Credit Score: " + str(StatManager.credit_score) + "/100, need 70+ sa year-end). Tandaan: ang hindi nabayarang Credit Card ay nagkaka-3%/buwan interest (5%/mo naman kapag Overdue Debt), kaya unahin itong bayaran!"
		return "Malinis ang rekord mo par! ₱0 ang Utang at Credit balance mo ngayon (Credit Score: " + str(StatManager.credit_score) + "/100). Panatilihing 100% funded ang Upa at Bills envelopes para sa automatic +2 Credit Score bonus bawat buwan!"
		
	# 5. Budget, Envelopes & Bills
	if _has_any_word(tokens, ["budget", "envelope", "envelopes", "sahod", "bills", "bill", "upa", "rent", "kuryente", "tubig", "pagkain", "food", "byahe", "commute", "split", "tipid"]):
		if _has_any_word(tokens, ["sahod", "sweldo", "payday", "trabaho", "work", "job", "layoff", "sideline", "hustle", "raket", "13th"]) and not _has_any_word(tokens, ["budget", "envelope", "bills", "upa", "split"]):
			pass
		else:
			if total_short > 0:
				return "Kulang pa ng ₱" + UITheme.format_num(total_short) + " ang Upa at Bills envelopes mo (Upa kulang: ₱" + UITheme.format_num(rent_short) + ", Bills kulang: ₱" + UITheme.format_num(util_short) + "). Runway ngayon: " + str(food_days) + " araw sa Pagkain at " + str(trans_days) + " araw sa Byahe. I-click ang Smart Split sa Cash Envelopes para sakto!"
			return "Kumpleto na ang pondo ng Upa at Bills mo para sa buwang ito! Runway: " + str(food_days) + " araw Pagkain, " + str(trans_days) + " araw Byahe (Hawak na Cash: ₱" + UITheme.format_num(StatManager.current_balance) + "). Monthly Mission: \"" + str(mission.get("title", "")) + "\" (" + str(mission.get("pct", 0)) + "%)."
			
	# 6. Salary, Job, Layoff, Side Hustle & 13th Month
	if _has_any_word(tokens, ["sahod", "sweldo", "payday", "trabaho", "work", "job", "layoff", "sideline", "hustle", "raket", "13th"]):
		var next_pay_day: String = "Day 15" if StatManager.current_day < 15 else "Day 1 ng susunod na buwan"
		var emp_note := "May regular work ka ngayon — dumarating ang sahod tuwing Day 1 at Day 15 (susunod: " + next_pay_day + ")."
		if StatManager.employment_status == "laid_off":
			emp_note = "Naka-Laid Off status tayo ngayon (₱0 work commute), kaya alagaan ang Cash at Emergency Fund habang naghahanap ng Temp o New Stable Job."
		elif StatManager.employment_status == "temporary_job":
			emp_note = "May Temporary Job (₱15,000/buwan) ka ngayon — sakto muna habang naghihintay ng mas mataas na offer."
		elif StatManager.employment_status == "new_stable_job":
			emp_note = "Solid yang New Stable Job (₱30,000/buwan) — bilisan ang pag-ipon at i-clear ang natitirang obligations."
		return _pick_non_repeating([
			"Employment Status: " + StatManager.get_employment_display_text() + ". " + emp_note + (" Active din ang +₱5,000/mo Side Hustle mo!" if StatManager.has_side_income else ""),
			"Sa trabaho mo ngayon (" + StatManager.get_employment_display_text() + "), laking tulong ng Smart Split tuwing payday para diretso ang Upa, Bills, at 13th Month bonus pag-Dec 15!"
		])
		
	# 7. Well-Being, Burnout & Weekend
	if _has_any_word(tokens, ["happy", "happiness", "social", "stress", "burnout", "pagod", "weekend", "pahinga", "barkada", "pamilya"]):
		return _pick_non_repeating([
			"Happiness: " + str(StatManager.happy) + "/100 | Social: " + str(StatManager.social) + "/100. Huwag hayaang bumagsak sa 0 nang 5 araw dahil Game Over 'yon! Kung mababa na, mag-Mototaxi o Mag-order muna, o mag-Barkada/Pamilya bonding sa Weekend.",
			"Alagaan ang energy par! Nasa " + str(StatManager.happy) + " Happy at " + str(StatManager.social) + " Social ka. Magtabi ng kahit ₱400–₱600 sa Libangan envelope pang-Weekend bonding!"
		])
		
	# 8. Grades, Report Card, Missions & Ledger
	if _has_any_word(tokens, ["grade", "grades", "marka", "report", "mission", "missions", "badge", "badges", "achievement", "ledger", "status"]):
		return _pick_non_repeating([
			"Average Grade mo: " + StatManager.get_average_grade_text() + ". Active Mission ngayong buwan: \"" + str(mission.get("title", "")) + "\" (" + str(mission.get("pct", 0)) + "% — " + str(mission.get("desc", "")) + ").",
			"Para sa Grade S ngayong buwan: Auto-Paid Upa & Bills, +₱2,000+ sa Ipon, ₱0 Overdue Debt, at Happy/Social 55+ / Credit 70+. Buksan ang Status Laptop para makita ang buong Report Card!"
		])
		
	# 9. Thanks / Appreciation (before greetings so "salamat baldo" replies warmly instead of greeting)
	if _has_any_word(tokens, ["salamat", "thanks", "thank", "ty", "galing", "nice", "astig", "omsim", "bait"]):
		return _pick_non_repeating([
			"Walang anuman par! Kakampi mo ako hanggang December 31 para maging Tunay na Paldo tayo!",
			"Anytime lods! Omsim, basta disiplina sa Envelopes at iwas utang, sure win tayo.",
			"Dasurv ang suporta par! Balik ka lang dito kung may bagong text o emergency."
		])
		
	# 10. Help / What should I do next?
	if _has_any_word(tokens, ["tulong", "help", "paano", "tips", "tip", "payo", "advice", "gagawin", "next"]):
		var steps: Array[String] = []
		if EventManager.active_events.size() > 0:
			steps.append("1) Basahin ang " + str(EventManager.active_events.size()) + " unread text sa Inbox")
		if total_short > 0:
			steps.append("2) Punan ang ₱" + UITheme.format_num(total_short) + " kulang sa Upa at Bills Envelopes")
		elif StatManager.get_envelope_amount("Food") == 0:
			steps.append("2) Lagyan ang Pagkain Envelope para di mabawasan ang Cash")
		else:
			steps.append("2) Tapusin ang Mission: \"" + str(mission.get("title", "")) + "\" (" + str(mission.get("pct", 0)) + "%)")
		if tot_debt > 0:
			steps.append("3) Magbawas sa ₱" + UITheme.format_num(tot_debt) + " utang para iwas interest")
		else:
			steps.append("3) Maghulog ng extra sa Ipon (₱" + UITheme.format_num(StatManager.savings) + " / ₱" + UITheme.format_num(goal_target) + ")")
		return "Ito ang pinaka-ideal na next moves mo ngayon: " + "  |  ".join(steps) + "."
		
	# 11. Conversational Check-ins ("ayos ka lang?", "kumusta?")
	if _has_any_word(tokens, ["ayos", "musta", "kumusta", "kamusta", "okay", "ok", "buhay", "tulog"]):
		return _pick_non_repeating([
			"Ayos na ayos naman ako par, laging gising at nakabantay sa budget mo! Ikaw, nasa " + str(StatManager.happy) + "/100 ang Happiness at ₱" + UITheme.format_num(StatManager.current_balance) + " ang Cash mo — may gusto ka bang i-check?",
			"Goods lang lods! Ready akong mag-compute ng bills, ipon pace, o credit tips anytime. Ano ang pinagkakaabalahan natin ngayon sa " + str(stage_info.get("name", "Stage")) + "?",
			"Palaban pa rin par! Tuloy-tuloy lang tayo — may ₱" + UITheme.format_num(StatManager.savings) + " ka na sa Bangko para sa \"" + str(goal["title"]) + "\"."
		])
		
	# 12. Casual Greetings ("hi baldo", "hello", "yo")
	if _has_any_word(tokens, ["hi", "hello", "hey", "yo", "yow", "uy", "oi", "morning", "afternoon", "evening", "magandang", "baldo", "bro", "par", "lods"]):
		return _pick_non_repeating([
			"Yow par! Kumusta? Nasa ₱" + UITheme.format_num(StatManager.current_balance) + " ang Cash mo at " + str(StatManager.get_goal_progress_percent()) + "% ka na sa goal mo. Pindutin ang quick topic buttons sa ibaba o magtanong kahit ano!",
			"Uy hello lods! Si Baldo 'to. Kung naguguluhan ka sa Upa/Bills (" + ("may kulang ₱" + UITheme.format_num(total_short) if total_short > 0 else "kumpleto na!") + ") o gusto mo mag-invest check, sabihin mo lang.",
			"Kamusta breadwinner! Ready na ba mag-budget o mag-check ng " + str(mission.get("title", "Monthly Mission")) + "? Tanong ka lang!"
		])
		
	# 13. Non-repeating multi-angle live-state fallback for unrecognized/random prompts
	var general_replies: Array[String] = []
	if EventManager.active_events.size() > 0:
		var active_ev = EventManager.active_events[0]
		general_replies.append("Heads up par: may unread text ka pa tungkol sa \"" + str(active_ev["title"]) + "\" sa PaldoPhone Inbox! Sagutin muna 'yon bago mag-evening rollover.")
	if total_short > 0:
		general_replies.append("Budget Alert: kulang pa ng ₱" + UITheme.format_num(total_short) + " ang Upa at Bills envelopes mo (Cash on hand: ₱" + UITheme.format_num(StatManager.current_balance) + "). Pwedeng gamitin ang Smart Split o Fill Target sa Cash Envelopes!")
	else:
		general_replies.append("Goods ang Bills Envelopes mo ngayon! Food runway: " + str(food_days) + " araw | Byahe runway: " + str(trans_days) + " araw. Subukan mong magtanong tungkol sa 'budget', 'ipon', 'utang', o 'goal'.")
	general_replies.append("Mission Tracker: \"" + str(mission.get("title", "")) + "\" ay nasa " + str(mission.get("pct", 0)) + "% na — goal: " + str(mission.get("desc", "")) + ". Life Goal: " + str(StatManager.get_goal_progress_percent()) + "%!")
	general_replies.append("Market & Ipon Pulse: " + str(mood.get("label", "Steady Market")) + " ngayon. Ang ₱" + UITheme.format_num(StatManager.savings) + " sa Bangko Ipon ay kikita ng ~+₱" + UITheme.format_num(next_sav_interest) + " ngayong buwan.")
	general_replies.append("Well-Being & Credit Check: Happy " + str(StatManager.happy) + "/100 | Social " + str(StatManager.social) + "/100 | Credit Score " + str(StatManager.credit_score) + "/100" + (" | Utang: ₱" + UITheme.format_num(tot_debt) if tot_debt > 0 else " | ₱0 Utang!") + ".")
	return _pick_non_repeating(general_replies)
