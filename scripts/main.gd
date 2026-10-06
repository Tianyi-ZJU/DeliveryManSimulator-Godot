extends Node2D

## Composition root: owns one run, wires modules and schedules each frame.
## Rules live in gameplay; views read shared state and emit player commands.
const Config := preload("res://scripts/core/game_config.gd")
const GameState := preload("res://scripts/core/game_state.gd")
const MapModel := preload("res://scripts/gameplay/map_model.gd")
const OrderSystem := preload("res://scripts/gameplay/order_system.gd")
const CourierController := preload("res://scripts/gameplay/courier_controller.gd")
const DayCycle := preload("res://scripts/gameplay/day_cycle.gd")
const InputController := preload("res://scripts/gameplay/input_controller.gd")
const GameAssets := preload("res://scripts/presentation/game_assets.gd")
const MapRenderer := preload("res://scripts/presentation/map_renderer.gd")
const GameHUD := preload("res://scripts/ui/game_hud.gd")
const RestScreen := preload("res://scripts/ui/rest_screen.gd")
const EndSummary := preload("res://scripts/ui/end_summary.gd")
const GameAudio := preload("res://scripts/game_audio.gd")
const NotificationCenter := preload("res://scripts/notification_center.gd")
const WeatherAtmosphere := preload("res://scripts/weather_atmosphere.gd")
const Leaderboard := preload("res://scripts/online/leaderboard_controller.gd")

var state := GameState.new()
var map_model := MapModel.new()
var assets := GameAssets.new()
var order_system := OrderSystem.new(state, map_model)
var courier := CourierController.new(state, map_model)
var day_cycle := DayCycle.new(state)
var input_controller := InputController.new(state, map_model, order_system, day_cycle)
var weather_atmosphere := WeatherAtmosphere.new()
var map_renderer := MapRenderer.new(state, map_model, assets, weather_atmosphere)
var game_audio: GameAudio
var notifications: NotificationCenter
var hud: GameHUD
var rest_screen: RestScreen
var end_summary: EndSummary
var leaderboard: Leaderboard

func _ready() -> void:
	map_model.load_data()
	game_audio = GameAudio.new()
	game_audio.name = "GameAudio"
	add_child(game_audio)
	hud = GameHUD.new(state, assets)
	add_child(hud)
	var notice_layer := CanvasLayer.new()
	notice_layer.name = "Notifications"
	notice_layer.layer = 20
	add_child(notice_layer)
	notifications = NotificationCenter.new()
	notifications.name = "NotificationCenter"
	notifications.theme = hud.theme
	notifications.position = Vector2(24, 24)
	notifications.size = Vector2(280, 627)
	notice_layer.add_child(notifications)
	_connect_modules()
	day_cycle.choose_weather()
	game_audio.play_day(state.day)
	announce_day()
	refresh_views()

func _connect_modules() -> void:
	for system in [order_system, day_cycle, input_controller]:
		system.feedback.connect(notifications.post)
		system.cue_requested.connect(game_audio.play_cue)
	order_system.introduction_requested.connect(notifications.introduce)
	order_system.route_requested.connect(courier.begin_next_task)
	order_system.changed.connect(refresh_views)
	courier.destination_reached.connect(order_system.complete_current_task)
	courier.boost_changed.connect(game_audio.set_boost_active)
	day_cycle.weather_changed.connect(weather_atmosphere.reset)
	day_cycle.rest_started.connect(_on_rest_started)
	day_cycle.day_started.connect(_on_day_started)
	day_cycle.run_finished.connect(_on_run_finished)
	day_cycle.run_restarted.connect(_on_run_restarted)
	day_cycle.changed.connect(refresh_views)
	hud.settle_requested.connect(day_cycle.request_settlement)
	hud.task_list.task_gui_input.connect(input_controller.handle_task_input)
	hud.task_list.task_hovered.connect(input_controller.set_hover)
	input_controller.mute_requested.connect(_toggle_mute)
	input_controller.waiting_changed.connect(refresh_views)
	input_controller.redraw_requested.connect(queue_redraw)

