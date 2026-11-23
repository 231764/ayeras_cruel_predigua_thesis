extends Panel

const UITheme = preload("res://scripts/ui_theme.gd")

const ICON_CASH := preload("res://assets/cashonhand.png")
const ICON_BANK := preload("res://assets/bank.png")
const ICON_BUDGET := preload("res://assets/budget.png")
const ICON_CREDIT := preload("res://assets/creditcard.png")
const ICON_LOAN := preload("res://assets/loan.png")
const ICON_SCORE := preload("res://assets/creditscore.png")
const ICON_PHONE := preload("res://assets/phone.png")
const ICON_PLANNER := preload("res://assets/planner.png")
const ICON_LAPTOP := preload("res://assets/laptop.png")
const ICON_HAPPY := preload("res://assets/happy 60.png")
const ICON_HAPPY_MAX := preload("res://assets/happy90.png")
const ICON_SOCIAL := preload("res://assets/social.png")
const ICON_GOAL_DEFAULT := preload("res://assets/goal_kapatid.png")

const INITIAL_CARD_LIMIT := 45

@onready var overview_label: RichTextLabel = get_node_or_null("StatusReportLabel")

var _active_tab: String = "overview" # "overview", "ledger", "achievements"
var _active_filter: String = "all"   # "all", "transactions", "decisions", "achievements"
var _ledger_card_limit: int = INITIAL_CARD_LIMIT
var _last_export_folder: String = ""

var _header_label: Label
var _tab_overview_btn: Button
var _tab_ledger_btn: Button
var _tab_achievements_btn: Button
var _download_btn: Button

var _export_bar: HBoxContainer
var _export_status_lbl: Label
var _open_folder_btn: Button
var _save_as_btn: Button
var _save_dialog: FileDialog

var _overview_container: VBoxContainer
var _stage_title_lbl: Label
var _stage_theme_lbl: Label
var _employment_pill_lbl: Label
var _victory_grid: GridContainer
var _env_strip: HBoxContainer

var _ledger_container: VBoxContainer
var _kpi_grid: HBoxContainer
var _cashflow_bar: ProgressBar
var _cashflow_bar_lbl: Label
var _filter_buttons: Dictionary = {}
var _ledger_scroll: ScrollContainer
var _ledger_list: VBoxContainer

var _achievements_container: VBoxContainer
var _ach_progress_bar: ProgressBar
var _ach_grid: GridContainer

func _ready() -> void:
	_build_dashboard_ui()
	LedgerManager.on_entry_recorded.connect(_on_ledger_changed)
	LedgerManager.on_achievement_unlocked.connect(_on_ledger_changed)
	LedgerManager.on_ledger_reset.connect(_on_ledger_changed)
	StatManager.on_stats_changed.connect(_on_stats_changed)
	
	var parent_node := get_parent()
	if parent_node:
		parent_node.visibility_changed.connect(func():
			if parent_node.visible:
				_ledger_card_limit = INITIAL_CARD_LIMIT
				refresh_all()
		)
	_select_tab("overview")
	refresh_all()

func _get_icon_for_key(key: String) -> Texture2D:
	match key:
		"cash", "Income":
			return ICON_CASH
		"bank", "Savings":
			return ICON_BANK
		"budget", "Budgeting", "Daily Routine", "Routine Setting":
			return ICON_BUDGET
		"credit", "Credit Card":
			return ICON_CREDIT
		"loan", "Loan", "Debt", "Bills":
			return ICON_LOAN
		"creditscore", "Achievement":
			return ICON_SCORE
		"phone", "Event":
			return ICON_PHONE
		"planner", "Weekly Review", "Year-End":
			return ICON_PLANNER
		"laptop", "Investment", "Interest & Returns":
			return ICON_LAPTOP
		"happy", "Weekend":
			return ICON_HAPPY
		"happy_max":
			return ICON_HAPPY_MAX
		"social":
			return ICON_SOCIAL
		"goal", "Goal":
			var g := StatManager.get_current_goal()
			return g.get("icon", ICON_GOAL_DEFAULT)
		_:
			return ICON_PLANNER

