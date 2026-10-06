extends RefCounted

## Orders, task ordering, restaurant waits and payment/penalty rules.
## Route requests are signals: this system has no courier or UI dependency.
signal feedback(event: StringName, values: Dictionary)
signal cue_requested(cue: StringName)
signal introduction_requested(event: StringName)
signal route_requested()
signal changed()

const GameState := preload("res://scripts/core/game_state.gd")
const MapModel := preload("res://scripts/gameplay/map_model.gd")
const Config := preload("res://scripts/core/game_config.gd")
var state: GameState
var map_model: MapModel

func _init(shared_state: GameState, shared_map: MapModel) -> void:
	state = shared_state
	map_model = shared_map

func _notify(event: StringName, values: Dictionary = {}) -> void:
	feedback.emit(event, values)

func update(delta: float) -> void:
	for order in state.orders.duplicate():
		if order["state"] == "available":
			order["accept_timer"] -= delta
			if order["accept_timer"] <= 0.0:
				if int(order["level"]) == 4:
					state.money -= int(order["price"])
					cue_requested.emit(&"late")
					_notify(&"assigned_missed", {"amount": int(order["price"])})
				state.orders.erase(order)
		elif order["state"] == "accepted" or order["state"] == "picked_up":
			if state.clock_minutes > order["deadline"] and not order["late"]:
				order["late"] = true
				state.money -= int(order["price"] / 2)
				state.late_count += 1
				cue_requested.emit(&"late")
				_notify(&"late", {"amount": int(order["price"] / 2)})
			if state.clock_minutes > int(order["deadline"]) + int(order["duration"]) / 2:
				state.money -= int(order["price"]) * (2 if int(order["level"]) == 4 else 1)
				state.occupied = maxi(0, state.occupied - 1)
				state.failed_count += 1
				for task in state.tasks.duplicate():
					if task["order"] == order:
						state.tasks.erase(task)
				if state.courier_target == int(order["from"]["id"]) or state.courier_target == int(order["to"]["id"]):
					state.courier_route.clear()
				if state.wait_order == order:
					state.wait_order = {}
				state.orders.erase(order)
				_notify(&"cancelled", {"amount": int(order["price"]) * (2 if int(order["level"]) == 4 else 1)})

func generate() -> void:
	if state.upgrade_visible:
		return
	var restaurants: Array = []
	var customers: Array = []
	for point in map_model.waypoints:
		var busy := false
		for order in state.orders:
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
	var thresholds: Array = [[70, 99, 100, 100], [65, 92, 98, 100], [55, 81, 93, 96], [50, 75, 88, 92], [45, 68, 83, 89]][mini(state.day - 1, 4)]
	var roll := randi_range(0, 99)
	var level := 5
	for i in thresholds.size():
		if roll < int(thresholds[i]):
			level = i + 1
			break
	var price_ranges: Array = [[25, 49], [40, 69], [60, 99], [40, 69], [120, 149]]
	var price_range: Array = price_ranges[level - 1]
	var price := randi_range(int(price_range[0]), int(price_range[1])) + state.weather_price_bonus
	var duration: int = [120, randi_range(105, 119), randi_range(90, 104), 105, randi_range(100, 114)][level - 1]
	create_order(int(pair[0]["id"]), int(pair[1]["id"]), level, price, duration)

func create_order(from_id: int, to_id: int, level: int, price: int, duration: int = 120, color_index: int = -1) -> Dictionary:
	var lifetime := 4.0 if state.weather == "雾天" else (2.3 if state.weather == "多云" else 3.0)
	if level == 4:
		lifetime += 2.0
	elif level == 5:
		lifetime = 0.9 if state.weather == "多云" else lifetime - 1.8
	if color_index < 0:
		color_index = state.next_order_id % Config.COLORS.size()
		for unused in Config.COLORS.size():
			var taken := false
			for existing in state.orders:
				if int(existing["color_index"]) == color_index:
					taken = true
			if not taken:
				break
			color_index = (color_index + 1) % Config.COLORS.size()
	var order: Dictionary = {"id": state.next_order_id, "from": map_model.waypoint(from_id), "to": map_model.waypoint(to_id), "level": level, "price": price, "state": "available", "accept_timer": lifetime, "lifetime": lifetime, "deadline": state.clock_minutes + duration, "duration": duration, "accepted_at": state.clock_minutes, "late": false, "color_index": color_index}
	state.next_order_id += 1
	state.orders.append(order)
	if level == 4:
		introduction_requested.emit(&"assigned_intro")
	elif level == 5:
		introduction_requested.emit(&"hot_intro")
	return order

