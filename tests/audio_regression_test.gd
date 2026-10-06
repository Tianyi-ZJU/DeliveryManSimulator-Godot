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
	game._restart_game()
	game.generated_timer = 999.0
	cues.clear()

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.generated_timer = 999.0
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

	var order: Dictionary = game.create_order(14, 21, 1, 46)
	game._accept_order_at(order["from"])
	check(cues == [&"accept"] and audio.effect_players[&"accept"].playing, "Accepting an order starts the original bell")
	game.capacity = 1
	var refused: Dictionary = game.create_order(3, 26, 1, 40)
	game._accept_order_at(refused["from"])
	check(cues == [&"accept"], "Refused order does not play acceptance audio")
	game._arrive_at_target()
	check(cues == [&"accept", &"pickup"], "Pickup starts its cue")
	game._arrive_at_target()
	check(cues == [&"accept", &"pickup", &"delivery"] and audio.effect_players[&"delivery"].playing, "Delivery starts original coin audio")

	reset()
	order = game.create_order(14, 21, 1, 46)
	game._accept_order_at(order["from"])
	game.clock_minutes = 721
	game._update_orders(0.0)
	check(cues.count(&"late") == 1, "Crossing deadline plays late audio")
	game._update_orders(0.0)
	check(cues.count(&"late") == 1, "Late audio does not repeat every frame")
	game.wait_order = order
	game.wait_until = 740
	var urge := InputEventAction.new()
	urge.action = "urge"
	urge.pressed = true
	game._unhandled_input(urge)
	check(cues.count(&"late") == 2, "Urging plays original voice audio")

	reset()
	order = game.create_order(14, 21, 1, 46)
	game._accept_order_at(order["from"])
	Input.action_press("speed_up")
	game._update_courier(0.0)
	game._update_courier(0.0)
	check(cues.count(&"boost") == 1, "Holding Shift plays one acceleration cue")
	Input.action_release("speed_up")
	game._update_courier(0.0)
	Input.action_press("speed_up")
	game._update_courier(0.0)
	check(cues.count(&"boost") == 2, "Pressing Shift again plays a new cue")
	game.wait_order = order
	game._update_courier(0.0)
	check(not audio.boost_active and cues.count(&"boost") == 2, "Waiting at restaurant suppresses boost audio")
	Input.action_release("speed_up")
	reset()
	Input.action_press("speed_up")
	game._update_courier(0.0)
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
		game._show_upgrade()
		check(not audio.music_player.playing and not audio.boost_active, "Day end stops gameplay audio")
		game._start_next_day()
		var source := load(audio.DAY_MUSIC[next_day - 1]) as AudioStreamMP3
		check(game.day == next_day and audio.current_day == next_day and audio.music_player.playing, "Next day plays track " + str(next_day))
		check(audio.music_player.stream.data == source.data and audio.music_player.stream.loop, "Next day loads and loops the correct original MP3")
		check(not source.loop, "Loop setting does not alter imported source resource")
	game._show_end()
	check(not audio.music_player.playing, "Final summary stops gameplay music")
	game._input(mute)
	check(audio.muted, "Mute input remains usable on the final summary")
	game._restart_game()
	check(audio.current_day == 1 and audio.music_player.playing and audio.music_player.pitch_scale == 1.0, "New game restarts day one music at normal speed")
	check(audio.muted and AudioServer.is_bus_mute(music_bus), "Restart preserves the player's mute choice")
	game._input(mute)
	game.queue_free()
	await process_frame
	# Playback disposal is completed on the mixer thread after nodes stop.
	await create_timer(0.1).timeout
	print("AUDIO REGRESSION RESULT: %s (%d checks)" % ["PASS" if errors == 0 else "FAIL", checks])
	quit(0 if errors == 0 else 1)