func _build_dashboard_ui() -> void:
	offset_left = 96.0
	offset_top = 62.0
	offset_right = 1056.0
	offset_bottom = 622.0
	clip_contents = true
	add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_CREAM, UITheme.INK_BORDER, 14, 3, 7, 16.0, 12.0))
	
	# Keep legacy StatusReportLabel hidden (still updated by stat_system.gd without breaking anything)
	if overview_label:
		overview_label.visible = false
	
	var root_vbox := VBoxContainer.new()
	root_vbox.name = "DashboardVBox"
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.offset_left = 18.0
	root_vbox.offset_top = 12.0
	root_vbox.offset_right = -18.0
	root_vbox.offset_bottom = -12.0
	root_vbox.add_theme_constant_override("separation", 8)
	add_child(root_vbox)
	
	# 1. Header Banner
	_header_label = Label.new()
	_header_label.name = "DashboardHeader"
	_header_label.text = "PALDO STATUS & LEDGER"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 17)
	UITheme.style_header_banner(_header_label, UITheme.BTN_SAGE, 8, 5.0)
	root_vbox.add_child(_header_label)
	
	# 2. Tabs + Direct Download CTA Row
	var nav_row := HBoxContainer.new()
	nav_row.name = "TabsRow"
	nav_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(nav_row)
	
	_tab_overview_btn = _create_nav_button("OverviewTabButton", "Overview", func(): _select_tab("overview"))
	nav_row.add_child(_tab_overview_btn)
	
	_tab_ledger_btn = _create_nav_button("LedgerTabButton", "Ledger (0)", func(): _select_tab("ledger"))
	nav_row.add_child(_tab_ledger_btn)
	
	_tab_achievements_btn = _create_nav_button("AchievementsTabButton", "Badges (0/14)", func(): _select_tab("achievements"))
	nav_row.add_child(_tab_achievements_btn)
	
	_download_btn = Button.new()
	_download_btn.name = "DownloadLedgerButton"
	_download_btn.text = "Download Ledger"
	_download_btn.tooltip_text = "Save CSV & JSON directly to your device Downloads folder"
	_download_btn.custom_minimum_size = Vector2(174, 36)
	_download_btn.add_theme_font_size_override("font_size", 13)
	UITheme.style_Button(_download_btn, UITheme.BTN_BLUE, 8, 4, 10.0, 5.0)
	_download_btn.pressed.connect(_on_download_pressed)
	nav_row.add_child(_download_btn)
	
	# 3. Compact Download Feedback Bar (shown on download, with 1-click Open Folder + Save As)
	_export_bar = HBoxContainer.new()
	_export_bar.name = "ExportFeedbackBar"
	_export_bar.visible = false
	_export_bar.add_theme_constant_override("separation", 6)
	root_vbox.add_child(_export_bar)
	
	_export_status_lbl = Label.new()
	_export_status_lbl.name = "ExportStatusLabel"
	_export_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_export_status_lbl.clip_text = true
	_export_status_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_export_status_lbl.add_theme_font_size_override("font_size", 12)
	_export_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_SUCCESS)
	_export_status_lbl.add_theme_stylebox_override("normal", UITheme.make_card_style(UITheme.PAPER_STICKY, UITheme.INK_BORDER, 6, 2, 2, 10.0, 4.0))
	_export_bar.add_child(_export_status_lbl)
	
	_open_folder_btn = Button.new()
	_open_folder_btn.name = "OpenFolderButton"
	_open_folder_btn.text = "Open Folder"
	_open_folder_btn.custom_minimum_size = Vector2(104, 28)
	_open_folder_btn.add_theme_font_size_override("font_size", 12)
	UITheme.style_Button(_open_folder_btn, UITheme.BTN_GOLD, 6, 3, 8.0, 3.0)
	_open_folder_btn.pressed.connect(func(): LedgerManager.open_export_folder(_last_export_folder))
	_export_bar.add_child(_open_folder_btn)
	
	_save_as_btn = Button.new()
	_save_as_btn.name = "SaveAsButton"
	_save_as_btn.text = "Save As..."
	_save_as_btn.custom_minimum_size = Vector2(92, 28)
	_save_as_btn.add_theme_font_size_override("font_size", 12)
	UITheme.style_Button(_save_as_btn, UITheme.PAPER_CREAM, 6, 3, 8.0, 3.0)
	_save_as_btn.pressed.connect(_on_save_as_pressed)
	_export_bar.add_child(_save_as_btn)
	
	# Native OS FileDialog for optional Save As...
	_save_dialog = FileDialog.new()
	_save_dialog.name = "LedgerSaveDialog"
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.use_native_dialog = true
	_save_dialog.title = "Save Paldo Ledger"
	_save_dialog.filters = PackedStringArray(["*.csv ; CSV Spreadsheet", "*.json ; JSON Dataset"])
	_save_dialog.file_selected.connect(_on_save_dialog_file_selected)
	add_child(_save_dialog)
	
	# 4. Tab Content Stack
	var content_stack := Control.new()
	content_stack.name = "ContentStack"
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_stack)
	
	_build_overview_tab(content_stack)
	_build_ledger_tab(content_stack)
	_build_achievements_tab(content_stack)

func _create_nav_button(btn_name: String, label_txt: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.name = btn_name
	btn.text = label_txt
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(callback)
	return btn

func _build_overview_tab(parent_ctrl: Control) -> void:
	_overview_container = VBoxContainer.new()
	_overview_container.name = "OverviewContainer"
	_overview_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overview_container.add_theme_constant_override("separation", 10)
	parent_ctrl.add_child(_overview_container)
	
	var stage_card := PanelContainer.new()
	stage_card.name = "StageBannerCard"
	stage_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_KRAFT, UITheme.INK_BORDER, 8, 2, 3, 12.0, 6.0))
	_overview_container.add_child(stage_card)
	
	var stage_hb := HBoxContainer.new()
	stage_hb.add_theme_constant_override("separation", 10)
	stage_card.add_child(stage_hb)
	
	var stage_vb := VBoxContainer.new()
	stage_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_vb.add_theme_constant_override("separation", 2)
	stage_hb.add_child(stage_vb)
	
	_stage_title_lbl = Label.new()
	_stage_title_lbl.name = "StageTitleLabel"
	_stage_title_lbl.add_theme_font_size_override("font_size", 15)
	_stage_title_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	stage_vb.add_child(_stage_title_lbl)
	
	_stage_theme_lbl = Label.new()
	_stage_theme_lbl.name = "StageThemeLabel"
	_stage_theme_lbl.add_theme_font_size_override("font_size", 12)
	_stage_theme_lbl.add_theme_color_override("font_color", Color(0.32, 0.25, 0.20, 1.0))
	_stage_theme_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_vb.add_child(_stage_theme_lbl)
	
	_employment_pill_lbl = _make_badge_pill("Regular Job", UITheme.PAPER_CREAM, UITheme.INK_DARK)
	_employment_pill_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage_hb.add_child(_employment_pill_lbl)
	
	_victory_grid = GridContainer.new()
	_victory_grid.name = "VictoryCardsGrid"
	_victory_grid.columns = 2
	_victory_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_victory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_victory_grid.add_theme_constant_override("h_separation", 10)
	_victory_grid.add_theme_constant_override("v_separation", 10)
	_overview_container.add_child(_victory_grid)
	
	var env_hdr := Label.new()
	env_hdr.text = "CASH ENVELOPES AT A GLANCE"
	env_hdr.add_theme_font_size_override("font_size", 12)
	env_hdr.add_theme_color_override("font_color", UITheme.INK_MUTED)
	_overview_container.add_child(env_hdr)
	
	_env_strip = HBoxContainer.new()
	_env_strip.name = "EnvelopesStrip"
	_env_strip.add_theme_constant_override("separation", 6)
	_overview_container.add_child(_env_strip)

