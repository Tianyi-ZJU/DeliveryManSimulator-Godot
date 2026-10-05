extends Node2D

## Minimal migration slice: original map data, timed orders, click-to-accept,
## pickup-before-dropoff queueing, automatic courier movement, weather modifiers,
## Shift speed boost, Ctrl time slow, original waits and paid day-end upgrades.

const MAP_PATH := "res://data/map.json"
const VISUAL_WAYPOINTS_PATH := "res://data/visual_waypoints.json"
const MAP_TEXTURE := "res://assets/background_ui.png"
const HOME_TEXTURE := "res://assets/home.png"
const RESTAURANT_TEXTURE := "res://assets/restaurant.png"
const RING_TEXTURE := "res://assets/ring.png"
const FIRE_TEXTURE := "res://assets/fire.png"
const CLOCK_TEXTURE := "res://assets/clock.png"
const STOPWATCH_TEXTURE := "res://assets/stopwatch.fill.png"
const HARE_TEXTURE := "res://assets/hare.fill.png"
const DOLLAR_TEXTURE := "res://assets/dollarsign.circle.fill.png"
const STAR_TEXTURE := "res://assets/star.png"
const ASSIGNED_TEXTURE := "res://assets/assigned.png"
const SUNNY_TEXTURE := "res://assets/sunny.png"
const CLOUDY_TEXTURE := "res://assets/cloudy.png"
const RAINY_TEXTURE := "res://assets/rainy.png"
const FOGGY_TEXTURE := "res://assets/foggy.png"
const MAP_MARGIN := Rect2(0.0, 0.0, 1280.0, 675.0)
const CAMERA_CENTER := Vector2(10.0, 5.0)
const CAMERA_HALF_HEIGHT := 50.0
const VIEW_WORLD_MIN := CAMERA_CENTER - Vector2(CAMERA_HALF_HEIGHT * 1280.0 / 675.0, CAMERA_HALF_HEIGHT)
const VIEW_WORLD_MAX := CAMERA_CENTER + Vector2(CAMERA_HALF_HEIGHT * 1280.0 / 675.0, CAMERA_HALF_HEIGHT)
const COLORS := [Color("#0a84ff"), Color("#ffd60a"), Color("#bf5af2"), Color("#ff9f0a"), Color("#32d74b"), Color("#ff00ff"), Color(0.5, 0.7, 0.039), Color(1, 0.5, 0.5), Color(0, 0.7, 0.7), Color(0.68, 0.56, 0.17), Color(0.57, 0.99, 0.95)]
const RoadGraph := preload("res://scripts/road_graph.gd")
const VisualRoadGraph := preload("res://scripts/visual_road_graph.gd")
const HUD_FONT := preload("res://assets/LiberationSans.ttf")
const EndRating := preload("res://scripts/end_rating.gd")
var road_graph := RoadGraph.new()
var visual_road_graph := VisualRoadGraph.new()

var map_data: Dictionary = {}
var waypoints: Array = []
var roads: Array = []
var runtime_waypoints: Array = []
var vertex_min := VIEW_WORLD_MIN
var vertex_max := VIEW_WORLD_MAX
var map_texture: Texture2D
var home_texture: Texture2D
var restaurant_texture: Texture2D
var ring_texture: Texture2D
var fire_texture: Texture2D
var clock_texture: Texture2D
var stopwatch_texture: Texture2D
var hare_texture: Texture2D
var dollar_texture: Texture2D
var star_texture: Texture2D
var assigned_texture: Texture2D
var sunny_texture: Texture2D
var cloudy_texture: Texture2D
var rainy_texture: Texture2D
var foggy_texture: Texture2D

var day := 1
var clock_minutes := 10 * 60
var clock_accumulator := 0.0
var minute_seconds := 0.2
var money := 100
var capacity := 3
var occupied := 0
var courier_speed := 11.0
var speed_energy := 20.0
var slow_energy := 15.0
var speed_energy_max := 20.0
var slow_energy_max := 15.0
var upgrades_remaining := {"speed": 2, "capacity": 2, "speed_energy": 2, "slow_energy": 2}
var purchases_left := 2
var finished_count := 0
var late_count := 0
var failed_count := 0
var wait_order: Dictionary = {}
var wait_until := 0
var weather := "晴天"
var weather_speed_factor := 1.0
var weather_price_bonus := 0
var next_order_id := 0
var orders: Array = []
var tasks: Array = []
var courier_pos := Vector2.ZERO
var courier_target := -1
var courier_target_kind := ""
var courier_route: Array[Vector2] = []
var courier_route_index := 0
var generated_timer := 3.0
var notification := "点击餐厅图标接单"
var notification_timer := 4.0
var last_result := ""
var upgrade_visible := false
var game_finished := false
var end_panel: PanelContainer
var hover_order_id := -1
var hover_kind := ""
var last_task_signature := ""
var task_drag_index := -1
var task_drag_origin := Vector2.ZERO
var task_dragged := false

