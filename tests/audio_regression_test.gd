extends SceneTree

var game: Node
var cues: Array[StringName] = []
var errors := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors += 1
		push_error(message)

func reset() -> void:
	Input.action_release("time_slow")
	Input.action_release("speed_up")
	game.day_cycle.restart()
	game.state.generated_timer = 999.0
	cues.clear()

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state.generated_timer = 999.0
	await process_frame
	var audio: Node = game.game_audio
	audio.cue_started.connect(func(cue: StringName) -> void: cues.append(cue))
	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	check(music_bus > 0 and sfx_bus > 0 and music_bus != sfx_bus, "Music and SFX have separate mixer buses")
	check(audio.music_player.bus == &"Music" and audio.music_player.playing, "Day one starts music automatically")
	check(audio.current_day == 1 and audio.music_player.stream.loop, "Music loops on day one")
	var ctrl_key := InputEventKey.new()
	ctrl_key.physical_keycode = KEY_CTRL
	check(InputMap.action_has_event("time_slow", ctrl_key), "Time slowing is bound to the physical Ctrl key")
	for cue: StringName in audio.CUE_PATHS:
		var player: AudioStreamPlayer = audio.effect_players[cue]
		check(player.stream != null and player.stream.get_length() > 0.0, "Decodable effect: " + String(cue))
		check(player.bus == &"SFX" and not player.stream.loop, "Effect is a one-shot: " + String(cue))

	var order: Dictionary = game.order_system.create_order(14, 21, 1, 46)
	game.order_system.accept_at(order["from"])
	check(cues == [&"accept"] and audio.effect_players[&"accept"].playing, "Accepting an order starts the original bell")
	game.state.capacity = 1
	var refused: Dictionary = game.order_system.create_order(3, 26, 1, 40)
	game.order_system.accept_at(refused["from"])
	check(cues == [&"accept"], "Refused order does not play acceptance audio")
	game.order_system.complete_current_task()
	check(cues == [&"accept"], "Arriving at a restaurant does not play a spurious pickup cue")
	game.order_system.complete_current_task()
	check(cues == [&"accept", &"delivery"] and audio.effect_players[&"delivery"].playing, "Delivery starts original coin audio")

	reset()
	order = game.order_system.create_order(14, 21, 1, 46)
	game.order_system.accept_at(order["from"])
	game.state.wait_order = order
	game.state.wait_until = game.state.clock_minutes
	game.order_system.finish_wait_if_ready()
	check(cues == [&"accept"], "Food becoming ready at a restaurant does not play a pickup cue")

	reset()
	order = game.order_system.create_order(14, 21, 1, 46)
	game.order_system.accept_at(order["from"])
	game.state.clock_minutes = 721
	game.order_system.update(0.0)
	check(cues.count(&"late") == 1, "Crossing deadline plays late audio")
	game.order_system.update(0.0)
	check(cues.count(&"late") == 1, "Late audio does not repeat every frame")
	game.state.wait_order = order
	game.state.wait_until = 740
	var urge := InputEventAction.new()
	urge.action = "urge"
	urge.pressed = true
	game._unhandled_input(urge)
	check(cues.count(&"late") == 2, "Urging plays original voice audio")

	reset()
	order = game.order_system.create_order(14, 21, 1, 46)
	game.order_system.accept_at(order["from"])
	Input.action_press("speed_up")
	game.courier.update(0.0, Input.is_action_pressed("speed_up"))
	game.courier.update(0.0, Input.is_action_pressed("speed_up"))
	check(cues.count(&"boost") == 1, "Holding Shift plays one acceleration cue")
	Input.action_release("speed_up")
	game.courier.update(0.0, Input.is_action_pressed("speed_up"))
	Input.action_press("speed_up")
	game.courier.update(0.0, Input.is_action_pressed("speed_up"))
	check(cues.count(&"boost") == 2, "Pressing Shift again plays a new cue")
	game.state.wait_order = order
	game.courier.update(0.0, Input.is_action_pressed("speed_up"))
	check(not audio.boost_active and cues.count(&"boost") == 2, "Waiting at restaurant suppresses boost audio")
	Input.action_release("speed_up")
	reset()
	Input.action_press("speed_up")
	game.courier.update(0.0, Input.is_action_pressed("speed_up"))
	check(cues.is_empty(), "Idle courier does not play boost audio")
	Input.action_release("speed_up")
	Input.action_press("time_slow")
	game._process(0.4)
	check(is_equal_approx(audio.music_player.pitch_scale, 0.5), "Ctrl gradually lowers BGM pitch")
	Input.action_release("time_slow")
	game._process(0.4)
	check(is_equal_approx(audio.music_player.pitch_scale, 1.0), "Releasing Ctrl restores BGM pitch")

	var mute := InputEventAction.new()
	mute.action = "mute_audio"
	mute.pressed = true
	game._input(mute)
	check(audio.muted and AudioServer.is_bus_mute(music_bus) and AudioServer.is_bus_mute(sfx_bus), "M mutes music and effects")
	game._input(mute)
	check(not audio.muted and not AudioServer.is_bus_mute(music_bus) and not AudioServer.is_bus_mute(sfx_bus), "M restores music and effects")

	reset()
	for next_day in range(2, 6):
		game.day_cycle.begin_rest()
		check(not audio.music_player.playing and not audio.boost_active, "Day end stops gameplay audio")
		game.day_cycle.start_next_day()
		var source := load(audio.DAY_MUSIC[next_day - 1]) as AudioStreamMP3
		check(game.state.day == next_day and audio.current_day == next_day and audio.music_player.playing, "Next day plays track " + str(next_day))
		check(audio.music_player.stream.data == source.data and audio.music_player.stream.loop, "Next day loads and loops the correct original MP3")
		check(not source.loop, "Loop setting does not alter imported source resource")
	game.day_cycle.finish_run()
	check(not audio.music_player.playing, "Final summary stops gameplay music")
	game._input(mute)
	check(audio.muted, "Mute input remains usable on the final summary")
	game.day_cycle.restart()
	check(audio.current_day == 1 and audio.music_player.playing and audio.music_player.pitch_scale == 1.0, "New game restarts day one music at normal speed")
	check(audio.muted and AudioServer.is_bus_mute(music_bus), "Restart preserves the player's mute choice")
	game._input(mute)
	game.queue_free()
	await process_frame
	# Playback disposal is completed on the mixer thread after nodes stop.
	await create_timer(0.1).timeout
	print("AUDIO REGRESSION RESULT: %s (%d checks)" % ["PASS" if errors == 0 else "FAIL", checks])
	quit(0 if errors == 0 else 1)
