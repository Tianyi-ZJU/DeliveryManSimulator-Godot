extends Control

## Rest-screen presentation emits commands; costs/limits belong to DayCycle.
signal purchase_requested(kind: String)
signal next_day_requested()
const Config := preload("res://scripts/core/game_config.gd")
const GameState := preload("res://scripts/core/game_state.gd")
var state: GameState
var upgrade_panel: Panel
var upgrade_money_label: Label
var upgrade_purchase_label: Label
var upgrade_next_day: Button
var upgrade_buttons: Dictionary = {}

func _init(shared_state: GameState) -> void:
	state = shared_state

func _ready() -> void:
	name = "RestScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay := ColorRect.new()
	overlay.name = "UpgradeOverlay"
	overlay.color = Color(0.02, 0.04, 0.08, 0.86)
	overlay.size = Config.MAP_MARGIN.size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	upgrade_panel = Panel.new()
	upgrade_panel.name = "UpgradePanel"
	upgrade_panel.position = Vector2(190, 58)
	upgrade_panel.size = Vector2(900, 558)
	upgrade_panel.theme = theme
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.72, 0.76, 0.78, 0.36)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(22)
	panel_style.shadow_color = Color(0.01, 0.02, 0.04, 0.38)
	panel_style.shadow_size = 14
	upgrade_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(upgrade_panel)
	upgrade_buttons.clear()
	var content := VBoxContainer.new()
	content.name = "UpgradeContent"
	content.position = Vector2(30, 24)
	content.size = Vector2(840, 510)
	content.add_theme_constant_override("separation", 12)
	upgrade_panel.add_child(content)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size.y = 64
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_upgrade_label("休息点 · 第 %d 天完成" % state.day, 14, Color("#aebbc7")))
	heading.add_child(_upgrade_label("整备送餐车", 29, Color("#eef1ed")))
	heading.add_child(_upgrade_label("选择升级后开始下一天", 13, Color("#8998a5")))
	header.add_child(heading)
	var status := PanelContainer.new()
	status.name = "Status"
	status.custom_minimum_size = Vector2(180, 58)
	status.add_theme_stylebox_override("panel", _upgrade_style(Color(0.14, 0.19, 0.23, 0.9), Color(0.75, 0.78, 0.70, 0.25), 12))
	var status_box := VBoxContainer.new()
	status_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_box.add_theme_constant_override("separation", 2)
	status_box.add_child(_upgrade_label("可用资金", 11, Color("#9eabb4")))
	upgrade_money_label = _upgrade_label("", 21, Color("#e0df72"))
	status_box.add_child(upgrade_money_label)
	status.add_child(status_box)
	header.add_child(status)

	var stats := HBoxContainer.new()
	stats.name = "DailyStats"
	stats.add_theme_constant_override("separation", 10)
	content.add_child(stats)
	_upgrade_stat(stats, "今日送达", "%d 单" % (state.finished_count - state.day_start_finished))
	var daily_net := state.money - state.day_start_money
	var daily_net_text := ("-$%d" % -daily_net) if daily_net < 0 else ("$%d" % daily_net)
	_upgrade_stat(stats, "今日净收入", daily_net_text)
	_upgrade_stat(stats, "升级费用", "$100 / 项")

	var section := HBoxContainer.new()
	section.custom_minimum_size.y = 24
	section.add_child(_upgrade_label("选择升级", 17, Color("#eef1ed")))
	var section_spacer := Control.new()
	section_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(section_spacer)
	upgrade_purchase_label = _upgrade_label("", 13, Color("#aebbc7"))
	section.add_child(upgrade_purchase_label)
	content.add_child(section)

	var grid := GridContainer.new()
	grid.name = "UpgradeGrid"
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	_build_upgrade_option(grid, "speed", "速度", "更快抵达下一站", "当前 %.0f  ->  %.0f" % [state.courier_speed, state.courier_speed + 4.0])
	_build_upgrade_option(grid, "capacity", "容量", "同时携带更多订单", "当前 %d  ->  %d 单" % [state.capacity, state.capacity + 1])
	_build_upgrade_option(grid, "speed_energy", "加速能量", "延长加速可用时间", "当前 %.0f  ->  %.0f" % [state.speed_energy_max, state.speed_energy_max + 20.0])
	_build_upgrade_option(grid, "slow_energy", "慢时能量", "更长时间观察路线", "当前 %.0f  ->  %.0f" % [state.slow_energy_max, state.slow_energy_max + 15.0])

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.custom_minimum_size.y = 52
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	var hint := _upgrade_label("SPACE 也可直接开始下一天", 12, Color("#84929d"))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(hint)
	upgrade_next_day = Button.new()
	upgrade_next_day.name = "StartNextDay"
	upgrade_next_day.custom_minimum_size = Vector2(240, 48)
	upgrade_next_day.add_theme_font_size_override("font_size", 16)
	upgrade_next_day.focus_mode = Control.FOCUS_NONE
	upgrade_next_day.pressed.connect(next_day_requested.emit)
	_upgrade_button_style(upgrade_next_day, Color("#e0df72"), Color("#f1efa0"), Color("#c4c35e"), Color("#253343"))
	footer.add_child(upgrade_next_day)
	refresh()
	upgrade_panel.modulate.a = 0.0
	upgrade_panel.create_tween().tween_property(upgrade_panel, "modulate:a", 1.0, 0.18)

