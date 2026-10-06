extends SceneTree

var game: Node
var center: Node
var errors := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors += 1
		push_error(message)

func has_event(event: String) -> bool:
	for notice: Dictionary in center.snapshot():
		if notice["event"] == event:
			return true
	return false

func reset_game() -> void:
	game._restart_game()
	game.set_process(false)
	center.set_process(false)
	center.clear()
	game.generated_timer = 999.0

func test_introductions() -> void:
	center.reset_introductions()
	var weather_events := {"晴天": "weather_sunny", "多云": "weather_cloudy", "雨天": "weather_rainy", "雾天": "weather_foggy"}
	for weather_name: String in weather_events:
		game.weather = weather_name
		game._announce_day()
		check(has_event(weather_events[weather_name]) and center.snapshot().size() == 1 and center.snapshot()[0]["title"].contains(weather_name), "First %s combines weather guidance with the day opening" % weather_name)
		await process_frame
		await process_frame
		var card: Control = center.active[0]["node"]
		check(is_equal_approx(card.size.x, 280.0) and card.size.y < 100.0, "%s guide fits the compact card" % weather_name)
		center.advance(6.0)
		center.clear()
		game._announce_day()
		check(has_event("day_started") and not has_event(weather_events[weather_name]), "Known %s uses a brief opening without repeating its guide" % weather_name)
		center.advance(6.0)
	check(center.seen_introductions.size() == 4, "All four weather encounters are tracked independently within the run")
	for level in range(1, 4):
		game.create_order(14, 21, level, 40)
	check(center.snapshot().is_empty() and center.pending_introductions.is_empty(), "Ordinary star difficulties do not create special-order guides")
	game.weather = "晴天"
	var assigned: Dictionary = game.create_order(14, 21, 4, 60)
	check(has_event("assigned_intro") and assigned["state"] == "available" and center.snapshot()[0]["title"].contains("!"), "Specified order guide appears when its marker spawns, before acceptance")
	center.advance(1.0)
	var remaining: float = center.snapshot()[0]["remaining"]
	game.create_order(3, 26, 4, 60)
	check(center.snapshot()[0]["remaining"] == remaining and center.pending_introductions.is_empty(), "Repeated specified orders neither repeat nor prolong the guide")
	game.create_order(5, 21, 5, 130)
	game.create_order(10, 26, 5, 130)
	check(has_event("assigned_intro") and center.pending_introductions.size() == 1, "First hot guide queues once behind the specified guide")
	center.advance(4.0)
	check(has_event("hot_intro") and center.snapshot().size() == 1 and center.snapshot()[0]["title"].contains("火焰"), "Hot guide follows with the original flame marker description")
	center.advance(5.0)
	center.clear()
	game.create_order(14, 21, 4, 60)
	game.create_order(3, 26, 5, 130)
	check(center.snapshot().is_empty(), "Completed special-order guides remain suppressed after normal clearing")

	center.reset_introductions()
	game._announce_day()
	game.create_order(14, 21, 4, 60)
	game.create_order(3, 26, 5, 130)
	check(has_event("weather_sunny") and center.pending_introductions.size() == 2, "Simultaneous new weather and both special types retain one visible card and two queued guides")
	check(not center.post(&"audio", {"state": "声音已关闭"}) and has_event("weather_sunny"), "Routine same-priority feedback does not interrupt a first-time guide")
	center.post(&"late", {"amount": 23})
	check(has_event("late") and center.pending_introductions.size() == 3, "A penalty immediately interrupts without dropping the unfinished guide or queue")
	center.advance(4.0)
	check(has_event("weather_sunny"), "Interrupted weather guide resumes after the penalty expires")
	center.advance(4.0)
	check(has_event("assigned_intro"), "Specified guide follows the resumed weather guide")
	center.advance(5.0)
	check(has_event("hot_intro"), "Hot guide completes the preserved sequence")
	center.advance(5.0)
	check(center.snapshot().is_empty() and center.pending_introductions.is_empty(), "Completed guide sequence leaves no lingering cards")
	game._start_next_day()
	check(center.seen_introductions.has(&"weather_sunny") and center.seen_introductions.has(&"assigned_intro") and center.seen_introductions.has(&"hot_intro"), "Actual day transition preserves encounter history")
	center.clear()
	game.create_order(14, 21, 4, 60)
	game.create_order(3, 26, 5, 130)
	check(center.snapshot().is_empty(), "Special guides do not repeat on a later day")
	game._show_end()
	game._restart_game()
	check(has_event("weather_sunny") and center.seen_introductions.size() == 1, "Actual new-game action resets history and restores the sunny opening")
	game.create_order(14, 21, 4, 60)
	game.create_order(3, 26, 5, 130)
	check(center.pending_introductions.size() == 2, "New run restores each special-order introduction")
	center.clear()
	game.create_order(14, 21, 4, 60)
	game.create_order(3, 26, 5, 130)
	check(center.snapshot().is_empty() and center.pending_introductions.is_empty(), "A transition drops stale queued cards without rearming encountered types")

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	center = game.notifications
	center.set_process(false)
	await process_frame
	check(has_event("weather_sunny") and center.snapshot().size() == 1, "Boot combines the first sunny guide and day opening into one card")
	check(center.get_parent() is CanvasLayer and center.get_parent().layer > 0, "Notices remain above upgrade overlays")
	check(center.mouse_filter == Control.MOUSE_FILTER_IGNORE and center.active[0]["node"].mouse_filter == Control.MOUSE_FILTER_IGNORE, "Notice cards pass clicks to the map")
	center.advance(6.0)
	check(center.snapshot().is_empty(), "Opening guide expires without an action or gameplay clock advance")
	check(center.post(&"full_bag"), "First capacity warning is displayed")
	var warning_node: Control = center.active[0]["node"]
	check(not center.post(&"full_bag") and center.snapshot().size() == 1, "Rapid repeat clicks do not stack capacity warnings")
	center.advance(1.6)
	check(center.post(&"full_bag") and center.active[0]["node"] == warning_node, "Later repeat refreshes the existing card instead of adding another")
	center.post(&"late", {"amount": 23})
	check(center.snapshot().size() == 1 and has_event("late"), "Important penalty replaces routine feedback in the single notice slot")
	check(not center.post(&"sorted") and has_event("late"), "Routine feedback cannot replace higher-priority warnings")
	center.post(&"cancelled", {"amount": 46})
	check(center.snapshot().size() == 1 and has_event("cancelled") and not has_event("late"), "The latest critical notice replaces the previous penalty")
	center.clear()
	center.post(&"late", {"amount": 30})
	center.post(&"late", {"amount": 23})
	check(center.snapshot().size() == 1 and center.snapshot()[0]["body"].contains("$53") and center.snapshot()[0]["count"] == 2, "Consecutive penalties merge their count and total amount without losing a deduction")
	center.advance(6.0)
	check(center.snapshot().is_empty(), "All timed warnings disappear automatically")
	center.set_waiting(10)
	var waiting_node: Control = center.context_card["node"]
	center.post(&"late", {"amount": 23})
	center.post(&"cancelled", {"amount": 46})
	await process_frame
	await process_frame
	var waiting_bottom := waiting_node.global_position.y + waiting_node.size.y
	center.advance(6.0)
	await process_frame
	await process_frame
	check(is_equal_approx(waiting_node.global_position.y + waiting_node.size.y, waiting_bottom), "Waiting card stays anchored to the bottom when other notices expire")
	center.set_waiting(7)
	check(center.context_card["node"] == waiting_node and center.context_card["body"].text.contains("7 分钟"), "Waiting context updates in place as restaurant time changes")
	center.advance(20.0)
	check(not center.context_card.is_empty(), "Waiting guidance stays visible until the actual waiting state ends")
	center.set_waiting(-1)
	check(center.context_card.is_empty(), "Ending the waiting state removes its persistent guidance")
	center.post(&"audio", {"state": "声音已关闭", "action": "关闭"})
	center.post(&"audio", {"state": "声音已开启", "action": "开启"})
	check(center.snapshot().size() == 1 and center.snapshot()[0]["title"] == "声音已开启", "Rapid mute toggles show the latest audio state in one card")
	center.clear()
	check(center.snapshot().is_empty() and center.context_card.is_empty(), "Scene transition clears transient and persistent notices")
	await test_introductions()

	reset_game()
	for iteration in range(6):
		game._generate_order()
	check(center.snapshot().is_empty() and not game.orders.is_empty(), "Regular order refresh changes map markers without repeated toast spam")
	reset_game()
	game.create_order(14, 21, 1, 46)
	game._update_orders(6.0)
	check(center.snapshot().is_empty(), "Ordinary unaccepted expiration stays quiet")
	game.create_order(14, 21, 4, 60)
	game._update_orders(6.0)
	check(has_event("assigned_missed") and center.snapshot()[0]["body"].contains("$60"), "Assigned order expiration reports the actual penalty")
	reset_game()
	var order: Dictionary = game.create_order(14, 21, 1, 46)
	game._accept_order_at(order["from"])
	check(not has_event("accepted") and game.occupied == 1 and not game.tasks.is_empty(), "Acceptance updates the task list without a redundant toast")
	center.clear()
	game._prioritize(1)
	check(has_event("pickup_first") and game.tasks[0]["kind"] == "取餐", "Invalid priority change explains the pickup constraint without changing tasks")
	center.clear()
	game.wait_order = order
	game.wait_until = 610
	game._update_ui()
	check(not center.context_card.is_empty() and center.context_card["body"].text.contains("10 分钟"), "Restaurant waiting is represented by a live context card")
	var urge := InputEventAction.new()
	urge.action = "urge"
	urge.pressed = true
	game._unhandled_input(urge)
	check(game.wait_until == 608 and not has_event("urged") and center.context_card["body"].text.contains("8 分钟"), "Urging updates the persistent wait estimate without another toast")
	game.clock_minutes = 608
	game._process(0.0)
	check(game.wait_order.is_empty() and center.context_card.is_empty() and not has_event("food_ready"), "Food readiness clears the waiting card without a redundant follow-up toast")
	check(order.has("state") and order.has("id") and game.tasks[0]["order"] == order, "Ending a restaurant wait preserves the shared order and its task fields")
	center.clear()
	game.clock_minutes = 721
	game._update_orders(0.0)
	check(has_event("late") and center.snapshot()[0]["body"].contains("$23"), "Lateness notice states the actual half-price deduction")
	var late_node: Control = center.active[0]["node"]
	game._update_orders(0.0)
	check(center.active[0]["node"] == late_node and center.snapshot().size() == 1, "Lateness does not create a card on every frame")
	game.wait_order = order
	game.wait_until = 900
	game._update_ui()
	game.clock_minutes = 781
	game._update_orders(0.0)
	game._update_ui()
	check(has_event("cancelled") and center.context_card.is_empty() and game.tasks.is_empty(), "Cancelled order clears stale waiting guidance and tasks")
	reset_game()
	game.clock_minutes = 1140
	game.create_order(14, 21, 1, 46)
	game._process(0.0)
	check(not game.day_close_panel.visible and game.task_scroll.position.y == 148.0 and game.task_scroll.size.y == 510.0 and center.snapshot().is_empty(), "19:00 pending orders add no closing panel or notice")
	game.orders.clear()
	game._update_ui()
	check(game.day_close_panel.visible and center.snapshot().is_empty(), "Empty evening uses only the retained settlement card")

	game._request_day_settlement()
	game.money = 99
	game._purchase("speed")
	check(has_event("funds") and center.snapshot()[0]["body"].contains("$99"), "Upgrade funds warning shows the actual balance above the overlay")
	center.clear()
	game.money = 300
	game.upgrades_remaining["speed"] = 0
	game._purchase("speed")
	check(has_event("max_upgrade") and not has_event("funds"), "Maxed upgrade gets its own explanation instead of a generic funds error")
	center.clear()
	game.purchases_left = 0
	game._purchase("capacity")
	check(has_event("purchases_used"), "Exhausted daily purchases get a distinct explanation")
	center.clear()
	game.purchases_left = 1
	game._purchase("capacity")
	check(game.day == 1 and game.upgrade_visible and game.money == 200 and has_event("upgraded"), "Last upgrade leaves the rest panel open with a concise success receipt")
	game._start_next_day()
	check(game.day == 2 and not game.upgrade_visible, "Starting the next day is an explicit rest-point action")
	game._purchase("capacity")
	check(game.money == 200, "Stale upgrade input cannot spend money outside the upgrade screen")
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("NOTIFICATION REGRESSION RESULT: %s (%d checks)" % ["PASS" if errors == 0 else "FAIL", checks])
	quit(0 if errors == 0 else 1)