var time_label: Label
var stats_label: Label
var weather_label: Label
var task_box: VBoxContainer
var notification_label: Label
var upgrade_panel: Panel
var hud_layer: Control
var money_label: Label
var weather_value_label: Label
var energy_label: Label

func _ready() -> void:
	map_data = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	if map_data.is_empty():
		map_data = {"waypoints": [], "roads": []}
	waypoints = map_data.get("waypoints", [])
	roads = map_data.get("roads", [])
	runtime_waypoints = waypoints.duplicate(true)
	var visual_waypoint_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(VISUAL_WAYPOINTS_PATH))
	if visual_waypoint_data is Dictionary and visual_waypoint_data.get("waypoints", []).size() == waypoints.size():
		runtime_waypoints = visual_waypoint_data["waypoints"]
	map_texture = load(MAP_TEXTURE)
	home_texture = load(HOME_TEXTURE)
	restaurant_texture = load(RESTAURANT_TEXTURE)
	ring_texture = load(RING_TEXTURE)
	fire_texture = load(FIRE_TEXTURE)
	clock_texture = load(CLOCK_TEXTURE)
	stopwatch_texture = load(STOPWATCH_TEXTURE)
	hare_texture = load(HARE_TEXTURE)
	dollar_texture = load(DOLLAR_TEXTURE)
	star_texture = load(STAR_TEXTURE)
	assigned_texture = load(ASSIGNED_TEXTURE)
	sunny_texture = load(SUNNY_TEXTURE)
	cloudy_texture = load(CLOUDY_TEXTURE)
	rainy_texture = load(RAINY_TEXTURE)
	foggy_texture = load(FOGGY_TEXTURE)
	road_graph.build(map_data)
	visual_road_graph.load_mask()
	courier_pos = Vector2(-24.7, -39.8)
	_choose_weather()
	_build_ui()
	_set_notification("点击带黄色标记的餐厅接单")
	queue_redraw()

func _runtime_waypoint(point_id: int) -> Dictionary:
	return runtime_waypoints[point_id].duplicate()

func _choose_weather() -> void:
	if day == 1:
		weather = "晴天"
		weather_speed_factor = 1.0
		weather_price_bonus = 0
		return
	var roll := randi_range(0, 99)
	weather = "多云" if roll < 28 else ("雨天" if roll < 56 else ("雾天" if roll < 84 else "晴天"))
	weather_speed_factor = 0.77 if weather == "雨天" else (0.88 if weather == "雾天" else 1.0)
	weather_price_bonus = 17 if weather == "雨天" else 0

func _build_ui() -> void:
	hud_layer = Control.new()
	hud_layer.name = "OriginalStyleHUD"
	var hud_theme := Theme.new()
	hud_theme.default_font = HUD_FONT
	hud_layer.theme = hud_theme
	hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_layer)
	stats_label = Label.new()
	stats_label.position = Vector2(82, 101)
	stats_label.size = Vector2(220, 40)
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color.WHITE)
	stats_label.visible = false
	hud_layer.add_child(stats_label)
	energy_label = Label.new()
	energy_label.position = Vector2(82, 178)
	energy_label.size = Vector2(220, 40)
	energy_label.add_theme_font_size_override("font_size", 18)
	energy_label.add_theme_color_override("font_color", Color.WHITE)
	energy_label.visible = false
	hud_layer.add_child(energy_label)
	time_label = Label.new()
	time_label.position = Vector2(728, 25)
	time_label.size = Vector2(84, 38)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 22)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	hud_layer.add_child(time_label)
	money_label = Label.new()
	money_label.name = "Money"
	money_label.position = Vector2(730, 25)
	money_label.size = Vector2(82, 38)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 30)
	money_label.add_theme_color_override("font_color", Color.WHITE)
	hud_layer.add_child(money_label)
	weather_value_label = Label.new()
	weather_value_label.position = Vector2(1075, 26)
	weather_value_label.size = Vector2(150, 38)
	weather_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_value_label.add_theme_font_size_override("font_size", 18)
	weather_value_label.add_theme_color_override("font_color", Color.WHITE)
	weather_value_label.visible = false
	hud_layer.add_child(weather_value_label)
	weather_label = Label.new()
	weather_label.visible = false
	hud_layer.add_child(weather_label)
	var task_scroll := ScrollContainer.new()
	task_scroll.name = "TaskScroll"
	task_scroll.position = Vector2(960, 148)
	task_scroll.size = Vector2(320, 510)
	task_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud_layer.add_child(task_scroll)
	task_box = VBoxContainer.new()
	task_box.name = "TaskList"
	task_box.custom_minimum_size = Vector2(300, 0)
	task_box.add_theme_constant_override("separation", 12)
	task_box.mouse_filter = Control.MOUSE_FILTER_PASS
	task_scroll.add_child(task_box)
	notification_label = Label.new()
	notification_label.name = "Notification"
	notification_label.position = Vector2(24, 627)
	notification_label.size = Vector2(900, 36)
	notification_label.add_theme_font_size_override("font_size", 16)
	notification_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	hud_layer.add_child(notification_label)