func _build_ledger_tab(parent_ctrl: Control) -> void:
	_ledger_container = VBoxContainer.new()
	_ledger_container.name = "LedgerContainer"
	_ledger_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ledger_container.add_theme_constant_override("separation", 8)
	_ledger_container.visible = false
	parent_ctrl.add_child(_ledger_container)
	
	# 4 Illustrated KPI Cards
	_kpi_grid = HBoxContainer.new()
	_kpi_grid.name = "LedgerKPIRow"
	_kpi_grid.add_theme_constant_override("separation", 8)
	_ledger_container.add_child(_kpi_grid)
	
	# Visual Inflow vs Outflow Ratio Bar
	_cashflow_bar = ProgressBar.new()
	_cashflow_bar.name = "CashFlowBar"
	_cashflow_bar.custom_minimum_size = Vector2(0, 22)
	_cashflow_bar.max_value = 100.0
	_cashflow_bar.value = 50.0
	_cashflow_bar.show_percentage = false
	UITheme.style_progress_bar(_cashflow_bar, UITheme.BTN_SAGE, 7)
	var bg_red := StyleBoxFlat.new()
	bg_red.bg_color = Color(0.92, 0.62, 0.56, 0.95)
	bg_red.border_width_left = 2
	bg_red.border_width_top = 2
	bg_red.border_width_right = 2
	bg_red.border_width_bottom = 3
	bg_red.border_color = UITheme.INK_BORDER
	bg_red.corner_radius_top_left = 7
	bg_red.corner_radius_top_right = 7
	bg_red.corner_radius_bottom_right = 7
	bg_red.corner_radius_bottom_left = 7
	_cashflow_bar.add_theme_stylebox_override("background", bg_red)
	_cashflow_bar_lbl = Label.new()
	_cashflow_bar_lbl.name = "CashFlowBarLabel"
	_cashflow_bar_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cashflow_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cashflow_bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cashflow_bar_lbl.add_theme_font_size_override("font_size", 11)
	_cashflow_bar_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	_cashflow_bar_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.94, 0.92))
	_cashflow_bar_lbl.add_theme_constant_override("outline_size", 3)
	_cashflow_bar.add_child(_cashflow_bar_lbl)
	_ledger_container.add_child(_cashflow_bar)
	
	# 4 Clean Filter Pills (Decisions & Tradeoffs unified!)
	var filter_row := HBoxContainer.new()
	filter_row.name = "FilterRow"
	filter_row.add_theme_constant_override("separation", 6)
	_ledger_container.add_child(filter_row)
	
	var filter_defs := [
		["all", "All"],
		["transactions", "Cash Flow"],
		["decisions", "Decisions & Tradeoffs"],
		["achievements", "Badges"]
	]
	for fd in filter_defs:
		var f_key: String = str(fd[0])
		var f_lbl: String = str(fd[1])
		var f_btn := Button.new()
		f_btn.name = "Filter_" + f_key
		f_btn.text = f_lbl
		f_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f_btn.custom_minimum_size = Vector2(0, 30)
		f_btn.add_theme_font_size_override("font_size", 12)
		f_btn.pressed.connect(func(): _select_filter(f_key))
		filter_row.add_child(f_btn)
		_filter_buttons[f_key] = f_btn
	
	# Visual Scrollable Ledger Card List
	var feed_bg := PanelContainer.new()
	feed_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_bg.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_WARM, UITheme.INK_BORDER, 8, 2, 3, 8.0, 8.0))
	_ledger_container.add_child(feed_bg)
	
	_ledger_scroll = ScrollContainer.new()
	_ledger_scroll.name = "LedgerScroll"
	_ledger_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ledger_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ledger_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feed_bg.add_child(_ledger_scroll)
	
	_ledger_list = VBoxContainer.new()
	_ledger_list.name = "LedgerCardsList"
	_ledger_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ledger_list.add_theme_constant_override("separation", 6)
	_ledger_scroll.add_child(_ledger_list)

