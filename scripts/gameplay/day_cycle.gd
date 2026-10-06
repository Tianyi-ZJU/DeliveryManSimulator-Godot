extends RefCounted

## Five-day lifecycle, weather selection, upgrades and resetting a run.
signal weather_changed(weather: String)
signal rest_started()
signal day_started(day: int)
signal run_finished()
signal run_restarted()
signal changed()
signal feedback(event: StringName, values: Dictionary)
signal cue_requested(cue: StringName)
const GameState := preload("res://scripts/core/game_state.gd")
const Config := preload("res://scripts/core/game_config.gd")
var state: GameState

func _init(shared_state: GameState) -> void:
	state = shared_state

func _notify(event: StringName, values: Dictionary = {}) -> void:
	feedback.emit(event, values)

func choose_weather() -> void:
	if state.day == 1:
		state.weather = "晴天"
		state.weather_speed_factor = 1.0
		state.weather_price_bonus = 0
		weather_changed.emit(state.weather)
		return
	var roll := randi_range(0, 99)
	state.weather = "多云" if roll < 28 else ("雨天" if roll < 56 else ("雾天" if roll < 84 else "晴天"))
	state.weather_speed_factor = 0.77 if state.weather == "雨天" else (0.88 if state.weather == "雾天" else 1.0)
	state.weather_price_bonus = 17 if state.weather == "雨天" else 0
	weather_changed.emit(state.weather)

func time_scale(delta: float, slowing: bool) -> float:
	if slowing and state.slow_energy > 0.0:
		state.slow_energy = maxf(0.0, state.slow_energy - delta * 2.0)
		return 0.2
	return 1.0

func advance_clock(delta: float) -> bool:
	state.slow_energy = minf(state.slow_energy_max, state.slow_energy + delta * 0.15)
	state.clock_accumulator += delta
	while state.clock_accumulator >= state.minute_seconds:
		state.clock_accumulator -= state.minute_seconds
		state.clock_minutes += 1
		if auto_settle():
			return true
	return false

func auto_settle() -> bool:
	if state.clock_minutes >= 21 * 60 and can_settle():
		finish_day()
		return true
	return false

func can_settle() -> bool:
	return not state.upgrade_visible and not state.game_finished and state.clock_minutes >= 19 * 60 and state.orders.is_empty() and state.tasks.is_empty() and state.wait_order.is_empty()

func request_settlement() -> void:
	if not can_settle():
		return
	finish_day()
	cue_requested.emit(&"button")

func finish_day() -> void:
	if not can_settle():
		return
	if state.day >= 5:
		finish_run()
	else:
		begin_rest()

func purchase(kind: String) -> void:
	if not state.upgrade_visible:
		return
	if int(state.upgrades_remaining[kind]) <= 0:
		_notify(&"max_upgrade")
		return
	if state.purchases_left <= 0:
		_notify(&"purchases_used")
		return
	if state.money < 100:
		_notify(&"funds", {"money": state.money})
		return
	state.money -= 100
	state.purchases_left -= 1
	cue_requested.emit(&"button")
	state.upgrades_remaining[kind] -= 1
	if kind == "speed":
		state.courier_speed += 4.0
	elif kind == "capacity":
		state.capacity += 1
	elif kind == "speed_energy":
		state.speed_energy_max += 20.0
	else:
		state.slow_energy_max += 15.0
	changed.emit()
	var upgrade_names := {"speed": "速度 +4", "capacity": "容量 +1", "speed_energy": "加速能量 +20", "slow_energy": "慢时能量 +15"}
	_notify(&"upgraded", {"upgrade": upgrade_names[kind]})

func begin_rest() -> void:
	if state.upgrade_visible:
		return
	state.upgrade_visible = true
	state.purchases_left = 2
	rest_started.emit()

func start_next_day() -> void:
	if state.game_finished or state.day >= 5:
		return
	state.day += 1
	state.day_start_finished = state.finished_count
	state.day_start_money = state.money
	state.clock_minutes = 10 * 60
	state.clock_accumulator = 0.0
	state.orders.clear()
	state.tasks.clear()
	state.occupied = 0
	state.courier_pos = Config.COURIER_SPAWN
	state.courier_route.clear()
	state.wait_order = {}
	state.speed_energy = state.speed_energy_max
	state.slow_energy = state.slow_energy_max
	state.generated_timer = 3.0
	choose_weather()
	state.upgrade_visible = false
	day_started.emit(state.day)

func finish_run() -> void:
	if state.game_finished:
		return
	state.game_finished = true
	state.courier_route.clear()
	run_finished.emit()

func restart() -> void:
	state.reset_run()
	choose_weather()
	run_restarted.emit()
	day_started.emit(state.day)
