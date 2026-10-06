extends SceneTree

var errors := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors += 1
		push_error(message)

func make_game() -> Node:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.game_audio.stop()
	game.state.generated_timer = 999.0
	return game

func run() -> void:
	var game := make_game()
	var other := make_game()
	await process_frame
	check(game.state != other.state and game.order_system != other.order_system, "Runs own distinct state and gameplay systems")
	game.state.money = 300
	var first: Dictionary = game.order_system.create_order(14, 21, 1, 46)
	check(other.state.money == 100 and other.state.orders.is_empty(), "Order and economy changes cannot affect another run")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.map_model.world_to_screen(Vector2(float(first["from"]["x"]), float(first["from"]["y"])))
	game._unhandled_input(click)
	check(first["state"] == "accepted" and game.state.courier_route.size() > 2, "Map input reaches orders and immediately requests courier routing")
	var second: Dictionary = game.order_system.create_order(3, 26, 1, 40)
	game.order_system.accept_at(second["from"])
	game.refresh_views()
	await process_frame
	check(game.hud.task_list.task_box.get_child_count() == 4, "Task view shows both accepted orders")
	click.global_position = Vector2(1000, 400)
	game.hud.task_list.task_gui_input.emit(click, 2)
	var motion := InputEventMouseMotion.new()
	motion.global_position = Vector2(1000, 430)
	game._input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = Vector2(1000, game.hud.task_list.task_box.global_position.y + 10)
	game._input(release)
	check(game.state.tasks[0]["order"] == second and game.state.courier_target == 3, "Task drag flows from view through input to ordering and routing")
	check(game.input_controller.task_drag_index == -1 and not game.input_controller.task_dragged, "Drag release clears the input controller state")
	game.hud.task_list.task_hovered.emit(int(second["id"]), "from")
	check(game.input_controller.hover_order_id == int(second["id"]) and game.input_controller.hover_kind == "from", "Task hover reaches the map rendering selection")
	game.day_cycle.begin_rest()
	await process_frame
	check(is_instance_valid(game.rest_screen) and not game.weather_atmosphere.running, "Rest lifecycle creates the view and stops atmosphere")
	game.rest_screen.upgrade_buttons["capacity"].pressed.emit()
	check(game.state.capacity == 4 and game.state.money == 200 and game.state.purchases_left == 1, "Purchase button invokes gameplay rules exactly once")
	game.rest_screen.upgrade_next_day.pressed.emit()
	await process_frame
	check(game.state.day == 2 and not game.state.upgrade_visible and game.rest_screen == null, "Next-day button removes the rest view and resumes the run")
	check(game.state.capacity == 4 and game.state.orders.is_empty() and other.state.capacity == 3, "Cross-day reset keeps only this run's purchases")
	game.state.day = 5
	game.state.clock_minutes = 1260
	game.day_cycle.request_settlement()
	check(game.state.game_finished and is_instance_valid(game.end_summary), "Final-day signal creates the summary view")
	var restart: Button = game.end_summary.find_child("Restart", true, false)
	restart.pressed.emit()
	await process_frame
	check(game.state.day == 1 and game.state.money == 100 and game.state.courier_speed == 10, "Summary restart button resets the same state object with original defaults")
	check(game.end_summary == null and game.notifications.seen_introductions.size() == 1, "Restart removes final UI and resets encounter introductions")
	var refs := [weakref(game.state), weakref(game.order_system), weakref(game.courier), weakref(game.day_cycle), weakref(game.input_controller), weakref(game.map_renderer)]
	game.queue_free()
	await process_frame
	await process_frame
	var released := true
	for ref: WeakRef in refs:
		released = released and ref.get_ref() == null
	check(released, "Scene disposal releases state and signal-connected systems without reference cycles")
	check(other.state.day == 1 and other.state.money == 100, "Disposing another scene leaves the surviving run intact")
	other.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("ARCHITECTURE REGRESSION RESULT: %s (%d checks)" % ["PASS" if errors == 0 else "FAIL", checks])
	quit(0 if errors == 0 else 1)