func _build_achievements_tab(parent_ctrl: Control) -> void:
	_achievements_container = VBoxContainer.new()
	_achievements_container.name = "AchievementsContainer"
	_achievements_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_achievements_container.add_theme_constant_override("separation", 8)
	_achievements_container.visible = false
	parent_ctrl.add_child(_achievements_container)
	
	_ach_progress_bar = ProgressBar.new()
	_ach_progress_bar.name = "AchievementsProgressBar"
	_ach_progress_bar.custom_minimum_size = Vector2(0, 26)
	_ach_progress_bar.max_value = float(LedgerManager.ACHIEVEMENT_DEFINITIONS.size())
	_ach_progress_bar.show_percentage = false
	UITheme.style_progress_bar(_ach_progress_bar, UITheme.BTN_GOLD, 8)
	var bar_lbl := Label.new()
	bar_lbl.name = "BarLabel"
	bar_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_lbl.add_theme_font_size_override("font_size", 13)
	bar_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	_ach_progress_bar.add_child(bar_lbl)
	_achievements_container.add_child(_ach_progress_bar)
	
	var ach_scroll := ScrollContainer.new()
	ach_scroll.name = "AchievementsScroll"
	ach_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ach_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_achievements_container.add_child(ach_scroll)
	
	_ach_grid = GridContainer.new()
	_ach_grid.name = "AchievementsGrid"
	_ach_grid.columns = 2
	_ach_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ach_grid.add_theme_constant_override("h_separation", 10)
	_ach_grid.add_theme_constant_override("v_separation", 8)
	ach_scroll.add_child(_ach_grid)

func _select_tab(tab_id: String) -> void:
	_active_tab = tab_id
	if _overview_container:
		_overview_container.visible = (tab_id == "overview")
	if _ledger_container:
		_ledger_container.visible = (tab_id == "ledger")
	if _achievements_container:
		_achievements_container.visible = (tab_id == "achievements")
	_refresh_tab_styles()
	refresh_all()

func _select_filter(filter_id: String) -> void:
	_active_filter = filter_id
	_ledger_card_limit = INITIAL_CARD_LIMIT
	_refresh_filter_styles()
	_refresh_ledger_cards()

func _refresh_tab_styles() -> void:
	UITheme.style_Button(_tab_overview_btn, UITheme.BTN_GOLD if _active_tab == "overview" else UITheme.PAPER_CREAM, 8, 5 if _active_tab == "overview" else 3, 10.0, 5.0)
	UITheme.style_Button(_tab_ledger_btn, UITheme.BTN_GOLD if _active_tab == "ledger" else UITheme.PAPER_CREAM, 8, 5 if _active_tab == "ledger" else 3, 10.0, 5.0)
	UITheme.style_Button(_tab_achievements_btn, UITheme.BTN_GOLD if _active_tab == "achievements" else UITheme.PAPER_CREAM, 8, 5 if _active_tab == "achievements" else 3, 10.0, 5.0)

func _refresh_filter_styles() -> void:
	for f_key in _filter_buttons.keys():
		var btn: Button = _filter_buttons[f_key]
		var is_sel: bool = (f_key == _active_filter)
		UITheme.style_Button(btn, UITheme.BTN_SAGE if is_sel else UITheme.PAPER_CREAM, 6, 4 if is_sel else 2, 8.0, 3.0)

func _on_ledger_changed(_arg = null) -> void:
	var p := get_parent()
	if p and p.visible:
		refresh_all()

func _on_stats_changed() -> void:
	var p := get_parent()
	if p and p.visible:
		refresh_all()

func refresh_all() -> void:
	var stats := LedgerManager.get_analytics_summary()
	if _header_label:
		_header_label.text = "PALDO STATUS & LEDGER  •  " + str(stats["entry_count"]) + " Records  •  " + str(stats["achievements_unlocked"]) + "/" + str(stats["achievements_total"]) + " Badges"
	if _tab_ledger_btn:
		_tab_ledger_btn.text = "Ledger (" + str(stats["entry_count"]) + ")"
	if _tab_achievements_btn:
		_tab_achievements_btn.text = "Badges (" + str(stats["achievements_unlocked"]) + "/" + str(stats["achievements_total"]) + ")"
	_refresh_tab_styles()
	_refresh_filter_styles()
	if _active_tab == "overview":
		_refresh_overview_dashboard()
	elif _active_tab == "ledger":
		_refresh_ledger_cards()
	elif _active_tab == "achievements":
		_refresh_achievements_grid()

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _make_badge_pill(text_val: String, bg_col: Color, fg_col: Color = UITheme.INK_DARK) -> Label:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", fg_col)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.border_color = UITheme.INK_BORDER
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_right = 5
	sb.corner_radius_bottom_left = 5
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl

