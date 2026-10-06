extends Control

## Gameplay HUD: labels, task list, day-close card and original backplates.
signal settle_requested()
const Config := preload("res://scripts/core/game_config.gd")
const GameState := preload("res://scripts/core/game_state.gd")
const GameAssets := preload("res://scripts/presentation/game_assets.gd")
const TaskListView := preload("res://scripts/ui/task_list_view.gd")
const DayClosePanel := preload("res://scripts/day_close_panel.gd")
var state: GameState
var assets: GameAssets
var task_list: TaskListView
var day_close_panel: DayClosePanel
var money_label: Label

func _init(shared_state: GameState, shared_assets: GameAssets) -> void:
	state = shared_state
	assets = shared_assets

func _ready() -> void:
	name = "OriginalStyleHUD"
	theme = Theme.new()
	theme.default_font = GameAssets.HUD_FONT
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_label = Label.new()
	money_label.name = "Money"
	money_label.position = Vector2(730, 25)
	money_label.size = Vector2(82, 38)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 30)
	money_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(money_label)
	task_list = TaskListView.new(state, assets)
	add_child(task_list)
	day_close_panel = DayClosePanel.new()
	day_close_panel.name = "DayClosePanel"
	day_close_panel.position = Vector2(960, 148)
	day_close_panel.size = Vector2(300, 496)
	day_close_panel.settle_requested.connect(settle_requested.emit)
	add_child(day_close_panel)

func refresh(can_settle: bool) -> void:
	money_label.text = "%d" % state.money
	task_list.visible = not can_settle
	if can_settle:
		day_close_panel.present(state.day, state.clock_minutes, state.finished_count - state.day_start_finished, state.money - state.day_start_money)
	else:
		day_close_panel.hide()
	task_list.refresh()

func _draw_panel(canvas: CanvasItem, rect: Rect2, background: Color, border: Color = Color(0.55, 0.58, 0.63, 0.45), radius: int = 24) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(0 if border.a == 0.0 else 2)
	style.set_corner_radius_all(radius)
	canvas.draw_style_box(style, rect)

func inventory_slot_rect(index: int) -> Rect2:
	# Unity's inventory GridLayoutGroup fixes two rows and fills vertically.
	# Capacity upgrades therefore add columns within the existing HUD panel.
	var column := floori(float(index) / 2.0)
	var row := index % 2
	return Rect2(967 + column * 38, 29 + row * 38, 30, 30)

func draw_backplates(canvas: CanvasItem) -> void:
	var panel := Color(0.18, 0.21, 0.27, 0.78)
	_draw_panel(canvas, Rect2(20, 14, 590, 62), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(canvas, Rect2(20, 92, 300, 60), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(canvas, Rect2(20, 170, 300, 60), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(canvas, Rect2(624, 14, 198, 62), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(canvas, Rect2(842, 14, 87, 62), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(canvas, Config.INVENTORY_PANEL, panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(canvas, Rect2(940, 130, 340, 537), Color(0.40, 0.43, 0.47, 0.32), Color(0.72, 0.75, 0.78, 0.55), 28)
	# Original Unity HUD icons and resource bars.
	if assets.clock_texture:
		canvas.draw_texture_rect(assets.clock_texture, Rect2(34, 29, 32, 32), false, Color.WHITE)
	canvas.draw_rect(Rect2(85, 40, 485, 9), Color(0.65, 0.68, 0.72, 0.35), true)
	var day_progress := clampf(float(state.clock_minutes - 600) / float(1350 - 600), 0.0, 1.0)
	_draw_panel(canvas, Rect2(85, 40, maxf(0.0, 485.0 * day_progress), 8), Color("#e0df72"), Color.TRANSPARENT, 4)
	if assets.fire_texture:
		for peak in [765, 1080]:
			var flame_center := 85.0 + 485.0 * float(peak - 600) / 750.0
			canvas.draw_texture_rect(assets.fire_texture, Rect2(flame_center - 17.5, 27, 35, 35), false, Color.WHITE)
	for i in range(3):
		_draw_panel(canvas, Rect2(93 + i * 65, 118, 60, 8), Color(0.65, 0.68, 0.72, 0.35), Color.TRANSPARENT, 4)
		_draw_panel(canvas, Rect2(93 + i * 65, 196, 60, 8), Color(0.65, 0.68, 0.72, 0.35), Color.TRANSPARENT, 4)
		var slow_part := clampf(state.slow_energy / 15.0 - i, 0.0, 1.0)
		var speed_part := clampf(state.speed_energy / 20.0 - i, 0.0, 1.0)
		if slow_part > 0.0:
			_draw_panel(canvas, Rect2(93 + i * 65, 118, 60 * slow_part, 8), Color.WHITE, Color.TRANSPARENT, 4)
		if speed_part > 0.0:
			_draw_panel(canvas, Rect2(93 + i * 65, 196, 60 * speed_part, 8), Color.WHITE, Color.TRANSPARENT, 4)
	if assets.stopwatch_texture:
		canvas.draw_texture_rect(assets.stopwatch_texture, Rect2(39, 106, 32, 35), false, Color.WHITE)
	var current_weather_icon: Texture2D = assets.sunny_texture
	if assets.sunny_texture and state.weather == "晴天":
		current_weather_icon = assets.sunny_texture
	elif assets.cloudy_texture and state.weather == "多云":
		current_weather_icon = assets.cloudy_texture
	elif assets.rainy_texture and state.weather == "雨天":
		current_weather_icon = assets.rainy_texture
	elif assets.foggy_texture:
		current_weather_icon = assets.foggy_texture
	if assets.hare_texture:
		canvas.draw_texture_rect(assets.hare_texture, Rect2(35, 181, 44, 32), false, Color.WHITE)
	if current_weather_icon:
		var weather_panel := Rect2(842, 14, 87, 62)
		var weather_icon_size := Vector2(35, 35)
		canvas.draw_texture_rect(current_weather_icon, Rect2(weather_panel.get_center() - weather_icon_size * 0.5, weather_icon_size), false, Color.WHITE)
	if assets.dollar_texture:
		canvas.draw_texture_rect(assets.dollar_texture, Rect2(640, 29, 32, 32), false, Color("#ffd200"))
	else:
		canvas.draw_circle(Vector2(656, 45), 15, Color("#ffd200"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(650, 52), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#1d2530"))
	for i in range(state.capacity):
		var slot := inventory_slot_rect(i)
		_draw_panel(canvas, slot, Color("#518da0") if i < state.occupied else Color("#a3a3a3"), Color.TRANSPARENT, 7)
