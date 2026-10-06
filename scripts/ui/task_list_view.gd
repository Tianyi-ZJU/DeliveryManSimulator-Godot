extends ScrollContainer

## Task-card layout and refresh only; drag/priority decisions live in gameplay.
signal task_gui_input(event: InputEvent, index: int)
signal task_hovered(order_id: int, kind: String)
const Config := preload("res://scripts/core/game_config.gd")
const GameState := preload("res://scripts/core/game_state.gd")
const GameAssets := preload("res://scripts/presentation/game_assets.gd")
var state: GameState
var assets: GameAssets
var task_box: VBoxContainer
var last_task_signature := ""

func _init(shared_state: GameState, shared_assets: GameAssets) -> void:
	state = shared_state
	assets = shared_assets

func _ready() -> void:
	name = "TaskScroll"
	position = Vector2(960, 148)
	size = Vector2(320, 510)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	task_box = VBoxContainer.new()
	task_box.name = "TaskList"
	task_box.custom_minimum_size = Vector2(300, 0)
	task_box.add_theme_constant_override("separation", 12)
	task_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(task_box)

func refresh() -> void:
	var signature_parts: Array[String] = []
	for task in state.tasks:
		signature_parts.append("%s:%d:%d:%d" % [task["kind"], int(task["order"]["id"]), int(task["order"]["price"]), int(task["order"]["deadline"])])
	var task_signature := ",".join(signature_parts)
	if task_signature != last_task_signature:
		last_task_signature = task_signature
		for child in task_box.get_children():
			child.queue_free()
		for i in state.tasks.size():
			var task: Dictionary = state.tasks[i]
			var button := Button.new()
			button.name = "Task_%d_%s" % [int(task["order"]["id"]), task["kind"]]
			button.text = ""
			button.custom_minimum_size = Vector2(300, 88)
			button.flat = true
			button.focus_mode = Control.FOCUS_NONE
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_theme_font_size_override("font_size", 18)
			button.add_theme_color_override("font_color", Color.WHITE)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			button.gui_input.connect(task_gui_input.emit.bind(i))
			var card_style := StyleBoxFlat.new()
			card_style.bg_color = Color(0.08, 0.09, 0.12, 0.80)
			card_style.border_color = Color(0.40, 0.42, 0.45, 0.45)
			card_style.set_border_width_all(1)
			card_style.set_corner_radius_all(22)
			for style_name in ["normal", "hover", "pressed"]:
				button.add_theme_stylebox_override(style_name, card_style)
			button.flat = false
			var task_icon := TextureRect.new()
			task_icon.texture = assets.restaurant_texture if task["kind"] == "取餐" else assets.home_texture
			task_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			task_icon.position = Vector2(25, 25)
			task_icon.size = Vector2(38, 38)
			task_icon.modulate = Config.COLORS[int(task["order"]["color_index"])]
			task_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(task_icon)
			var price_label := Label.new()
			price_label.position = Vector2(93, 22)
			price_label.size = Vector2(80, 42)
			price_label.text = "$%d" % task["order"]["price"]
			price_label.add_theme_font_size_override("font_size", 28)
			price_label.add_theme_color_override("font_color", Color.WHITE)
			price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(price_label)
			var deadline_label := Label.new()
			deadline_label.position = Vector2(215, 22)
			deadline_label.size = Vector2(80, 42)
			deadline_label.text = "%02d:%02d" % [int(task["order"]["deadline"]) / 60, int(task["order"]["deadline"]) % 60]
			deadline_label.add_theme_font_size_override("font_size", 28)
			deadline_label.add_theme_color_override("font_color", Color.WHITE)
			deadline_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(deadline_label)
			task_box.add_child(button)
			button.mouse_entered.connect(task_hovered.emit.bind(int(task["order"]["id"]), "from" if task["kind"] == "取餐" else "to"))
			button.mouse_exited.connect(task_hovered.emit.bind(-1, ""))
