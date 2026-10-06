extends RefCounted

## Map -> atmosphere -> route -> order markers -> courier. HUD is drawn later.
const Config := preload("res://scripts/core/game_config.gd")
const GameState := preload("res://scripts/core/game_state.gd")
const MapModel := preload("res://scripts/gameplay/map_model.gd")
const GameAssets := preload("res://scripts/presentation/game_assets.gd")
const WeatherAtmosphere := preload("res://scripts/weather_atmosphere.gd")
var state: GameState
var map_model: MapModel
var assets: GameAssets
var weather_atmosphere: WeatherAtmosphere

func _init(shared_state: GameState, shared_map: MapModel, shared_assets: GameAssets, atmosphere: WeatherAtmosphere) -> void:
	state = shared_state
	map_model = shared_map
	assets = shared_assets
	weather_atmosphere = atmosphere

func draw_on(canvas: CanvasItem, hover_order_id: int, hover_kind: String) -> void:
	canvas.draw_rect(Config.MAP_MARGIN, Color("#243246"))
	if assets.map_texture:
		var world_size := assets.map_texture.get_size() / 10.0 * Vector2(1.1939985, 1.183636)
		var center := Vector2(9.2519, -9.3247)
		var top_left := map_model.world_to_screen(center + Vector2(-world_size.x, world_size.y) * 0.5)
		canvas.draw_texture_rect(assets.map_texture, Rect2(top_left, world_size * Config.MAP_MARGIN.size.y / (2.0 * Config.CAMERA_HALF_HEIGHT)), false)
	if not state.upgrade_visible and not state.game_finished:
		weather_atmosphere.draw_on(canvas)
	if not state.courier_route.is_empty() and state.courier_route_index < state.courier_route.size():
		var route_points := PackedVector2Array([map_model.world_to_screen(state.courier_pos)])
		for i in range(state.courier_route_index, state.courier_route.size()):
			route_points.append(map_model.world_to_screen(state.courier_route[i]))
		canvas.draw_polyline(route_points, Color.YELLOW, 2.1, true)
	for order in state.orders:
		var tint: Color = Config.COLORS[int(order["color_index"])]
		for kind in ["from", "to"]:
			if kind == "from" and order["state"] == "picked_up" and state.wait_order != order:
				continue
			var point: Dictionary = order[kind]
			var pos := map_model.world_to_screen(Vector2(float(point["x"]), float(point["y"])))
			var icon: Texture2D = assets.restaurant_texture if kind == "from" else assets.home_texture
			var icon_size := Vector2.ONE * (32.0 if kind == "from" else 38.0)
			var scale_factor := 1.0
			if int(order["id"]) == hover_order_id and kind == hover_kind:
				scale_factor = 1.5 if (order["state"] == "available") == (kind == "from") else 1.9
				icon_size *= scale_factor
			if icon:
				canvas.draw_texture_rect(icon, Rect2(pos - icon_size * 0.5, icon_size), false, tint)
			if kind == "from" and order["state"] == "available":
				var level := int(order["level"])
				if level <= 3 and assets.star_texture:
					for star_index in level:
						var offset := Vector2((star_index - (level - 1) * 0.5) * 11.0, -25.0)
						canvas.draw_texture_rect(assets.star_texture, Rect2(pos + offset - Vector2(5, 5), Vector2(10, 10)), false, tint)
				else:
					var badge: Texture2D = assets.assigned_texture if level == 4 else assets.fire_texture
					if badge:
						canvas.draw_texture_rect(badge, Rect2(pos + Vector2(-24, -30), Vector2(18, 18)), false, tint)
			var progress := 0.0
			var ring_color := tint
			if kind == "from" and state.wait_order == order:
				progress = clampf(float(state.wait_until - state.clock_minutes) / float(17 + 3 * (state.day - 1)), 0.0, 1.0)
				ring_color = Color.RED
			elif order["state"] == "available" and kind == "from":
				progress = float(order["accept_timer"]) / float(order["lifetime"])
			elif order["state"] != "available" and kind == "to":
				progress = clampf(float(order["deadline"] - state.clock_minutes) / maxf(1.0, float(order["deadline"] - order["accepted_at"])), 0.0, 1.0)
				if order["late"]:
					ring_color = Color.RED
					progress = clampf(float(state.clock_minutes - order["deadline"]) / (float(order["duration"]) / 2.0), 0.0, 1.0)
			if progress > 0.0:
				canvas.draw_arc(pos, 18.0 * scale_factor, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, ring_color, 2.0, true)
	var courier_screen := map_model.world_to_screen(state.courier_pos)
	canvas.draw_circle(courier_screen, 10.0, Color("#dddddd"))
	canvas.draw_circle(courier_screen, 7.5, Color("#499bd6"))