func accept_at(point: Dictionary) -> void:
	if state.occupied >= state.capacity:
		_notify(&"full_bag")
		return
	for order in state.orders:
		if order["state"] == "available" and int(order["from"]["id"]) == int(point["id"]):
			order["state"] = "accepted"
			order["accepted_at"] = state.clock_minutes
			cue_requested.emit(&"accept")
			state.occupied += 1
			state.tasks.append({"order": order, "kind": "取餐"})
			state.tasks.append({"order": order, "kind": "送达"})
			route_requested.emit()
			_notify(&"accepted", {"occupied": state.occupied, "capacity": state.capacity})
			return
	_notify(&"no_order")

func prioritize(index: int) -> void:
	if index <= 0 or index >= state.tasks.size():
		return
	var task: Dictionary = state.tasks[index]
	if task["kind"] == "送达" and has_unfinished_pickup(task["order"]):
		_notify(&"pickup_first")
		return
	state.tasks.remove_at(index)
	state.tasks.push_front(task)
	state.courier_route.clear()
	route_requested.emit()
	_notify(&"sorted")

func move_task(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= state.tasks.size() or to_index < 0 or to_index >= state.tasks.size():
		return false
	var reordered: Array = state.tasks.duplicate()
	var task: Dictionary = reordered.pop_at(from_index)
	reordered.insert(to_index, task)
	for i in reordered.size():
		if reordered[i]["kind"] == "送达":
			for j in range(i + 1, reordered.size()):
				if reordered[j]["kind"] == "取餐" and reordered[j]["order"] == reordered[i]["order"]:
					_notify(&"pickup_first")
					return false
	var previous_first: Dictionary = state.tasks[0]
	state.tasks = reordered
	if state.tasks[0] != previous_first:
		state.courier_route.clear()
		route_requested.emit()
	changed.emit()
	_notify(&"sorted")
	return true

func has_unfinished_pickup(order: Dictionary) -> bool:
	for task in state.tasks:
		if task["order"] == order and task["kind"] == "取餐":
			return true
	return false

func complete_current_task() -> void:
	if state.tasks.is_empty():
		state.courier_route.clear()
		return
	var task: Dictionary = state.tasks.pop_front()
	var order: Dictionary = task["order"]
	if task["kind"] == "取餐":
		order["state"] = "picked_up"
		var threshold := pickup_wait_probability(int(order["level"]))
		if randi_range(0, 99) < threshold:
			state.wait_order = order
			state.wait_until = state.clock_minutes + 17 + 3 * (state.day - 1)
		else:
			_notify(&"picked_up")
	else:
		order["state"] = "delivered"
		cue_requested.emit(&"delivery")
		var level := int(order["level"])
		var event_roll := randi_range(0, 99)
		var late_probabilities: Array = [6, 25, 40, 70, 50]
		var ontime_probabilities: Array = [20, 15, 7, 2, 1]
		if order["late"] and event_roll < int(late_probabilities[level - 1]):
			order["price"] = int(order["price"] * 2 / 3)
		elif not order["late"] and event_roll < int(ontime_probabilities[level - 1]):
			order["price"] = int(order["price"] * 4 / 3)
		state.money += int(order["price"])
		state.finished_count += 1
		state.occupied = max(0, state.occupied - 1)
		state.orders.erase(order)
		_notify(&"delivered", {"amount": int(order["price"])})
	state.courier_route.clear()
	route_requested.emit()

func pickup_wait_probability(level: int) -> int:
	var thresholds: Array = [[0, 0, 0, 0], [5, 7, 13, 2], [8, 12, 17, 4], [10, 14, 20, 5], [12, 15, 22, 6]][mini(state.day - 1, 4)]
	return int(thresholds[mini(level - 1, 3)])

func advance_generation(delta: float) -> void:
	state.generated_timer -= delta
	if state.generated_timer <= 0.0 and state.clock_minutes < 19 * 60:
		generate()
		var round_index := mini(state.day - 1, 4)
		var peak := (state.clock_minutes >= 690 and state.clock_minutes <= 840) or (state.clock_minutes >= 1020 and state.clock_minutes <= 1140)
		var extra_probability: int = [30, 35, 38, 40, 45][round_index] if peak else 17 + round_index * 2
		if randi_range(0, 99) < extra_probability:
			generate()
		var intervals: Array = [3.7, 3.2, 3.0, 2.8, 2.5] if peak else [5.0, 4.6, 4.2, 3.9, 3.6]
		state.generated_timer = float(intervals[round_index]) + randf_range(-0.7, 0.7)

func finish_wait_if_ready() -> void:
	if not state.wait_order.is_empty() and state.clock_minutes >= state.wait_until:
		# Detach the shared order rather than clearing its Dictionary.
		state.wait_order = {}
		_notify(&"food_ready")