func _process(delta: float) -> void:
	if upgrade_visible or game_finished:
		queue_redraw()
		return
	var time_factor := 1.0
	if Input.is_action_pressed("time_slow") and slow_energy > 0.0:
		time_factor = 0.2
		slow_energy = maxf(0.0, slow_energy - delta * 10.0 * time_factor)
	slow_energy = minf(slow_energy_max, slow_energy + delta * time_factor * 0.15)
	clock_accumulator += delta * time_factor
	while clock_accumulator >= minute_seconds:
		clock_accumulator -= minute_seconds
		clock_minutes += 1
		if clock_minutes >= 21 * 60 and tasks.is_empty() and orders.is_empty():
			_finish_day()
			return
	if Input.is_action_pressed("speed_up") and speed_energy > 0.0 and not courier_route.is_empty():
		speed_energy = maxf(0.0, speed_energy - delta * 5.0 * time_factor)
	speed_energy = minf(speed_energy_max, speed_energy + delta * time_factor * 20.0 / 60.0)
	if not wait_order.is_empty() and clock_minutes >= wait_until:
		wait_order.clear()
		_set_notification("餐厅出餐了，继续送达")
	_update_orders(delta * time_factor)
	if clock_minutes >= 21 * 60 and tasks.is_empty() and orders.is_empty():
		_finish_day()
		return
	_update_courier(delta * time_factor)
	generated_timer -= delta * time_factor
	if generated_timer <= 0.0 and clock_minutes < 19 * 60:
		_generate_order()
		var round_index := mini(day - 1, 4)
		var peak := (clock_minutes >= 690 and clock_minutes <= 840) or (clock_minutes >= 1020 and clock_minutes <= 1140)
		var extra_probability: int = [30, 35, 38, 40, 45][round_index] if peak else 17 + round_index * 2
		if randi_range(0, 99) < extra_probability:
			_generate_order()
		var intervals: Array = [3.7, 3.2, 3.0, 2.8, 2.5] if peak else [5.0, 4.6, 4.2, 3.9, 3.6]
		generated_timer = float(intervals[round_index]) + randf_range(-0.7, 0.7)
	if notification_timer > 0.0:
		notification_timer -= delta
	_update_ui()
	queue_redraw()

func _update_orders(delta: float) -> void:
	for order in orders.duplicate():
		if order["state"] == "available":
			order["accept_timer"] -= delta
			if order["accept_timer"] <= 0.0:
				if int(order["level"]) == 4:
					money -= int(order["price"])
				orders.erase(order)
				_set_notification("有一笔订单因等待接单超时消失")
		elif order["state"] == "accepted" or order["state"] == "picked_up":
			if clock_minutes > order["deadline"] and not order["late"]:
				order["late"] = true
				money -= int(order["price"] / 2)
				late_count += 1
				_set_notification("订单超时，收入减少")
			if clock_minutes > int(order["deadline"]) + int(order["duration"]) / 2:
				money -= int(order["price"]) * (2 if int(order["level"]) == 4 else 1)
				occupied = maxi(0, occupied - 1)
				failed_count += 1
				for task in tasks.duplicate():
					if task["order"] == order:
						tasks.erase(task)
				if courier_target == int(order["from"]["id"]) or courier_target == int(order["to"]["id"]):
					courier_route.clear()
				if wait_order == order:
					wait_order.clear()
				orders.erase(order)
				_set_notification("订单严重超时，已取消并释放背包")

func _update_courier(delta: float) -> void:
	if not wait_order.is_empty():
		return
	if courier_route.is_empty() or courier_route_index >= courier_route.size():
		return
	var target := courier_route[courier_route_index]
	var boost := 2.4 if Input.is_action_pressed("speed_up") and speed_energy > 0.0 else 1.0
	courier_pos = courier_pos.move_toward(target, courier_speed * weather_speed_factor * boost * delta)
	if courier_pos.distance_to(target) < 0.18:
		courier_route_index += 1
		if courier_route_index >= courier_route.size():
			_arrive_at_target()

func _generate_order() -> void:
	if upgrade_visible:
		return
	var restaurants: Array = []
	var customers: Array = []
	for point in waypoints:
		var busy := false
		for order in orders:
			if point["id"] == order["from"]["id"] or point["id"] == order["to"]["id"]:
				busy = true
				break
		if busy:
			continue
		if point.get("restaurant", false):
			restaurants.append(point)
		else:
			customers.append(point)
	if restaurants.is_empty() or customers.is_empty():
		return
	var pairs: Array = []
	for from in restaurants:
		for to in customers:
			var distance := Vector2(float(from["x"]), float(from["y"])).distance_to(Vector2(float(to["x"]), float(to["y"])))
			if from["road"] != to["road"] and distance >= 15.0 and distance <= 70.0:
				pairs.append([from, to])
	if pairs.is_empty():
		return
	var pair: Array = pairs.pick_random()
	var thresholds: Array = [[70, 99, 100, 100], [65, 92, 98, 100], [55, 81, 93, 96], [50, 75, 88, 92], [45, 68, 83, 89]][mini(day - 1, 4)]
	var roll := randi_range(0, 99)
	var level := 5
	for i in thresholds.size():
		if roll < int(thresholds[i]):
			level = i + 1
			break
	var price_ranges: Array = [[25, 49], [40, 69], [60, 99], [40, 69], [120, 149]]
	var price_range: Array = price_ranges[level - 1]
	var price := randi_range(int(price_range[0]), int(price_range[1])) + weather_price_bonus
	var duration: int = [120, randi_range(105, 119), randi_range(90, 104), 105, randi_range(100, 114)][level - 1]
	create_order(int(pair[0]["id"]), int(pair[1]["id"]), level, price, duration)
	_set_notification("新订单：点击餐厅或住宅图标接单")