func _upgrade_style(background: Color, border: Color = Color.TRANSPARENT, radius: int = 12, padding: Vector2 = Vector2(16, 10)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	# PanelContainer and Button both use these margins to keep text off borders.
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	return style

func _upgrade_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _upgrade_stat(row: HBoxContainer, caption: String, value: String) -> void:
	var stat := PanelContainer.new()
	stat.custom_minimum_size = Vector2(0, 48)
	stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat.add_theme_stylebox_override("panel", _upgrade_style(Color(0.11, 0.15, 0.19, 0.8), Color(0.62, 0.68, 0.70, 0.18), 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.add_child(_upgrade_label(caption, 11, Color("#8998a5")))
	box.add_child(_upgrade_label(value, 17, Color("#eef1ed")))
	stat.add_child(box)
	row.add_child(stat)

func _build_upgrade_option(grid: GridContainer, kind: String, title: String, description: String, effect: String) -> void:
	var card := PanelContainer.new()
	card.name = "Option_" + kind
	card.custom_minimum_size = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _upgrade_style(Color(0.11, 0.15, 0.19, 0.92), Color(0.62, 0.68, 0.70, 0.22), 12, Vector2(16, 12)))
	var box := VBoxContainer.new()
	box.name = "OptionContent"
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	box.add_child(_upgrade_label(title, 17, Color("#eef1ed")))
	box.add_child(_upgrade_label(description, 12, Color("#9eabb4")))
	var footer := HBoxContainer.new()
	footer.name = "OptionFooter"
	footer.add_theme_constant_override("separation", 8)
	var effect_label := _upgrade_label(effect, 12, Color("#e0df72"))
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(effect_label)
	var button := Button.new()
	button.name = "Buy"
	button.custom_minimum_size = Vector2(112, 30)
	button.add_theme_font_size_override("font_size", 14)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(purchase_requested.emit.bind(kind))
	_upgrade_button_style(button, Color(0.22, 0.28, 0.31, 0.95), Color(0.30, 0.37, 0.40, 0.98), Color(0.17, 0.22, 0.25, 0.98), Color("#eef1ed"))
	footer.add_child(button)
	box.add_child(footer)
	grid.add_child(card)
	upgrade_buttons[kind] = button

func _upgrade_button_style(button: Button, normal: Color, hover: Color, pressed: Color, text_color: Color) -> void:
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.59, 0.60, 0.65))
	var padding := Vector2(16, 8)
	button.add_theme_stylebox_override("normal", _upgrade_style(normal, Color(0.70, 0.75, 0.74, 0.18), 8, padding))
	button.add_theme_stylebox_override("hover", _upgrade_style(hover, Color(0.80, 0.83, 0.70, 0.45), 8, padding))
	button.add_theme_stylebox_override("pressed", _upgrade_style(pressed, Color(0.80, 0.83, 0.70, 0.55), 8, padding))
	button.add_theme_stylebox_override("disabled", _upgrade_style(Color(0.12, 0.16, 0.18, 0.65), Color(0.46, 0.50, 0.50, 0.12), 8, padding))

func refresh() -> void:
	if not is_instance_valid(upgrade_panel):
		return
	if upgrade_money_label:
		upgrade_money_label.text = "$%d" % state.money
	if upgrade_purchase_label:
		upgrade_purchase_label.text = "今日已用 %d / 2 次" % (2 - state.purchases_left)
	if upgrade_next_day:
		upgrade_next_day.text = "开始下一天" if state.purchases_left == 0 else "开始下一天 · 跳过 %d 次升级" % state.purchases_left
	for kind in upgrade_buttons:
		var button: Button = upgrade_buttons[kind]
		var maxed := int(state.upgrades_remaining[kind]) <= 0
		button.disabled = maxed or state.purchases_left <= 0
		button.text = "已达上限" if maxed else ("购买  $100" if state.money >= 100 else "资金不足")
