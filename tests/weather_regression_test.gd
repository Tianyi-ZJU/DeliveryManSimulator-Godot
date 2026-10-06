extends SceneTree

const GameFixture := preload("res://tests/game_fixture.gd")

const Atmosphere := preload("res://scripts/weather_atmosphere.gd")
var checks := 0
var errors := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors += 1
		push_error(message)

func run() -> void:
	# Decorative randomness must not change future order/weather rolls.
	seed(47109)
	var expected := [randi(), randi(), randi()]
	seed(47109)
	var atmosphere := Atmosphere.new()
	for name: String in Atmosphere.PROFILES:
		atmosphere.reset(name)
		atmosphere.advance(10.0)
	check([randi(), randi(), randi()] == expected, "VFX do not consume gameplay randomness")

	for name: String in Atmosphere.PROFILES:
		atmosphere.rng.seed = 789
		atmosphere.reset(name)
		check(atmosphere.opacity() == 0.0 and atmosphere.quiet_remaining >= 6.0, name + " has a quiet opening")
		var previous_active := false
		var bursts := 0
		var active_seconds := 0.0
		var shortest_quiet := 999.0
		var quiet_seconds := 0.0
		var geometry_valid := true
		var bounded_alpha := true
		for step in range(2400):
			atmosphere.advance(0.1)
			var active := not atmosphere.event.is_empty()
			if active:
				active_seconds += 0.1
				if not previous_active:
					bursts += 1
					if bursts > 1:
						shortest_quiet = minf(shortest_quiet, quiet_seconds)
					quiet_seconds = 0.0
				var progress := atmosphere.age / float(atmosphere.event["duration"])
				var point: Vector2 = atmosphere.event["origin"] + atmosphere.event["travel"] * progress
				var dimensions: Vector2 = atmosphere.event["size"]
				var start: Vector2 = atmosphere.event["origin"]
				var travel: Vector2 = atmosphere.event["travel"]
				match name:
					"多云":
						geometry_valid = geometry_valid and start.x + dimensions.x <= 0.0 and start.x + travel.x >= 1280.0 and is_zero_approx(travel.y) and dimensions.x * dimensions.y <= 140000.0
					"雨天":
						geometry_valid = geometry_valid and start.x >= 1280.0 and start.x + travel.x + dimensions.x <= 0.0 and point.y <= 0.0 and point.y + dimensions.y >= 675.0
					"晴天":
						geometry_valid = geometry_valid and point.y <= 0.0 and point.y + dimensions.y >= 675.0
					"雾天":
						geometry_valid = geometry_valid and Rect2(point, dimensions).encloses(Atmosphere.EFFECT_AREA)
			else:
				quiet_seconds += 0.1
			bounded_alpha = bounded_alpha and atmosphere.opacity() <= float(Atmosphere.PROFILES[name]["alpha"]) and atmosphere.opacity() >= 0.0
			previous_active = active
		check(bursts >= 4 and bursts <= 8, name + " appears only a few times over four minutes")
		check(active_seconds < 120.0 and shortest_quiet >= 23.9, name + " leaves long gaps and is absent most of the time")
		check(geometry_valid, name + " covers the requested full-height or cross-screen path")
		check(bounded_alpha, name + " respects its configured opacity cap")
		atmosphere._begin_event()
		check(is_zero_approx(atmosphere.opacity()), name + " fades in from transparent")
		atmosphere.age = float(atmosphere.event["duration"]) - 0.05
		check(atmosphere.opacity() < float(Atmosphere.PROFILES[name]["alpha"]) * 0.002, name + " fades below 0.2% of peak before its event ends")
		atmosphere.set_running(false)
		atmosphere.advance(60.0)
		check(atmosphere.event.is_empty() and atmosphere.opacity() == 0.0, name + " clears and stops during rest")
		atmosphere.set_running(true)
		check(atmosphere.event.is_empty() and atmosphere.quiet_remaining >= 6.0, name + " resumes with a quiet interval")

	atmosphere.reset("多云")
	atmosphere.advance(10.0)
	atmosphere.set_weather("雨天")
	check(atmosphere.event.is_empty() and atmosphere.weather == "雨天" and atmosphere.quiet_remaining >= 6.0, "Weather changes remove the previous effect")
	atmosphere.reset("unknown")
	atmosphere.advance(100.0)
	check(atmosphere.opacity() == 0.0, "Unknown weather is safely undecorated")

	var game: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state.generated_timer = 999.0
	await process_frame
	var vfx: RefCounted = game.weather_atmosphere
	check(vfx.weather == "晴天", "Gameplay initializes sunny decoration")
	vfx.quiet_remaining = 0.0
	game._process(0.1)
	check(not vfx.event.is_empty(), "Gameplay advances the decoration controller")
	var age_before: float = vfx.age
	Input.action_press("time_slow")
	game._process(0.5)
	Input.action_release("time_slow")
	check(is_equal_approx(vfx.age - age_before, 0.1), "Ctrl slows decoration with gameplay time")
	game.day_cycle.begin_rest()
	check(not vfx.running and vfx.event.is_empty(), "Rest clears weather immediately")
	game.day_cycle.start_next_day()
	check(vfx.running and vfx.weather == game.state.weather and vfx.event.is_empty(), "Next day starts the selected weather cleanly")
	vfx.quiet_remaining = 0.0
	vfx.advance(0.1)
	game.day_cycle.finish_run()
	check(not vfx.running and vfx.event.is_empty(), "Final summary clears weather")
	game.day_cycle.restart()
	check(vfx.running and vfx.weather == "晴天" and vfx.event.is_empty(), "Restart resets weather effects")

	if OS.get_cmdline_user_args().has("--capture"):
		await capture_and_compare(game)
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("WEATHER REGRESSION RESULT: %s (%d checks)" % ["PASS" if errors == 0 else "FAIL", checks])
	quit(0 if errors == 0 else 1)