func create_order(from_id: int, to_id: int, level: int, price: int, duration: int = 120, color_index: int = -1) -> Dictionary:
	var lifetime := 4.0 if weather == "雾天" else (2.3 if weather == "多云" else 3.0)
	if level == 4:
		lifetime += 2.0
	elif level == 5:
		lifetime = 0.9 if weather == "多云" else lifetime - 1.8
	if color_index < 0:
		color_index = next_order_id % COLORS.size()
		for unused in COLORS.size():
			var taken := false
			for existing in orders:
				if int(existing["color_index"]) == color_index:
					taken = true
			if not taken:
				break
			color_index = (color_index + 1) % COLORS.size()
	var order: Dictionary = {"id": next_order_id, "from": _runtime_waypoint(from_id), "to": _runtime_waypoint(to_id), "level": level, "price": price, "state": "available", "accept_timer": lifetime, "lifetime": lifetime, "deadline": clock_minutes + duration, "duration": duration, "accepted_at": clock_minutes, "late": false, "color_index": color_index}
	next_order_id += 1
	orders.append(order)
	return order

func _unhandled_input(event: InputEvent) -> void:
	if game_finished:
		return
	if upgrade_visible:
		if event.is_action_pressed("urge"):
			_start_next_day()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		_show_end()
		return
	if event.is_action_pressed("urge"):
		if not wait_order.is_empty():
			wait_until -= 2
			_set_notification("已催餐，等待减少 2 分钟")
		elif clock_minutes >= 19 * 60 and orders.is_empty():
			_finish_day()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for order in orders:
			for kind in ["from", "to"]:
				if kind == "from" and order["state"] == "picked_up":
					continue
				var point: Dictionary = order[kind]
				if _world_to_screen(Vector2(float(point["x"]), float(point["y"]))).distance_to(event.position) < 21.0:
					if order["state"] == "available":
						_accept_order_at(order["from"])
					else:
						for i in tasks.size():
							if tasks[i]["order"] == order and tasks[i]["kind"] == ("取餐" if kind == "from" else "送达"):
								_prioritize(i)
								break
					return

func _accept_order_at(point: Dictionary) -> void:
	if occupied >= capacity:
		_set_notification("容量已满，请先完成一单或升级背包")
		return
	for order in orders:
		if order["state"] == "available" and int(order["from"]["id"]) == int(point["id"]):
			order["state"] = "accepted"
			order["accepted_at"] = clock_minutes
			occupied += 1
			tasks.append({"order": order, "kind": "取餐"})
			tasks.append({"order": order, "kind": "送达"})
			_begin_next_task()
			_set_notification("已接单：先取餐，再送达")
			return
	_set_notification("这里暂时没有可接订单")

func _prioritize(index: int) -> void:
	if index <= 0 or index >= tasks.size():
		return
	var task: Dictionary = tasks[index]
	if task["kind"] == "送达" and _has_unfinished_pickup(task["order"]):
		_set_notification("必须先取餐，不能把送达排到取餐前")
		return
	tasks.remove_at(index)
	tasks.push_front(task)
	courier_route.clear()
	_begin_next_task()
	_set_notification("任务已置顶")