func _make_victory_card(icon_tex: Texture2D, title_txt: String, status_txt: String, is_ok: bool, bar_val: float, bar_max: float, bar_label: String, sub_txt: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_WARM, UITheme.INK_BORDER, 10, 2, 4, 12.0, 10.0))
	
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)
	
	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.custom_minimum_size = Vector2(46, 46)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(ic)
	
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)
	
	var top_row := HBoxContainer.new()
	vb.add_child(top_row)
	
	var t_lbl := Label.new()
	t_lbl.text = title_txt
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	top_row.add_child(t_lbl)
	
	top_row.add_child(_make_badge_pill(status_txt, UITheme.BTN_SAGE if is_ok else UITheme.BTN_CORAL))
	
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 20)
	bar.max_value = max(1.0, bar_max)
	bar.value = clamp(bar_val, 0.0, bar.max_value)
	bar.show_percentage = false
	UITheme.style_progress_bar(bar, UITheme.BTN_SAGE if is_ok else UITheme.BTN_GOLD, 6)
	var b_lbl := Label.new()
	b_lbl.text = bar_label
	b_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b_lbl.add_theme_font_size_override("font_size", 11)
	b_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	bar.add_child(b_lbl)
	vb.add_child(bar)
	
	var s_lbl := Label.new()
	s_lbl.text = sub_txt
	s_lbl.add_theme_font_size_override("font_size", 11)
	s_lbl.add_theme_color_override("font_color", UITheme.INK_MUTED)
	s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(s_lbl)
	
	return card

func _refresh_overview_dashboard() -> void:
	if not _victory_grid:
		return
	var stage_info := StatManager.get_stage_info()
	if _stage_title_lbl:
		_stage_title_lbl.text = str(stage_info["name"])
	if _stage_theme_lbl:
		_stage_theme_lbl.text = "\"" + str(stage_info["theme"]) + "\""
	if _employment_pill_lbl:
		_employment_pill_lbl.text = StatManager.get_employment_display_text()
		
	_clear_children(_victory_grid)
	var g := StatManager.get_current_goal()
	var target: int = StatManager.get_goal_target()
	var pct: int = StatManager.get_goal_progress_percent()
	var goal_ok: bool = (StatManager.savings >= target)
	_victory_grid.add_child(_make_victory_card(
		g.get("icon", ICON_GOAL_DEFAULT),
		str(g["title"]),
		"REACHED" if goal_ok else str(pct) + "%",
		goal_ok,
		float(StatManager.savings),
		float(target),
		"PHP " + UITheme.format_num(StatManager.savings) + " / " + UITheme.format_num(target),
		"Bank Interest Earned: +PHP " + UITheme.format_num(StatManager.total_savings_interest_earned) + "  •  Invest: PHP " + UITheme.format_num(StatManager.get_total_investments())
	))
	
	var wb_ok: bool = (StatManager.happy >= 50 and StatManager.social >= 50)
	_victory_grid.add_child(_make_victory_card(
		ICON_HAPPY_MAX if StatManager.happy >= 65 else ICON_HAPPY,
		"Well-Being & Social",
		"HEALTHY" if wb_ok else "LOW",
		wb_ok,
		float(min(StatManager.happy, StatManager.social)),
		100.0,
		"Happy " + str(StatManager.happy) + "  •  Social " + str(StatManager.social),
		"Target: Keep both Happiness & Social >= 50 until Dec 31."
	))
	
	var cs_ok: bool = (StatManager.credit_score >= 70)
	_victory_grid.add_child(_make_victory_card(
		ICON_SCORE,
		"Credit Standing",
		"GOOD" if cs_ok else "BUILD UP",
		cs_ok,
		float(StatManager.credit_score),
		100.0,
		str(StatManager.credit_score) + " / 100 (Need >= 70)",
		"Card: PHP " + UITheme.format_num(StatManager.credit_balance) + " / " + UITheme.format_num(StatManager.credit_limit)
	))
	
	var total_ob: int = StatManager.get_total_debt_and_loans() + StatManager.credit_balance
	var debt_ok: bool = (total_ob == 0)
	_victory_grid.add_child(_make_victory_card(
		ICON_LOAN,
		"Debt-Free Goal",
		"DEBT-FREE" if debt_ok else "HAS DEBT",
		debt_ok,
		100.0 if debt_ok else max(0.0, 100.0 - float(total_ob) / 500.0),
		100.0,
		"PHP 0 Obligations" if debt_ok else "PHP " + UITheme.format_num(total_ob) + " Total Owed",
		"Overdue: PHP " + UITheme.format_num(StatManager.debt_balance) + "  •  Loans: PHP " + UITheme.format_num(StatManager.get_total_active_loan_balance())
	))
	
	# Compact Envelope Mini-Tiles
	_clear_children(_env_strip)
	var env_short := {"Food": "Pagkain", "Transportation": "Byahe", "Entertainment": "Libangan", "Rent": "Upa", "Utilities": "Bills", "Credit Card": "Credit", "Savings": "Ipon"}
	for env in StatManager.envelopes:
		var cat: String = str(env["category"])
		var amt: int = int(env["amount"])
		var short_n: String = str(env_short.get(cat, cat))
		var shortfall: int = StatManager.get_envelope_shortfall_to_target(cat)
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bg_c := Color(0.86, 0.94, 0.83, 1.0) if (shortfall == 0 and amt > 0) else UITheme.PAPER_WARM
		tile.add_theme_stylebox_override("panel", UITheme.make_card_style(bg_c, UITheme.INK_BORDER, 7, 2, 3, 6.0, 5.0))
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
		lbl.text = short_n + "\n₱" + UITheme.format_num(amt)
		tile.add_child(lbl)
		_env_strip.add_child(tile)

