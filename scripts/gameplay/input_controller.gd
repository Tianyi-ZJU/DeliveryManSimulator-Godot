extends RefCounted

## Translate map clicks, task drags and keyboard actions into gameplay commands.
signal mute_requested()
signal waiting_changed()
signal redraw_requested()
signal feedback(event: StringName, values: Dictionary)
signal cue_requested(cue: StringName)
const GameState := preload("res://scripts/core/game_state.gd")
const MapModel := preload("res://scripts/gameplay/map_model.gd")
const OrderSystem := preload("res://scripts/gameplay/order_system.gd")
const DayCycle := preload("res://scripts/gameplay/day_cycle.gd")
var state: GameState
var map_model: MapModel
var orders: OrderSystem
var days: DayCycle
var hover_order_id := -1
var hover_kind := ""
var task_drag_index := -1
var task_drag_origin := Vector2.ZERO
var task_dragged := false

func _init(shared_state: GameState, shared_map: MapModel, order_system: OrderSystem, day_cycle: DayCycle) -> void:
	state = shared_state
	map_model = shared_map
	orders = order_system
	days = day_cycle

func _notify(event: StringName, values: Dictionary = {}) -> void:
	feedback.emit(event, values)

func handle_unhandled(event: InputEvent) -> void:
	if state.game_finished:
		return
	if state.upgrade_visible:
		if event.is_action_pressed("urge"):
			days.start_next_day()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		days.finish_run()
		return
	if event.is_action_pressed("urge"):
		if not state.wait_order.is_empty():
			state.wait_until -= 2
			cue_requested.emit(&"late")
			_notify(&"urged")
			waiting_changed.emit()
		else:
			days.request_settlement()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for order in state.orders:
			for kind in ["from", "to"]:
				if kind == "from" and order["state"] == "picked_up":
					continue
				var point: Dictionary = order[kind]
				if map_model.world_to_screen(Vector2(float(point["x"]), float(point["y"]))).distance_to(event.position) < 21.0:
					if order["state"] == "available":
						orders.accept_at(order["from"])
					else:
						for i in state.tasks.size():
							if state.tasks[i]["order"] == order and state.tasks[i]["kind"] == ("取餐" if kind == "from" else "送达"):
								orders.prioritize(i)
								break
					return

func handle_task_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		task_drag_index = index
		task_drag_origin = event.global_position
		task_dragged = false

func handle_global(event: InputEvent, task_box_y: float, viewport: Viewport) -> void:
	if event.is_action_pressed("mute_audio"):
		mute_requested.emit()
		viewport.set_input_as_handled()
		return
	# Capture release globally so dragging outside the original card also works.
	if event is InputEventMouseMotion:
		if task_drag_index >= 0 and event.global_position.distance_to(task_drag_origin) > 8.0:
			task_dragged = true
		update_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and task_drag_index >= 0:
		var from_index := task_drag_index
		task_drag_index = -1
		if task_dragged:
			var target := clampi(int((event.global_position.y - task_box_y) / 100.0), 0, state.tasks.size() - 1)
			orders.move_task(from_index, target)
		else:
			orders.prioritize(from_index)
		task_dragged = false
		viewport.set_input_as_handled()

func update_hover(mouse: Vector2) -> void:
	hover_order_id = -1
	hover_kind = ""
	if mouse.x < 940 and not state.upgrade_visible and not state.game_finished:
		for order in state.orders:
			for kind in ["from", "to"]:
				if kind == "from" and order["state"] == "picked_up" and state.wait_order != order:
					continue
				var point: Dictionary = order[kind]
				if map_model.world_to_screen(Vector2(float(point["x"]), float(point["y"]))).distance_to(mouse) < 21:
					hover_order_id = int(order["id"])
					hover_kind = kind
	redraw_requested.emit()

func set_hover(order_id: int, kind: String) -> void:
	hover_order_id = order_id
	hover_kind = kind
	redraw_requested.emit()