func _move_task(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= tasks.size() or to_index < 0 or to_index >= tasks.size():
		return false
	var reordered: Array = tasks.duplicate()
	var task: Dictionary = reordered.pop_at(from_index)
	reordered.insert(to_index, task)
	for i in reordered.size():
		if reordered[i]["kind"] == "送达":
			for j in range(i + 1, reordered.size()):
				if reordered[j]["kind"] == "取餐" and reordered[j]["order"] == reordered[i]["order"]:
					_set_notification("必须先取餐，再送达")
					return false
	var previous_first: Dictionary = tasks[0]
	tasks = reordered
	if tasks[0] != previous_first:
		courier_route.clear()
		_begin_next_task()
	_update_ui()
	return true

func _task_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		task_drag_index = index
		task_drag_origin = event.global_position
		task_dragged = false

func _input(event: InputEvent) -> void:
	# Capture release globally so dragging outside the original card also works.
	if event is InputEventMouseMotion:
		if task_drag_index >= 0 and event.global_position.distance_to(task_drag_origin) > 8.0:
			task_dragged = true
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and task_drag_index >= 0:
		var from_index := task_drag_index
		task_drag_index = -1
		if task_dragged:
			var target := clampi(int((event.global_position.y - task_box.global_position.y) / 100.0), 0, tasks.size() - 1)
			_move_task(from_index, target)
		else:
			_prioritize(from_index)
		task_dragged = false
		get_viewport().set_input_as_handled()

func _update_hover(mouse: Vector2) -> void:
	hover_order_id = -1
	hover_kind = ""
	if mouse.x < 940 and not upgrade_visible and not game_finished:
		for order in orders:
			for kind in ["from", "to"]:
				if kind == "from" and order["state"] == "picked_up" and wait_order != order:
					continue
				var point: Dictionary = order[kind]
				if _world_to_screen(Vector2(float(point["x"]), float(point["y"]))).distance_to(mouse) < 21:
					hover_order_id = int(order["id"])
					hover_kind = kind
	queue_redraw()

func _has_unfinished_pickup(order: Dictionary) -> bool:
	for task in tasks:
		if task["order"] == order and task["kind"] == "取餐":
			return true
	return false

func _begin_next_task() -> void:
	if tasks.is_empty() or not courier_route.is_empty() or not wait_order.is_empty():
		return
	var task: Dictionary = tasks[0]
	var point: Dictionary = task["order"]["from"] if task["kind"] == "取餐" else task["order"]["to"]
	courier_target = int(point["id"])
	courier_target_kind = task["kind"]
	var visual_route: Array[Vector2] = visual_road_graph.route_from(courier_pos, Vector2(float(point["x"]), float(point["y"])))
	courier_route = visual_route if not visual_route.is_empty() else road_graph.route_from(courier_pos, int(point["id"]))
	courier_route_index = 0
	if courier_route.is_empty() and courier_pos.distance_to(Vector2(float(point["x"]), float(point["y"]))) < 0.2:
		_arrive_at_target()

func _arrive_at_target() -> void:
	if tasks.is_empty():
		courier_route.clear()
		return
	var task: Dictionary = tasks.pop_front()
	var order: Dictionary = task["order"]
	if task["kind"] == "取餐":
		order["state"] = "picked_up"
		_set_notification("已取餐，正在前往客户")
		var threshold := pickup_wait_probability(int(order["level"]))
		if randi_range(0, 99) < threshold:
			wait_order = order
			wait_until = clock_minutes + 17 + 3 * (day - 1)
			_set_notification("餐厅还没出餐，按空格催餐")
	else:
		order["state"] = "delivered"
		var level := int(order["level"])
		var event_roll := randi_range(0, 99)
		var late_probabilities: Array = [6, 25, 40, 70, 50]
		var ontime_probabilities: Array = [20, 15, 7, 2, 1]
		if order["late"] and event_roll < int(late_probabilities[level - 1]):
			order["price"] = int(order["price"] * 2 / 3)
		elif not order["late"] and event_roll < int(ontime_probabilities[level - 1]):
			order["price"] = int(order["price"] * 4 / 3)
		money += int(order["price"])
		finished_count += 1
		occupied = max(0, occupied - 1)
		orders.erase(order)
		_set_notification("已送达，收入 +$%d" % int(order["price"]))
	courier_route.clear()
	_begin_next_task()

func pickup_wait_probability(level: int) -> int:
	var thresholds: Array = [[0, 0, 0, 0], [5, 7, 13, 2], [8, 12, 17, 4], [10, 14, 20, 5], [12, 15, 22, 6]][mini(day - 1, 4)]
	return int(thresholds[mini(level - 1, 3)])

func _finish_day() -> void:
	if day >= 5:
		_show_end()
	else:
		_show_upgrade()

func _show_upgrade() -> void:
	if upgrade_visible:
		return
	upgrade_visible = true
	purchases_left = 2
	var overlay := ColorRect.new()
	overlay.name = "UpgradeOverlay"
	overlay.color = Color(0.02, 0.04, 0.08, 0.92)
	overlay.size = MAP_MARGIN.size
	add_child(overlay)
	upgrade_panel = Panel.new()
	upgrade_panel.name = "UpgradePanel"
	upgrade_panel.position = Vector2(240, 190)
	upgrade_panel.size = Vector2(480, 410)
	add_child(upgrade_panel)
	var box := VBoxContainer.new()
	box.position = Vector2(28, 24)
	box.size = Vector2(424, 180)
	box.add_theme_constant_override("separation", 12)
	upgrade_panel.add_child(box)
	var label := Label.new()
	label.text = "日末升级 / 第 %d 天完成" % day
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	box.add_child(label)
	var info := Label.new()
	info.text = "每项 $100，每天最多购买两项"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	for option in [{"text":"速度 +4", "type":"speed"}, {"text":"容量 +1", "type":"capacity"}, {"text":"加速能量 +20", "type":"speed_energy"}, {"text":"慢时能量 +15", "type":"slow_energy"}]:
		var button := Button.new()
		button.text = option["text"]
		button.pressed.connect(_purchase.bind(option["type"]))
		box.add_child(button)
	var next_day := Button.new()
	next_day.text = "开始下一天"
	next_day.pressed.connect(_start_next_day)
	box.add_child(next_day)

func _purchase(kind: String) -> void:
	if money < 100 or purchases_left <= 0 or int(upgrades_remaining[kind]) <= 0:
		_set_notification("资金不足或升级次数已用完")
		return
	money -= 100
	purchases_left -= 1
	upgrades_remaining[kind] -= 1
	if kind == "speed":
		courier_speed += 4.0
	elif kind == "capacity":
		capacity += 1
	elif kind == "speed_energy":
		speed_energy_max += 20.0
	else:
		slow_energy_max += 15.0
	_update_ui()
	if purchases_left == 0:
		_start_next_day()

func _start_next_day() -> void:
	if game_finished or day >= 5:
		return
	day += 1
	clock_minutes = 10 * 60
	clock_accumulator = 0.0
	orders.clear()
	tasks.clear()
	occupied = 0
	courier_pos = Vector2(-24.7, -39.8)
	courier_route.clear()
	wait_order.clear()
	speed_energy = speed_energy_max
	slow_energy = slow_energy_max
	generated_timer = 3.0
	_choose_weather()
	upgrade_visible = false
	if upgrade_panel:
		var overlay := get_node_or_null("UpgradeOverlay")
		if overlay: overlay.queue_free()
		upgrade_panel.queue_free()
	_set_notification("第 %d 天开始：%s" % [day, weather])
	_update_ui()

func _show_end() -> void:
	if game_finished:
		return
	game_finished = true
	courier_route.clear()
	end_panel = PanelContainer.new()
	end_panel.name = "EndSummary"
	end_panel.position = Vector2(350, 130)
	end_panel.size = Vector2(580, 430)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	end_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	for line in ["Delivery Man Simulator", "You Have Earned: $%d" % money, "Finished Order: %d" % finished_count, "Late Order: %d" % late_count, "Bad Order: %d" % failed_count, "Rank: " + EndRating.calculate(money, late_count, failed_count)]:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		box.add_child(label)
	var restart := Button.new()
	restart.name = "Restart"
	restart.text = "Start a New Game"
	restart.pressed.connect(_restart_game)
	box.add_child(restart)
	add_child(end_panel)
	queue_redraw()

func _restart_game() -> void:
	day = 1
	clock_minutes = 600
	clock_accumulator = 0.0
	money = 100
	capacity = 3
	occupied = 0
	courier_speed = 10.0 # Unity Reset uses 10; first launch uses 11.
	speed_energy_max = 20.0
	slow_energy_max = 15.0
	speed_energy = speed_energy_max
	slow_energy = slow_energy_max
	upgrades_remaining = {"speed": 2, "capacity": 2, "speed_energy": 2, "slow_energy": 2}
	purchases_left = 2
	finished_count = 0
	late_count = 0
	failed_count = 0
	orders.clear()
	tasks.clear()
	wait_order.clear()
	courier_route.clear()
	courier_pos = Vector2(-24.7, -39.8)
	next_order_id = 0
	generated_timer = 3.0
	game_finished = false
	upgrade_visible = false
	if is_instance_valid(end_panel):
		end_panel.queue_free()
	_choose_weather()
	_update_ui()

func _update_ui() -> void:
	if not stats_label:
		return
	var moving := "移动中" if not courier_route.is_empty() else "待命"
	stats_label.text = "%d / %d" % [occupied, capacity]
	energy_label.text = "%d%%" % int(speed_energy / speed_energy_max * 100.0)
	money_label.text = "%d" % money
	time_label.text = ""
	weather_value_label.text = weather
	weather_label.text = "天气：%s 速度 %.0f%%" % [weather, weather_speed_factor * 100.0]
	notification_label.text = notification if notification_timer > 0.0 else ""
	var signature_parts: Array[String] = []
	for task in tasks:
		signature_parts.append("%s:%d:%d:%d" % [task["kind"], int(task["order"]["id"]), int(task["order"]["price"]), int(task["order"]["deadline"])])
	var task_signature := ",".join(signature_parts)
	if task_signature != last_task_signature:
		last_task_signature = task_signature
		for child in task_box.get_children():
			child.queue_free()
		for i in tasks.size():
			var task: Dictionary = tasks[i]
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
			button.gui_input.connect(_task_gui_input.bind(i))
			var card_style := StyleBoxFlat.new()
			card_style.bg_color = Color(0.08, 0.09, 0.12, 0.80)
			card_style.border_color = Color(0.40, 0.42, 0.45, 0.45)
			card_style.set_border_width_all(1)
			card_style.set_corner_radius_all(22)
			for state in ["normal", "hover", "pressed"]:
				button.add_theme_stylebox_override(state, card_style)
			button.flat = false
			var task_icon := TextureRect.new()
			task_icon.texture = restaurant_texture if task["kind"] == "取餐" else home_texture
			task_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			task_icon.position = Vector2(25, 25)
			task_icon.size = Vector2(38, 38)
			task_icon.modulate = COLORS[int(task["order"]["color_index"])]
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
			button.mouse_entered.connect(_hover_task.bind(int(task["order"]["id"]), "from" if task["kind"] == "取餐" else "to"))
			button.mouse_exited.connect(_hover_task.bind(-1, ""))
	_begin_next_task()
	queue_redraw()

func _set_notification(message: String) -> void:
	notification = message
	notification_timer = 3.0

func _hover_task(order_id: int, kind: String) -> void:
	hover_order_id = order_id
	hover_kind = kind
	queue_redraw()

func _world_to_screen(world: Vector2) -> Vector2:
	var normalized := Vector2((world.x - vertex_min.x) / (vertex_max.x - vertex_min.x), 1.0 - (world.y - vertex_min.y) / (vertex_max.y - vertex_min.y))
	return MAP_MARGIN.position + normalized * MAP_MARGIN.size

func _screen_to_world(screen: Vector2) -> Vector2:
	var normalized := (screen - MAP_MARGIN.position) / MAP_MARGIN.size
	return Vector2(lerpf(vertex_min.x, vertex_max.x, normalized.x), lerpf(vertex_max.y, vertex_min.y, normalized.y))

func _draw() -> void:
	draw_rect(MAP_MARGIN, Color("#243246"))
	if map_texture:
		var world_size := map_texture.get_size() / 10.0 * Vector2(1.1939985, 1.183636)
		var center := Vector2(9.2519, -9.3247)
		var top_left := _world_to_screen(center + Vector2(-world_size.x, world_size.y) * 0.5)
		draw_texture_rect(map_texture, Rect2(top_left, world_size * MAP_MARGIN.size.y / (2.0 * CAMERA_HALF_HEIGHT)), false)
	if not courier_route.is_empty() and courier_route_index < courier_route.size():
		var route_points := PackedVector2Array([_world_to_screen(courier_pos)])
		for i in range(courier_route_index, courier_route.size()):
			route_points.append(_world_to_screen(courier_route[i]))
		draw_polyline(route_points, Color.YELLOW, 2.1, true)
	for order in orders:
		var tint: Color = COLORS[int(order["color_index"])]
		for kind in ["from", "to"]:
			if kind == "from" and order["state"] == "picked_up" and wait_order != order:
				continue
			var point: Dictionary = order[kind]
			var pos := _world_to_screen(Vector2(float(point["x"]), float(point["y"])))
			var icon: Texture2D = restaurant_texture if kind == "from" else home_texture
			var icon_size := Vector2.ONE * (32.0 if kind == "from" else 38.0)
			var scale_factor := 1.0
			if int(order["id"]) == hover_order_id and kind == hover_kind:
				scale_factor = 1.5 if (order["state"] == "available") == (kind == "from") else 1.9
				icon_size *= scale_factor
			if icon:
				draw_texture_rect(icon, Rect2(pos - icon_size * 0.5, icon_size), false, tint)
			if kind == "from" and order["state"] == "available":
				var level := int(order["level"])
				if level <= 3 and star_texture:
					for star_index in level:
						var offset := Vector2((star_index - (level - 1) * 0.5) * 11.0, -25.0)
						draw_texture_rect(star_texture, Rect2(pos + offset - Vector2(5, 5), Vector2(10, 10)), false, tint)
				else:
					var badge: Texture2D = assigned_texture if level == 4 else fire_texture
					if badge:
						draw_texture_rect(badge, Rect2(pos + Vector2(-24, -30), Vector2(18, 18)), false, tint)
			var progress := 0.0
			var ring_color := tint
			if kind == "from" and wait_order == order:
				progress = clampf(float(wait_until - clock_minutes) / float(17 + 3 * (day - 1)), 0.0, 1.0)
				ring_color = Color.RED
			elif order["state"] == "available" and kind == "from":
				progress = float(order["accept_timer"]) / float(order["lifetime"])
			elif order["state"] != "available" and kind == "to":
				progress = clampf(float(order["deadline"] - clock_minutes) / maxf(1.0, float(order["deadline"] - order["accepted_at"])), 0.0, 1.0)
				if order["late"]:
					ring_color = Color.RED
					progress = clampf(float(clock_minutes - order["deadline"]) / (float(order["duration"]) / 2.0), 0.0, 1.0)
			if progress > 0.0:
				draw_arc(pos, 18.0 * scale_factor, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, ring_color, 2.0, true)
	var courier_screen := _world_to_screen(courier_pos)
	draw_circle(courier_screen, 10.0, Color("#dddddd"))
	draw_circle(courier_screen, 7.5, Color("#499bd6"))
	_draw_original_hud()
	if game_finished:
		draw_rect(MAP_MARGIN, Color(0.02, 0.04, 0.08, 0.85))

func prepare_input_regression() -> void:
	# Deterministic state used only by regression drivers; normal boot stays random.
	set_process(false)
	orders.clear()
	tasks.clear()
	courier_route.clear()
	occupied = 0
	hover_order_id = -1
	hover_kind = ""
	clock_minutes = 637
	create_order(14, 21, 1, 46, 120, 1)
	courier_pos = Vector2(-24.7, -35.0)
	_update_ui()
	notification_label.text = ""
	queue_redraw()

func prepare_visual_regression() -> void:
	prepare_input_regression()
	_accept_order_at(orders[0]["from"])
	_update_ui()
	notification_label.text = ""
	queue_redraw()

func regression_snapshot() -> Dictionary:
	return {"waypoints": waypoints.size(), "roads": roads.size(), "orders": orders.size(), "tasks": tasks.size(), "occupied": occupied, "capacity": capacity, "money": money, "route_points": courier_route.size(), "courier": {"x": courier_pos.x, "y": courier_pos.y}}

func _draw_panel(rect: Rect2, background: Color, border: Color = Color(0.55, 0.58, 0.63, 0.45), radius: int = 24) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(0 if border.a == 0.0 else 2)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _draw_original_hud() -> void:
	var panel := Color(0.18, 0.21, 0.27, 0.78)
	_draw_panel(Rect2(20, 14, 590, 62), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(Rect2(20, 92, 300, 60), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(Rect2(20, 170, 300, 60), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(Rect2(624, 14, 198, 62), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(Rect2(842, 14, 87, 62), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(Rect2(940, 8, 340, 105), panel, Color(0.52, 0.55, 0.60, 0.5), 28)
	_draw_panel(Rect2(940, 130, 340, 537), Color(0.40, 0.43, 0.47, 0.32), Color(0.72, 0.75, 0.78, 0.55), 28)
	# Original Unity HUD icons and resource bars.
	if clock_texture:
		draw_texture_rect(clock_texture, Rect2(34, 29, 32, 32), false, Color.WHITE)
	draw_rect(Rect2(85, 40, 485, 9), Color(0.65, 0.68, 0.72, 0.35), true)
	var day_progress := clampf(float(clock_minutes - 600) / float(1350 - 600), 0.0, 1.0)
	_draw_panel(Rect2(85, 40, maxf(0.0, 485.0 * day_progress), 8), Color("#e0df72"), Color.TRANSPARENT, 4)
	if fire_texture:
		for peak in [765, 1080]:
			var flame_center := 85.0 + 485.0 * float(peak - 600) / 750.0
			draw_texture_rect(fire_texture, Rect2(flame_center - 17.5, 27, 35, 35), false, Color.WHITE)
	for i in range(3):
		_draw_panel(Rect2(93 + i * 65, 118, 60, 8), Color(0.65, 0.68, 0.72, 0.35), Color.TRANSPARENT, 4)
		_draw_panel(Rect2(93 + i * 65, 196, 60, 8), Color(0.65, 0.68, 0.72, 0.35), Color.TRANSPARENT, 4)
		var slow_part := clampf(slow_energy / 15.0 - i, 0.0, 1.0)
		var speed_part := clampf(speed_energy / 20.0 - i, 0.0, 1.0)
		if slow_part > 0.0:
			_draw_panel(Rect2(93 + i * 65, 118, 60 * slow_part, 8), Color.WHITE, Color.TRANSPARENT, 4)
		if speed_part > 0.0:
			_draw_panel(Rect2(93 + i * 65, 196, 60 * speed_part, 8), Color.WHITE, Color.TRANSPARENT, 4)
	if stopwatch_texture:
		draw_texture_rect(stopwatch_texture, Rect2(39, 106, 32, 35), false, Color.WHITE)
	var current_weather_icon: Texture2D = sunny_texture
	if sunny_texture and weather == "晴天":
		current_weather_icon = sunny_texture
	elif cloudy_texture and weather == "多云":
		current_weather_icon = cloudy_texture
	elif rainy_texture and weather == "雨天":
		current_weather_icon = rainy_texture
	elif foggy_texture:
		current_weather_icon = foggy_texture
	if hare_texture:
		draw_texture_rect(hare_texture, Rect2(35, 181, 44, 32), false, Color.WHITE)
	if current_weather_icon:
		var weather_panel := Rect2(842, 14, 87, 62)
		var weather_icon_size := Vector2(35, 35)
		draw_texture_rect(current_weather_icon, Rect2(weather_panel.get_center() - weather_icon_size * 0.5, weather_icon_size), false, Color.WHITE)
	if dollar_texture:
		draw_texture_rect(dollar_texture, Rect2(640, 29, 32, 32), false, Color("#ffd200"))
	else:
		draw_circle(Vector2(656, 45), 15, Color("#ffd200"))
		draw_string(ThemeDB.fallback_font, Vector2(650, 52), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#1d2530"))
	for i in range(capacity):
		var slot := Rect2(967 + (i % 2) * 38, 29 + (i / 2) * 38, 30, 30)
		_draw_panel(slot, Color("#518da0") if i < occupied else Color("#a3a3a3"), Color.TRANSPARENT, 7)