func _make_kpi_tile(icon_tex: Texture2D, title_txt: String, value_txt: String, val_color: Color, bg_color: Color) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", UITheme.make_card_style(bg_color, UITheme.INK_BORDER, 8, 2, 3, 8.0, 6.0))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	tile.add_child(hb)
	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.custom_minimum_size = Vector2(28, 28)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	var t := Label.new()
	t.text = title_txt
	t.add_theme_font_size_override("font_size", 10)
	t.add_theme_color_override("font_color", UITheme.INK_MUTED)
	vb.add_child(t)
	var v := Label.new()
	v.text = value_txt
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", val_color)
	vb.add_child(v)
	return tile

func _make_ledger_row_card(e: Dictionary) -> PanelContainer:
	var et: String = str(e.get("entry_type", "transaction"))
	var cat: String = str(e.get("category", "General"))
	var cash_d: int = int(e.get("cash_delta", 0))
	
	var spine_col := UITheme.BTN_BLUE
	if et == "achievement":
		spine_col = UITheme.BTN_GOLD
	elif et == "decision":
		spine_col = UITheme.BTN_GOLD
	elif cash_d > 0:
		spine_col = UITheme.BTN_SAGE
	elif cash_d < 0:
		spine_col = UITheme.BTN_CORAL
		
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_bg := UITheme.PAPER_KRAFT if et == "achievement" else UITheme.PAPER_CREAM
	var sb := UITheme.make_card_style(card_bg, UITheme.INK_BORDER, 8, 2, 3, 10.0, 6.0)
	sb.border_width_left = 6
	sb.border_color = UITheme.INK_BORDER
	card.add_theme_stylebox_override("panel", sb)
	
	var outer_vb := VBoxContainer.new()
	outer_vb.add_theme_constant_override("separation", 6)
	card.add_child(outer_vb)
	
	var main_hb := HBoxContainer.new()
	main_hb.add_theme_constant_override("separation", 10)
	outer_vb.add_child(main_hb)
	
	# Color indicator dot/bar + Category Icon
	var dot := ColorRect.new()
	dot.color = spine_col
	dot.custom_minimum_size = Vector2(5, 34)
	main_hb.add_child(dot)
	
	var ic := TextureRect.new()
	ic.texture = _get_icon_for_key(cat)
	ic.custom_minimum_size = Vector2(32, 32)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	main_hb.add_child(ic)
	
	# Center Info: Concise Title + Compact Impact Chips
	var mid_vb := VBoxContainer.new()
	mid_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_vb.add_theme_constant_override("separation", 3)
	main_hb.add_child(mid_vb)
	
	var title_hb := HBoxContainer.new()
	title_hb.add_theme_constant_override("separation", 6)
	mid_vb.add_child(title_hb)
	
	var title_lbl := Label.new()
	title_lbl.text = str(e.get("title", ""))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", UITheme.INK_DARK)
	title_hb.add_child(title_lbl)
	
	var gd: Dictionary = e.get("game_date", {})
	var date_short := str(gd.get("month_name", "")).left(3) + " " + str(gd.get("day", 1)) + " • " + str(gd.get("weekday", ""))
	var date_lbl := Label.new()
	date_lbl.text = date_short
	date_lbl.add_theme_font_size_override("font_size", 11)
	date_lbl.add_theme_color_override("font_color", UITheme.INK_MUTED)
	title_hb.add_child(date_lbl)
	
	# Compact Visual Chips Row (instead of long prose paragraphs!)
	var chips_hb := HBoxContainer.new()
	chips_hb.add_theme_constant_override("separation", 5)
	mid_vb.add_child(chips_hb)
	
	var type_badge_txt := "DECISION" if et == "decision" else ("BADGE" if et == "achievement" else ("MILESTONE" if et == "milestone" else cat.to_upper()))
	var type_bg := UITheme.BTN_GOLD if (et == "decision" or et == "achievement") else UITheme.PAPER_WARM
	chips_hb.add_child(_make_badge_pill(type_badge_txt, type_bg))
	
	var deltas: Dictionary = e.get("deltas", {})
	var chip_defs := [
		["savings", "Ipon", true, false],
		["credit_balance", "CC", true, true],
		["debt_balance", "Debt", true, true],
		["happy", "Happy", false, false],
		["social", "Social", false, false],
		["credit_score", "CS", false, false]
	]
	var chip_count := 0
	for cd in chip_defs:
		if chip_count >= 3:
			break
		var k: String = str(cd[0])
		if deltas.has(k) and int(deltas[k]) != 0:
			var v: int = int(deltas[k])
			var is_php: bool = bool(cd[2])
			var inv: bool = bool(cd[3])
			var good: bool = (v < 0) if inv else (v > 0)
			var txt: String = ("+" if v > 0 else "-") + (("₱" + UITheme.format_num(abs(v))) if is_php else str(abs(v))) + " " + str(cd[1])
			chips_hb.add_child(_make_badge_pill(txt, Color(0.84, 0.94, 0.82, 1.0) if good else Color(0.98, 0.84, 0.80, 1.0), UITheme.TEXT_SUCCESS if good else UITheme.TEXT_DANGER))
			chip_count += 1
			
	if chip_count == 0:
		var sum_lbl := Label.new()
		sum_lbl.text = str(e.get("summary", ""))
		sum_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sum_lbl.clip_text = true
		sum_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sum_lbl.add_theme_font_size_override("font_size", 11)
		sum_lbl.add_theme_color_override("font_color", UITheme.INK_MUTED)
		chips_hb.add_child(sum_lbl)
	
	# Right Side: Amount Pill + Optional Expand Tradeoff Drawer Button
	var right_vb := VBoxContainer.new()
	right_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vb.add_theme_constant_override("separation", 3)
	main_hb.add_child(right_vb)
	
	if cash_d != 0:
		var amt_txt := ("+₱" if cash_d > 0 else "-₱") + UITheme.format_num(abs(cash_d))
		var amt_pill := _make_badge_pill(amt_txt, Color(0.82, 0.94, 0.80, 1.0) if cash_d > 0 else Color(0.98, 0.82, 0.78, 1.0), UITheme.TEXT_SUCCESS if cash_d > 0 else UITheme.TEXT_DANGER)
		amt_pill.add_theme_font_size_override("font_size", 13)
		amt_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_vb.add_child(amt_pill)
	
	var tf: Dictionary = e.get("tradeoff", {})
	if not tf.is_empty():
		var drawer := PanelContainer.new()
		drawer.visible = false
		drawer.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.PAPER_STICKY, UITheme.INK_BORDER, 6, 1, 2, 8.0, 5.0))
		var d_rtf := RichTextLabel.new()
		d_rtf.bbcode_enabled = true
		d_rtf.fit_content = true
		d_rtf.scroll_active = false
		d_rtf.add_theme_color_override("default_color", UITheme.INK_DARK)
		d_rtf.add_theme_font_size_override("normal_font_size", 11)
		d_rtf.add_theme_font_size_override("bold_font_size", 11)
		var alts: Array = tf.get("alternatives", [])
		var d_txt := "[b]Pinili:[/b] " + str(tf.get("chosen_option", ""))
		if str(tf.get("opportunity_cost_note", "")) != "":
			d_txt += "\n[color=#6e3b10][i]" + str(tf["opportunity_cost_note"]) + "[/i][/color]"
		if not alts.is_empty():
			d_txt += "\n[color=#5c4f45][b]Hindi Pinili:[/b] " + "  •  ".join(alts) + "[/color]"
		d_rtf.text = d_txt
		drawer.add_child(d_rtf)
		outer_vb.add_child(drawer)
		
		var toggle_btn := Button.new()
		toggle_btn.text = "Tradeoff v"
		toggle_btn.custom_minimum_size = Vector2(84, 22)
		toggle_btn.add_theme_font_size_override("font_size", 10)
		UITheme.style_Button(toggle_btn, UITheme.PAPER_KRAFT, 5, 2, 6.0, 2.0)
		toggle_btn.pressed.connect(func():
			drawer.visible = not drawer.visible
			toggle_btn.text = "Hide ^" if drawer.visible else "Tradeoff v"
		)
		right_vb.add_child(toggle_btn)
		
	return card

