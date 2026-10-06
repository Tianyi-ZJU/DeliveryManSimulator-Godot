extends Control

signal settle_requested

const INK := Color("#253343")
const PAPER := Color("#eef1ed")
const MUTED := Color("#b4c0cb")
const ACCENT := Color("#e0df72")

var ready_panel: PanelContainer
var day_label: Label
var completed_value: Label
var income_value: Label
var settle_button: Button
var reveal_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ready_panel()
	hide()

func _style(background: Color, radius: int, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	return style

func _label(text: String, font_size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _content(panel: PanelContainer, padding: int, separation: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, padding)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	return box

func _build_ready_panel() -> void:
	ready_panel = PanelContainer.new()
	ready_panel.name = "ReadyToSettle"
	ready_panel.size = Vector2(300, 496)
	ready_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var card := _style(Color(0.12, 0.18, 0.24, 0.96), 24, Color(0.76, 0.80, 0.78, 0.40))
	card.shadow_color = Color(0.02, 0.04, 0.06, 0.25)
	card.shadow_size = 8
	ready_panel.add_theme_stylebox_override("panel", card)
	add_child(ready_panel)
	var box := _content(ready_panel, 24, 14)
	day_label = _label("", 14, MUTED)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(day_label)
	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_center)
	var icon_plate := PanelContainer.new()
	icon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_plate.add_theme_stylebox_override("panel", _style(Color(0.88, 0.87, 0.45, 0.12), 22))
	icon_center.add_child(icon_plate)
	var icon_margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		icon_margin.add_theme_constant_override("margin_" + edge, 16)
	icon_plate.add_child(icon_margin)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/hare.circle.fill.png")
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = ACCENT
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_child(icon)
	var title := _label("今日收工", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := _label("没有待处理的订单了，辛苦啦！", 14, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stats)
	completed_value = _stat(stats, "今日送达")
	income_value = _stat(stats, "今日净收入")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	settle_button = Button.new()
	settle_button.name = "Settle"
	settle_button.custom_minimum_size.y = 50
	# Space belongs to the game's state transition, not to a focused GUI button.
	settle_button.focus_mode = Control.FOCUS_NONE
	settle_button.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		settle_button.add_theme_color_override(state, INK)
	settle_button.add_theme_stylebox_override("normal", _style(ACCENT, 14))
	settle_button.add_theme_stylebox_override("hover", _style(Color("#f1efa0"), 14))
	settle_button.add_theme_stylebox_override("pressed", _style(Color("#c4c35e"), 14))
	settle_button.pressed.connect(func() -> void: settle_requested.emit())
	box.add_child(settle_button)
	var shortcut := HBoxContainer.new()
	shortcut.alignment = BoxContainer.ALIGNMENT_CENTER
	shortcut.add_theme_constant_override("separation", 8)
	shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(shortcut)
	var keycap := PanelContainer.new()
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_style := _style(Color(0.26, 0.33, 0.40, 0.7), 6, Color(0.70, 0.76, 0.80, 0.3))
	key_style.content_margin_left = 8
	key_style.content_margin_right = 8
	key_style.content_margin_top = 3
	key_style.content_margin_bottom = 3
	keycap.add_theme_stylebox_override("panel", key_style)
	keycap.add_child(_label("SPACE", 12))
	shortcut.add_child(keycap)
	shortcut.add_child(_label("也可收工", 13, MUTED))
	var auto_settle := _label("21:00 自动结算", 12, Color(0.70, 0.75, 0.80, 0.75))
	auto_settle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(auto_settle)

func _stat(row: HBoxContainer, caption: String) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.22, 0.29, 0.35, 0.75), 14))
	row.add_child(panel)
	var box := _content(panel, 12, 5)
	var value := _label("", 23, ACCENT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	var text := _label(caption, 12, MUTED)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	return value

func present(day: int, minutes: int, completed: int, net_income: int) -> void:
	var changed := not visible
	show()
	day_label.text = "第 %d 天  ·  %02d:%02d" % [day, minutes / 60, minutes % 60]
	completed_value.text = "%d 单" % completed
	income_value.text = ("-$%d" % -net_income) if net_income < 0 else ("$%d" % net_income)
	income_value.add_theme_color_override("font_color", Color("#efa796") if net_income < 0 else ACCENT)
	settle_button.text = "查看最终成绩" if day >= 5 else "收工 · 进入升级"
	if changed:
		if reveal_tween != null:
			reveal_tween.kill()
		modulate.a = 0.0
		reveal_tween = create_tween()
		reveal_tween.tween_property(self, "modulate:a", 1.0, 0.18)
