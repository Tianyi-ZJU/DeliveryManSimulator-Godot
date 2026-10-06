extends SceneTree

var errors := 0
var checks := 0
var game: Node

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors += 1
		push_error(message)

func _init() -> void:
	call_deferred("run")

func reset() -> void:
	game.notifications.clear()
	game.state.orders.clear()
	game.state.tasks.clear()
	game.state.courier_route.clear()
	game.state.wait_order = {}
	game.state.occupied = 0
	game.state.money = 100
	game.state.clock_minutes = 600
	game.state.capacity = 3
	game.state.day = 1
	game.state.courier_pos = Vector2(-24.7, -39.8)
	game.state.upgrade_visible = false
	game.state.game_finished = false
	game.state.generated_timer = 999.0
	game.state.clock_accumulator = 0.0
	game.state.speed_energy = 20.0
	game.state.slow_energy = 15.0
	game.state.speed_energy_max = 20.0
	game.state.slow_energy_max = 15.0
	game.state.courier_speed = 11.0
	game.state.purchases_left = 2
	game.state.weather = "晴天"
	game.state.weather_speed_factor = 1.0

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	check(game.map_model.waypoints.size() == 30 and game.map_model.roads.size() == 93, "Original map sizes")
	check(game.map_model.runtime_waypoints.size() == 30, "Authored visual waypoint data loads")
	check(game.state.courier_pos == Vector2(-24.7, -39.8), "Shipping Unity courier spawn")
	check(game.map_model.visual_road_graph.loaded, "Visual road mask loads for runtime routing")
	# All shipping capacities must fit the padded backpack panel without overlap.
	var bag_inner := Rect2(956, 24, 308, 73)
	for bag_capacity in [3, 4, 5]:
		var bag_fits := true
		for slot_index in range(bag_capacity):
			var slot: Rect2 = game.hud.inventory_slot_rect(slot_index)
			bag_fits = bag_fits and bag_inner.encloses(slot)
			for previous_index in range(slot_index):
				bag_fits = bag_fits and not slot.intersects(game.hud.inventory_slot_rect(previous_index))
		check(bag_fits, "Backpack capacity %d stays inside the HUD with no overlapping slots" % bag_capacity)
	check(game.hud.inventory_slot_rect(0).position.x == game.hud.inventory_slot_rect(1).position.x and game.hud.inventory_slot_rect(4).position.y == game.hud.inventory_slot_rect(0).position.y, "Backpack fills vertically in two rows as in the Unity prefab")
	for runtime_point in game.map_model.runtime_waypoints:
		var runtime_position := Vector2(float(runtime_point["x"]), float(runtime_point["y"]))
		check(game.map_model.visual_road_graph.is_world_point_near_road(runtime_position, 0.1), "Authored waypoint leaves painted road: " + str(runtime_point["id"]))
	var visual_route: Array[Vector2] = game.map_model.visual_road_graph.route_from(game.state.courier_pos, Vector2(float(game.map_model.waypoints[14]["x"]), float(game.map_model.waypoints[14]["y"])))
	check(visual_route.size() > 2, "Visual road route has multiple cells")
	check(game.map_model.visual_road_graph.route_segments_follow_road(visual_route), "Visual route shortcut leaves painted road")
	for visual_point in visual_route:
		check(game.map_model.visual_road_graph.is_world_point_near_road(visual_point), "Visual route leaves painted road")
	for point in game.map_model.waypoints:
		var world := Vector2(float(point["x"]), float(point["y"]))
		var screen: Vector2 = game.map_model.world_to_screen(world)
		check(Rect2(0, 0, 940, 675).has_point(screen), "Waypoint must remain visible: " + point["name"])
		check(game.map_model.screen_to_world(screen).distance_to(world) < 0.0001, "Coordinate inverse")
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/route_fixtures.json"))
	for fixture in fixtures:
		var from: Dictionary = game.map_model.waypoints[int(fixture["from"])]
		var position := Vector2(float(from["x"]), float(from["y"]))
		var route: Array[Vector2] = game.map_model.road_graph.route_from(position, int(fixture["to"]))
		var length := 0.0
		for step in route:
			length += position.distance_to(step)
			position = step
		check(absf(length - float(fixture["length"])) < 0.002, "Unity shortest route mismatch: %d -> %d" % [int(fixture["from"]), int(fixture["to"])])
	reset()
	var first: Dictionary = game.order_system.create_order(14, 21, 1, 46, 120, 1)
	check(game.map_model.visual_road_graph.is_world_point_near_road(Vector2(float(first["from"]["x"]), float(first["from"]["y"])), 0.1), "Order pickup is placed on a painted road")
	check(game.map_model.visual_road_graph.is_world_point_near_road(Vector2(float(first["to"]["x"]), float(first["to"]["y"])), 0.1), "Order delivery is placed on a painted road")
	game.order_system.accept_at(first["from"])
	game.refresh_views()
	await process_frame
	check(game.state.occupied == 1 and game.state.tasks.size() == 2, "Accepted order uses one slot and two tasks")
	check(game.hud.task_list.task_box.get_child_count() == 2, "Pickup and delivery cards exist")
	check(game.state.courier_route.size() > 2, "Courier follows multi-segment road route")
	game.order_system.prioritize(1)
	check(game.state.tasks[0]["kind"] == "取餐", "Delivery cannot jump before pickup")
	var second: Dictionary = game.order_system.create_order(3, 26, 1, 40)
	game.order_system.accept_at(second["from"])
	game.order_system.prioritize(2)
	check(game.state.tasks[0]["order"] == second and game.state.courier_target == 3, "Prioritization immediately reroutes courier")
	check(not game.order_system.move_task(0, 3), "Dragging pickup after its delivery is refused")
	check(game.order_system.move_task(1, 0) and game.state.tasks[0]["order"] == first, "Dragging an independent pickup to the front reroutes")
	var third: Dictionary = game.order_system.create_order(27, 0, 1, 40)
	game.order_system.accept_at(third["from"])
	var fourth: Dictionary = game.order_system.create_order(29, 4, 1, 40)
	game.order_system.accept_at(fourth["from"])
	check(game.state.occupied == 3 and fourth["state"] == "available", "Full capacity refuses fourth order")
	reset()
	game.state.upgrades_remaining["capacity"] = 2
	game.state.money = 400
	game.day_cycle.begin_rest()
	game.day_cycle.purchase("capacity")
	check(game.state.capacity == 4 and game.state.money == 300, "First bag upgrade unlocks a fourth slot")
	game.day_cycle.purchase("capacity")
	check(game.state.capacity == 5 and game.state.money == 200 and game.state.upgrades_remaining["capacity"] == 0, "Second bag upgrade unlocks a fifth slot")
	game.day_cycle.start_next_day()
	await process_frame
	check(game.state.capacity == 5 and game.state.occupied == 0, "Next day keeps all five unlocked slots and clears occupancy")
	var bag_orders: Array[Dictionary] = []
	for pickup_id in [3, 5, 10, 14, 17, 18]:
		var bag_order: Dictionary = game.order_system.create_order(pickup_id, 21, 1, 40)
		game.order_system.accept_at(bag_order["from"])
		bag_orders.append(bag_order)
	check(game.state.occupied == 5 and game.state.tasks.size() == 10 and bag_orders[5]["state"] == "available", "Five-slot backpack accepts five orders and refuses the sixth")
	game.state.clock_minutes = 781
	game.order_system.update(0.0)
	check(game.state.occupied == 0 and game.state.tasks.is_empty(), "Cancellation releases every occupied slot of an upgraded backpack")
	reset()
	first = game.order_system.create_order(14, 21, 1, 46)
	game.order_system.accept_at(first["from"])
	var iterations := 0
	while first["state"] != "picked_up" and iterations < 2000:
		game.courier.update(0.05, Input.is_action_pressed("speed_up"))
		iterations += 1
	check(first["state"] == "picked_up" and game.state.tasks.size() == 1, "Movement reaches pickup before delivery")
	while not game.state.orders.is_empty() and iterations < 4000:
		game.courier.update(0.05, Input.is_action_pressed("speed_up"))
		iterations += 1
	check(game.state.orders.is_empty() and game.state.occupied == 0 and game.state.money >= 146, "Delivery pays reward and frees slot")
	reset()
	first = game.order_system.create_order(14, 21, 1, 46)
	game.order_system.accept_at(first["from"])
	game.state.clock_minutes = 721
	game.order_system.update(0.0)
	check(game.state.money == 77 and first["late"], "Late penalty occurs once")
	game.order_system.update(0.0)
	check(game.state.money == 77, "Repeated late update does not repeat penalty")
	game.state.clock_minutes = 781
	game.order_system.update(0.0)
	check(game.state.orders.is_empty() and game.state.tasks.is_empty() and game.state.occupied == 0 and game.state.money == 31, "Severely late order clears tasks and capacity")
	reset()
	first = game.order_system.create_order(14, 21, 4, 60)
	game.order_system.update(6.0)
	check(game.state.orders.is_empty() and game.state.money == 40, "Unaccepted assigned order penalty")
	reset()
	game.state.weather = "多云"
	first = game.order_system.create_order(14, 21, 1, 40)
	check(is_equal_approx(float(first["lifetime"]), 2.3), "Cloudy acceptance window")
	game.state.weather = "雾天"
	first = game.order_system.create_order(3, 26, 1, 40)
	check(is_equal_approx(float(first["lifetime"]), 4.0), "Foggy acceptance window")
	reset()
	game.state.day = 2
	check(game.order_system.pickup_wait_probability(3) == 13, "Original second-day pickup event probability")
	game.state.wait_order = game.order_system.create_order(14, 21, 1, 40)
	game.state.wait_until = 620
	var urge := InputEventAction.new()
	urge.action = "urge"
	urge.pressed = true
	game._unhandled_input(urge)
	check(game.state.wait_until == 618, "Space urge reduces wait by two virtual minutes")
	reset()
	game.state.upgrade_visible = true
	game.day_cycle.purchase("speed")
	check(game.state.money == 0 and game.state.courier_speed == 15.0 and game.state.purchases_left == 1, "Original upgrade cost and speed increment")
	game.day_cycle.purchase("capacity")
	check(game.state.capacity == 3, "Insufficient funds refuses upgrade")
	reset()
	Input.action_press("time_slow")
	game._process(1.0)
	check(game.state.clock_minutes == 601, "Ctrl slows one real second to one virtual minute")
	check(absf(game.state.slow_energy - 13.03) < 0.001, "Ctrl consumes and recovers energy in scaled time")
	Input.action_release("time_slow")
	reset()
	first = game.order_system.create_order(14, 21, 1, 46)
	game.order_system.accept_at(first["from"])
	Input.action_press("speed_up")
	game._process(0.1)
	check(absf(game.state.speed_energy - (19.5 + 0.1 / 3.0)) < 0.001, "Shift drain and recharge match Unity")
	Input.action_release("speed_up")
	reset()
	# Unity GeneratorManager cuts off new orders at 19:00. GamingCanvasBehaviour
	# permits Space once the database is empty, or automatically settles at 21:00.
	game.state.clock_minutes = 1139
	game.state.generated_timer = 0.0
	game._process(0.0)
	check(not game.state.orders.is_empty(), "Orders still refresh at 18:59")
	reset()
	game.state.clock_minutes = 1140
	game.state.generated_timer = 0.0
	game._process(0.0)
	check(game.state.orders.is_empty() and not game.state.upgrade_visible, "19:00 stops new orders without automatically settling")
	check(game.hud.day_close_panel.visible and not game.hud.task_list.visible, "Empty evening replaces the task list with the ready-to-settle card")
	game.notifications.clear()
	game._process(0.5)
	check(game.hud.day_close_panel.visible and game.notifications.active.is_empty(), "Settlement card remains visible without a separate closing notice")
	game._unhandled_input(urge)
	check(game.state.upgrade_visible and game.state.day == 1, "Space after 19:00 enters settlement without waiting until 21:00")
	check(not game.hud.day_close_panel.visible, "Settlement card closes before the upgrade screen opens")
	var settlement_children: int = game.get_child_count()
	game.day_cycle.request_settlement()
	game.day_cycle.finish_day()
	check(game.get_child_count() == settlement_children and game.state.day == 1, "Repeated settlement requests cannot duplicate overlays or skip upgrades")
	var held_space := InputEventKey.new()
	held_space.physical_keycode = KEY_SPACE
	held_space.pressed = true
	held_space.echo = true
	game._unhandled_input(held_space)
	check(game.state.day == 1 and game.state.upgrade_visible, "Holding Space does not also skip the upgrade screen")
	game.day_cycle.start_next_day()
	await process_frame
	check(not game.hud.day_close_panel.visible and game.hud.task_list.visible and game.hud.task_list.position.y == 148.0, "Next day restores the full-height order list")
	reset()
	game.state.clock_minutes = 1139
	game._unhandled_input(urge)
	check(not game.state.upgrade_visible, "Space cannot settle before 19:00")
	game.day_cycle.request_settlement()
	check(not game.state.upgrade_visible, "The settlement button follows the same cutoff guard as Space")
	game.state.clock_minutes = 1140
	first = game.order_system.create_order(14, 21, 1, 46)
	game.refresh_views()
	game._unhandled_input(urge)
	check(not game.state.upgrade_visible and not game.hud.day_close_panel.visible, "Remaining available order leaves the settlement card hidden")
	check(game.hud.day_close_panel.get_node_or_null("ClosingOrders") == null, "The unwanted closing-orders panel is removed")
	game.order_system.accept_at(first["from"])
	game.refresh_views()
	game._unhandled_input(urge)
	check(not game.state.upgrade_visible and not game.state.tasks.is_empty(), "Accepted order must finish before settling")
	check(game.hud.task_list.visible and game.hud.task_list.position.y == 148.0 and game.hud.task_list.size.y == 510.0, "Evening deliveries keep the original full-height task list")
	check(not game.hud.day_close_panel.visible and not game.day_cycle.can_settle(), "Unfinished evening delivery has no closing panel and cannot settle")
	game.hud.day_close_panel.settle_requested.emit()
	check(not game.state.upgrade_visible, "A stale UI signal cannot discard an unfinished order")
	game.state.clock_minutes = 1260
	game._process(0.0)
	check(not game.state.upgrade_visible, "21:00 automatic settlement also waits for unfinished orders")
	reset()
	game.state.clock_minutes = 1140
	game.state.finished_count = 8
	game.state.day_start_finished = 5
	game.state.money = 220
	game.state.day_start_money = 180
	game.refresh_views()
	check(game.hud.day_close_panel.completed_value.text == "3 单" and game.hud.day_close_panel.income_value.text == "$40", "Closing summary shows this day's totals, not lifetime completion or account balance")
	game.state.money = 158
	game.refresh_views()
	check(game.hud.day_close_panel.income_value.text == "-$22", "Net loss from penalties appears as a negative daily income")
	game.hud.day_close_panel.settle_button.pressed.emit()
	check(game.state.upgrade_visible and not game.state.game_finished, "Clicking the card's button enters the upgrade screen")
	game.day_cycle.start_next_day()
	await process_frame
	check(game.state.day_start_finished == 8 and game.state.day_start_money == 158, "Daily totals restart after upgrades without losing lifetime statistics")
	reset()
	game.state.clock_minutes = 1259
	game._process(0.0)
	check(not game.state.upgrade_visible, "An empty day does not auto-settle at 20:59")
	reset()
	game.state.clock_minutes = 1140
	game.state.day = 5
	game.refresh_views()
	check(game.hud.day_close_panel.settle_button.text == "查看最终成绩", "Day five offers the final summary instead of a nonexistent day six upgrade")
	game._unhandled_input(urge)
	check(game.state.game_finished and not game.state.upgrade_visible, "Space on an empty fifth day opens the final summary")
	game.day_cycle.restart()
	await process_frame
	reset()
	for expected_day in range(1, 5):
		game.state.clock_minutes = 1260
		game._process(0.2)
		check(game.state.upgrade_visible and not game.state.game_finished, "Days 1-4 go to upgrades")
		game._unhandled_input(urge)
		await process_frame
		check(game.state.day == expected_day + 1 and game.state.clock_minutes == 600 and not game.state.upgrade_visible, "Space skips upgrades and begins next day")
	game.state.money = 6500
	game.state.finished_count = 87
	game.state.clock_minutes = 1260
	game._process(0.2)
	check(game.state.day == 5 and game.state.game_finished and not game.state.upgrade_visible, "Day five ends the run without day six")
	check(game.get_node("EndSummary") != null, "Final statistics panel exists")
	game._process(5.0)
	check(game.state.clock_minutes == 1261, "Final summary freezes the clock")
	game.day_cycle.restart()
	await process_frame
	check(game.state.day == 1 and game.state.money == 100 and game.state.finished_count == 0 and not game.state.game_finished, "New game resets run statistics")
	check(game.get_node_or_null("EndSummary") == null, "Restart removes the summary panel")
	check(game.state.capacity == 3 and game.state.courier_speed == 10 and game.state.upgrades_remaining["speed"] == 2, "Restart matches Unity Reset and restores upgrades")
	var rating = load("res://scripts/end_rating.gd")
	for example in [[1999, 0, 0, "F"], [2000, 0, 0, "D"], [2999, 0, 0, "D"], [3000, 0, 0, "C"], [3999, 11, 1, "D"], [4000, 0, 0, "B"], [4000, 11, 1, "C"], [5000, 0, 0, "A"], [5999, 11, 1, "B"], [6000, 0, 6, "B"], [6000, 11, 0, "A"], [6000, 6, 0, "S"], [6000, 0, 2, "S"], [6000, 1, 0, "SS"], [6999, 0, 0, "SSS"], [7000, 0, 6, "A"], [7000, 11, 0, "S"], [7000, 6, 0, "SS"], [7000, 0, 2, "SS"], [7000, 1, 0, "SSS"], [7000, 0, 0, "SSSS"]]:
		check(rating.calculate(example[0], example[1], example[2]) == example[3], "Original final rating boundary: " + str(example))
	var quit_key := InputEventKey.new()
	quit_key.physical_keycode = KEY_Q
	quit_key.pressed = true
	game._unhandled_input(quit_key)
	check(game.state.game_finished, "Q ends current run with statistics")
	game.queue_free()
	await process_frame
	print("REGRESSION RESULT: %s (%d checks; 870 independent Unity route fixtures)" % ["PASS" if errors == 0 else "FAIL", checks])
	quit(0 if errors == 0 else 1)