func _refresh_ledger_cards() -> void:
	var stats := LedgerManager.get_analytics_summary()
	if _kpi_grid:
		_clear_children(_kpi_grid)
		_kpi_grid.add_child(_make_kpi_tile(ICON_CASH, "INFLOW", "+₱" + UITheme.format_num(int(stats["total_inflow"])), UITheme.TEXT_SUCCESS, Color(0.88, 0.96, 0.86, 1.0)))
		_kpi_grid.add_child(_make_kpi_tile(ICON_LOAN, "OUTFLOW", "-₱" + UITheme.format_num(int(stats["total_outflow"])), UITheme.TEXT_DANGER, Color(0.99, 0.89, 0.86, 1.0)))
		var nw: int = int(stats["net_worth"])
		_kpi_grid.add_child(_make_kpi_tile(ICON_BANK, "NET WORTH", ("₱" if nw >= 0 else "-₱") + UITheme.format_num(abs(nw)), UITheme.TEXT_SUCCESS if nw >= 0 else UITheme.TEXT_DANGER, UITheme.PAPER_KRAFT))
		_kpi_grid.add_child(_make_kpi_tile(ICON_SCORE, "DECISIONS", str(stats["decisions_count"]) + " Choices", UITheme.INK_DARK, UITheme.PAPER_CREAM))
		
	if _cashflow_bar:
		var inf: float = float(max(0, int(stats["total_inflow"])))
		var outf: float = float(max(0, int(stats["total_outflow"])))
		var tot_flow: float = inf + outf
		var ratio: float = 50.0 if tot_flow <= 0.0 else clamp((inf / tot_flow) * 100.0, 0.0, 100.0)
		_cashflow_bar.value = ratio
		if _cashflow_bar_lbl:
			_cashflow_bar_lbl.text = "CASH FLOW RATIO: " + str(int(round(ratio))) + "% INFLOW  •  SAVINGS RATE: " + str(stats["savings_rate_pct"]) + "%"
			
	if not _ledger_list:
		return
	_clear_children(_ledger_list)
	var filtered := LedgerManager.get_filtered_entries(_active_filter)
	if filtered.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Wala pang nakatalang record para sa filter na ito."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.custom_minimum_size = Vector2(0, 60)
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", UITheme.INK_MUTED)
		_ledger_list.add_child(empty_lbl)
		return
		
	var total_cnt: int = filtered.size()
	var start_idx: int = max(0, total_cnt - _ledger_card_limit)
	for i in range(total_cnt - 1, start_idx - 1, -1):
		_ledger_list.add_child(_make_ledger_row_card(filtered[i]))
		
	if start_idx > 0:
		var more_btn := Button.new()
		more_btn.text = "Load Older Records (" + str(start_idx) + " more)"
		more_btn.custom_minimum_size = Vector2(0, 34)
		more_btn.add_theme_font_size_override("font_size", 12)
		UITheme.style_Button(more_btn, UITheme.PAPER_CREAM, 6, 3, 10.0, 4.0)
		more_btn.pressed.connect(func():
			_ledger_card_limit += 45
			_refresh_ledger_cards()
		)
		_ledger_list.add_child(more_btn)