func capture_and_compare(game: Node) -> void:
	root.size = Vector2i(1280, 675)
	GameFixture.prepare_input(game)
	game.order_system.accept_at(game.state.orders[0]["from"])
	game.notifications.clear()
	await process_frame
	# Render each event at its plateau, including a marker over the effect.
	for name: String in Atmosphere.PROFILES:
		var vfx: RefCounted = game.weather_atmosphere
		game.state.weather = name
		vfx.set_running(false)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var baseline := root.get_texture().get_image()
		vfx.rng.seed = 10921
		vfx.reset(name)
		vfx.advance(10.0)
		vfx.age = float(vfx.event["duration"]) * 0.5
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var stem: String = {"多云": "cloudy", "雾天": "foggy", "晴天": "sunny", "雨天": "rainy"}[name]
		image.save_png("res://tests/weather_%s.png" % stem)
		var maximum_difference := 0.0
		var changed_pixels := 0
		var markers_unchanged := true
		var opaque_marker_pixels := 0
		var hud_unchanged := true
		var opaque_hud_pixels := 0
		var top_changes := 0
		var bottom_changes := 0
		var warm_pixels := 0
		for y in range(675):
			for x in range(1280):
				var before := baseline.get_pixel(x, y)
				var after := image.get_pixel(x, y)
				var difference := maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))
				maximum_difference = maxf(maximum_difference, difference)
				if difference > 1.0 / 255.0:
					changed_pixels += 1
					if y < 100: top_changes += 1
					if y > 575: bottom_changes += 1
					if after.r - before.r > after.b - before.b + 0.03: warm_pixels += 1
				if before == Color.WHITE:
					opaque_hud_pixels += 1
					hud_unchanged = hud_unchanged and before == after
				if before.is_equal_approx(Color.YELLOW) or before.is_equal_approx(Color("#ffd60a")) or before.is_equal_approx(Color("#499bd6")):
					opaque_marker_pixels += 1
					markers_unchanged = markers_unchanged and before == after
		check(opaque_hud_pixels > 500 and hud_unchanged, name + " preserves solid HUD text and icon colors")
		check(changed_pixels > 1000 and maximum_difference < 0.45, name + " is visibly present while keeping the map readable")
		check(opaque_marker_pixels > 100 and markers_unchanged, name + " preserves route, order and courier colors")
		if name == "晴天":
			check(top_changes > 1000 and bottom_changes > 1000 and warm_pixels > 10000, "Sunlight reaches top and bottom with a warm color")
		elif name == "雾天":
			check(changed_pixels > 600000, "Fog reaches the entire map rather than a local patch")
		elif name == "雨天":
			check(top_changes > 100 and bottom_changes > 100, "Rain curtain reaches top and bottom")
		print("WEATHER CAPTURE %s: %d pixels, max change %.3f" % [stem, changed_pixels, maximum_difference])
