extends RefCounted

## Deterministic regression setup belongs to tests, not the shipping controller.
static func prepare_input(game: Node) -> void:
	game.set_process(false)
	game.state.orders.clear()
	game.state.tasks.clear()
	game.state.courier_route.clear()
	game.state.occupied = 0
	game.input_controller.set_hover(-1, "")
	game.state.clock_minutes = 637
	game.order_system.create_order(14, 21, 1, 46, 120, 1)
	game.state.courier_pos = Vector2(-24.7, -35.0)
	game.refresh_views()
	game.notifications.clear()
	game.queue_redraw()

static func prepare_visual(game: Node) -> void:
	prepare_input(game)
	game.order_system.accept_at(game.state.orders[0]["from"])
	game.refresh_views()
	game.notifications.clear()
	game.queue_redraw()