func _refresh_achievements_grid() -> void:
	if not _ach_grid:
		return
	_clear_children(_ach_grid)
	var catalog := LedgerManager.get_achievements_catalog()
	var unlocked_cnt := 0
	for item in catalog:
		if bool(item.get("unlocked", false)):
			unlocked_cnt += 1
	if _ach_progress_bar:
		_ach_progress_bar.max_value = float(max(1, catalog.size()))
		_ach_progress_bar.value = float(unlocked_cnt)
		var bl := _ach_progress_bar.get_node_or_null("BarLabel") as Label
		if bl:
			bl.text = "BADGES UNLOCKED: " + str(unlocked_cnt) + " / " + str(catalog.size())
			
	for item in catalog:
		var is_unlocked: bool = bool(item.get("unlocked", false))
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_bg := UITheme.PAPER_KRAFT if is_unlocked else UITheme.PAPER_WARM
		card.add_theme_stylebox_override("panel", UITheme.make_card_style(card_bg, UITheme.INK_BORDER, 8, 2, 4 if is_unlocked else 2, 10.0, 8.0))
		
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)
		
		var ic := TextureRect.new()
		ic.texture = _get_icon_for_key(str(item.get("icon", "creditscore")))
		ic.custom_minimum_size = Vector2(42, 42)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_unlocked else Color(0.55, 0.52, 0.48, 0.55)
		hb.add_child(ic)
		
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 2)
		hb.add_child(vb)
		
		var top_hb := HBoxContainer.new()
		vb.add_child(top_hb)
		
		var title_l := Label.new()
		title_l.text = str(item["title"])
		title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_l.add_theme_font_size_override("font_size", 13)
		title_l.add_theme_color_override("font_color", UITheme.INK_DARK if is_unlocked else UITheme.INK_MUTED)
		top_hb.add_child(title_l)
		
		top_hb.add_child(_make_badge_pill(
			str(item.get("unlocked_date_text", "UNLOCKED")) if is_unlocked else "LOCKED",
			UITheme.BTN_SAGE if is_unlocked else Color(0.84, 0.81, 0.75, 1.0),
			UITheme.INK_DARK if is_unlocked else UITheme.INK_MUTED
		))
		
		var desc_l := Label.new()
		desc_l.text = str(item["description"])
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.add_theme_font_size_override("font_size", 11)
		desc_l.add_theme_color_override("font_color", UITheme.INK_DARK if is_unlocked else UITheme.INK_MUTED)
		vb.add_child(desc_l)
		
		if is_unlocked:
			var les_l := Label.new()
			les_l.text = "Tip: " + str(item["lesson"])
			les_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			les_l.add_theme_font_size_override("font_size", 11)
			les_l.add_theme_color_override("font_color", Color(0.10, 0.29, 0.48, 1.0))
			vb.add_child(les_l)
			
		_ach_grid.add_child(card)

func _on_download_pressed() -> void:
	var res := LedgerManager.export_to_device_downloads()
	_last_export_folder = str(res.get("folder_path", ""))
	if _export_bar:
		_export_bar.visible = true
	if _open_folder_btn:
		_open_folder_btn.visible = (_last_export_folder != "" and not OS.has_feature("web"))
	if _save_as_btn:
		_save_as_btn.visible = (not OS.has_feature("web"))
	if _export_status_lbl:
		if bool(res.get("ok", false)):
			_export_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_SUCCESS)
			_export_status_lbl.text = "Saved to " + str(res.get("folder_label", "Downloads")) + ": " + str(res.get("csv_filename", "")) + " & .json (" + str(res["entry_count"]) + " rows)"
		else:
			_export_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_DANGER)
			_export_status_lbl.text = "Download failed: " + str(res.get("error", "Unknown error"))

func _on_save_as_pressed() -> void:
	if not _save_dialog:
		return
	var target := LedgerManager.resolve_device_downloads_dir()
	_save_dialog.current_dir = str(target["path"])
	_save_dialog.current_file = LedgerManager._build_friendly_export_stem() + ".csv"
	_save_dialog.popup_centered_ratio(0.65)

func _on_save_dialog_file_selected(path: String) -> void:
	var res := LedgerManager.export_single_file(path)
	if _export_bar:
		_export_bar.visible = true
	if _export_status_lbl:
		if bool(res.get("ok", false)):
			_last_export_folder = path.get_base_dir()
			_export_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_SUCCESS)
			_export_status_lbl.text = "Saved " + str(res["format"]) + ": " + str(res["filename"]) + " (" + str(res["entry_count"]) + " rows)"
		else:
			_export_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_DANGER)
			_export_status_lbl.text = "Save failed: " + str(res.get("error", "Unknown error"))
