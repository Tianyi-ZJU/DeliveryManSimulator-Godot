extends Control

## Presentation only. Online requests belong to LeaderboardController.
signal connect_requested(nickname: String)
signal refresh_requested()
signal submit_requested()
signal close_requested()
const HUD_FONT := preload("res://assets/LiberationSans.ttf")
var run_score: Variant
var nickname: LineEdit
var connect_button: Button
var refresh_button: Button
var submit_button: Button
var status: Label
var account: Label
var rows_box: VBoxContainer
var _rows_signature := ""

func _init(score: Variant = null) -> void:
	run_score = score

func _ready() -> void:
	name = "LeaderboardView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font = HUD_FONT
	theme.default_font_size = 16
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.04, 0.08, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 558)
	panel.add_theme_stylebox_override("panel", _style(Color("#111c27"), 18))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label("配送排行榜", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("返回", close_requested.emit)
	close.name = "CloseLeaderboard"
	header.add_child(close)
	account = _label("输入昵称后连接排行榜", 14, Color("#9cabb9"))
	content.add_child(account)
	var login_row := HBoxContainer.new()
	login_row.add_theme_constant_override("separation", 10)
	content.add_child(login_row)
	nickname = LineEdit.new()
	nickname.name = "Nickname"
	nickname.placeholder_text = "昵称 · 3～25 个字符"
	nickname.max_length = 25
	nickname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nickname.custom_minimum_size.y = 40
	nickname.text_submitted.connect(func(_text: String) -> void: _request_connection())
	login_row.add_child(nickname)
	connect_button = _button("连接 / 修改昵称", _request_connection)
	connect_button.name = "ConnectProfile"
	login_row.add_child(connect_button)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.add_child(_cell("名次", 64, Color("#9cabb9")))
	var name_column := _label("玩家", 14, Color("#9cabb9"))
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(name_column)
	columns.add_child(_cell("收入", 110, Color("#9cabb9")))
	content.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.name = "LeaderboardScroll"
	scroll.custom_minimum_size.y = 260
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.name = "LeaderboardRows"
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 4)
	scroll.add_child(rows_box)
	status = _label("", 14, Color("#e0df72"))
	status.custom_minimum_size.y = 40
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	var caption := _label("前 100 名 · 按收入排名" if run_score == null else "本局收入  $%d" % int(run_score), 14, Color("#9cabb9"))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(caption)
	refresh_button = _button("刷新", refresh_requested.emit)
	refresh_button.name = "RefreshLeaderboard"
	footer.add_child(refresh_button)
	if run_score != null:
		submit_button = _button("提交本局成绩", submit_requested.emit)
		submit_button.name = "SubmitScore"
		footer.add_child(submit_button)

func _request_connection() -> void:
	if not connect_button.disabled:
		connect_requested.emit(nickname.text)

func render(model: Dictionary) -> void:
	var connected: bool = model.connected
	var busy: bool = model.busy
	connect_button.disabled = busy or not model.configured
	nickname.editable = not busy
	refresh_button.disabled = busy or not connected
	if submit_button != null:
		submit_button.disabled = busy or not connected or model.submitted
		submit_button.text = "本局已提交" if model.submitted else "提交本局成绩"
	account.text = "已连接 · " + model.nickname if connected else "输入昵称，查看玩家排名"
	if nickname.text.is_empty() and not model.nickname.is_empty():
		nickname.text = model.nickname
	status.text = model.message
	var signature := JSON.stringify(model.rows)
	if signature == _rows_signature:
		return
	_rows_signature = signature
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()
	for row: Dictionary in model.rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.custom_minimum_size.y = 32
		line.add_child(_cell(str(row.rank), 64))
		var player := _label(row.name, 16)
		player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(player)
		line.add_child(_cell("$%d" % int(row.score), 110, Color("#e0df72")))
		rows_box.add_child(line)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.62, 0.69, 0.74, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style(Color("#273847"), 8))
	button.add_theme_stylebox_override("hover", _style(Color("#3a5062"), 8))
	button.add_theme_stylebox_override("pressed", _style(Color("#1b2935"), 8))
	button.pressed.connect(action)
	return button

func _label(text: String, font_size: int, color: Color = Color("#eef1ed")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _cell(text: String, width: float, color: Color = Color("#eef1ed")) -> Label:
	var label := _label(text, 16, color)
	label.custom_minimum_size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label