func _process(delta: float) -> void:
	weather_atmosphere.set_running(not state.upgrade_visible and not state.game_finished)
	if state.upgrade_visible or state.game_finished:
		queue_redraw()
		return
	var boosting := Input.is_action_pressed("speed_up")
	var time_factor := day_cycle.time_scale(delta, Input.is_action_pressed("time_slow"))
	var scaled_delta := delta * time_factor
	weather_atmosphere.set_weather(state.weather)
	weather_atmosphere.advance(scaled_delta)
	game_audio.update_music_pitch(time_factor < 1.0, delta)
	if day_cycle.advance_clock(scaled_delta):
		return
	courier.update_energy(scaled_delta, boosting)
	order_system.finish_wait_if_ready()
	order_system.update(scaled_delta)
	if day_cycle.auto_settle():
		return
	courier.update(scaled_delta, boosting)
	order_system.advance_generation(scaled_delta)
	refresh_views()

func _input(event: InputEvent) -> void:
	input_controller.handle_global(event, hud.task_list.task_box.global_position.y, get_viewport())

func _unhandled_input(event: InputEvent) -> void:
	input_controller.handle_unhandled(event)

func refresh_views() -> void:
	notifications.set_waiting(maxi(0, state.wait_until - state.clock_minutes) if not state.wait_order.is_empty() and not state.upgrade_visible and not state.game_finished else -1)
	hud.refresh(day_cycle.can_settle())
	if is_instance_valid(rest_screen):
		rest_screen.refresh()
	courier.begin_next_task()
	queue_redraw()

func announce_day() -> void:
	var event: StringName = NotificationCenter.WEATHER_EVENTS[state.weather]
	if not notifications.introduce(event, {"day": state.day}):
		notifications.post(&"day_started", {"day": state.day, "weather": state.weather})

func _on_rest_started() -> void:
	weather_atmosphere.set_running(false)
	hud.day_close_panel.hide()
	notifications.clear()
	game_audio.stop()
	rest_screen = RestScreen.new(state)
	rest_screen.theme = hud.theme
	rest_screen.purchase_requested.connect(day_cycle.purchase)
	rest_screen.next_day_requested.connect(day_cycle.start_next_day)
	add_child(rest_screen)

func _on_day_started(day: int) -> void:
	if is_instance_valid(rest_screen):
		rest_screen.queue_free()
		rest_screen = null
	game_audio.play_day(day)
	notifications.clear()
	announce_day()
	refresh_views()

func _on_run_finished() -> void:
	weather_atmosphere.set_running(false)
	hud.day_close_panel.hide()
	notifications.clear()
	game_audio.stop()
	end_summary = EndSummary.new(state)
	end_summary.restart_requested.connect(day_cycle.restart)
	end_summary.leaderboard_requested.connect(_open_leaderboard)
	add_child(end_summary)
	queue_redraw()

func _on_run_restarted() -> void:
	if is_instance_valid(leaderboard):
		leaderboard.queue_free()
	if is_instance_valid(end_summary):
		end_summary.queue_free()
		end_summary = null
	notifications.reset_introductions()

func _open_leaderboard(score: int) -> void:
	if not is_instance_valid(end_summary) or is_instance_valid(leaderboard):
		return
	leaderboard = Leaderboard.new(get_node("/root/OnlineService"), score, str(end_summary.get_instance_id()))
	add_child(leaderboard)

func _toggle_mute() -> void:
	var muted := game_audio.toggle_mute()
	notifications.post(&"audio", {"state": "声音已关闭" if muted else "声音已开启", "action": "关闭" if muted else "开启"})

func _draw() -> void:
	map_renderer.draw_on(self, input_controller.hover_order_id, input_controller.hover_kind)
	if is_instance_valid(hud):
		hud.draw_backplates(self)
	if state.game_finished:
		draw_rect(Config.MAP_MARGIN, Color(0.02, 0.04, 0.08, 0.85))
