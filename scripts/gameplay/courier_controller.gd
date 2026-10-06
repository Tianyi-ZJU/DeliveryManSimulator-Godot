extends RefCounted

## Courier routing/movement. Completing an order is handled by OrderSystem.
signal destination_reached()
signal boost_changed(active: bool)
const GameState := preload("res://scripts/core/game_state.gd")
const MapModel := preload("res://scripts/gameplay/map_model.gd")
var state: GameState
var map_model: MapModel

func _init(shared_state: GameState, shared_map: MapModel) -> void:
	state = shared_state
	map_model = shared_map

func update_energy(delta: float, boosting: bool) -> void:
	if boosting and state.speed_energy > 0.0 and not state.courier_route.is_empty():
		state.speed_energy = maxf(0.0, state.speed_energy - delta * 5.0)
	state.speed_energy = minf(state.speed_energy_max, state.speed_energy + delta * 20.0 / 60.0)

func update(delta: float, boosting: bool) -> void:
	var moving := state.wait_order.is_empty() and not state.courier_route.is_empty() and state.courier_route_index < state.courier_route.size()
	boost_changed.emit(moving and boosting and state.speed_energy > 0.0)
	if not state.wait_order.is_empty():
		return
	if state.courier_route.is_empty() or state.courier_route_index >= state.courier_route.size():
		return
	var target := state.courier_route[state.courier_route_index]
	var boost := 2.4 if boosting and state.speed_energy > 0.0 else 1.0
	state.courier_pos = state.courier_pos.move_toward(target, state.courier_speed * state.weather_speed_factor * boost * delta)
	if state.courier_pos.distance_to(target) < 0.18:
		state.courier_route_index += 1
		if state.courier_route_index >= state.courier_route.size():
			destination_reached.emit()

func begin_next_task() -> void:
	if state.tasks.is_empty() or not state.courier_route.is_empty() or not state.wait_order.is_empty():
		return
	var task: Dictionary = state.tasks[0]
	var point: Dictionary = task["order"]["from"] if task["kind"] == "取餐" else task["order"]["to"]
	state.courier_target = int(point["id"])
	state.courier_target_kind = task["kind"]
	var visual_route: Array[Vector2] = map_model.visual_road_graph.route_from(state.courier_pos, Vector2(float(point["x"]), float(point["y"])))
	state.courier_route = visual_route if not visual_route.is_empty() else map_model.road_graph.route_from(state.courier_pos, int(point["id"]))
	state.courier_route_index = 0
	if state.courier_route.is_empty() and state.courier_pos.distance_to(Vector2(float(point["x"]), float(point["y"]))) < 0.2:
		destination_reached.emit()
