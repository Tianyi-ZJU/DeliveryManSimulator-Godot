extends RefCounted

## Routes against the roads visible in background_ui.png.
## The original Unity graph is kept separately for migration regression checks;
## this graph is used by the playable courier so the route follows the art.

const DEFAULT_MASK_PATH := "res://data/visual_road_mask.json"

var grid := AStarGrid2D.new()
var open_cells: Array[Vector2i] = []
var width := 0
var height := 0
var cell_pixels := 4.0
var texture_size := Vector2.ZERO
var background_center := Vector2.ZERO
var background_size := Vector2.ZERO
var loaded := false

func load_mask(path: String = DEFAULT_MASK_PATH) -> bool:
	loaded = false
	open_cells.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed
	width = int(data.get("width", 0))
	height = int(data.get("height", 0))
	cell_pixels = float(data.get("cell_pixels", 4.0))
	texture_size = Vector2(float(data.get("texture_width", 0)), float(data.get("texture_height", 0)))
	var center: Array = data.get("background_center", [0.0, 0.0])
	var size: Array = data.get("background_size", [0.0, 0.0])
	if center.size() < 2 or size.size() < 2 or width <= 0 or height <= 0 or cell_pixels <= 0.0:
		return false
	background_center = Vector2(float(center[0]), float(center[1]))
	background_size = Vector2(float(size[0]), float(size[1]))
	var rows: Array = data.get("rows", [])
	if rows.size() != height:
		return false

	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.jumping_enabled = false
	grid.update()
	for y in height:
		var row := String(rows[y])
		if row.length() != width:
			return false
		for x in width:
			var walkable := row.substr(x, 1) == "1"
			var cell := Vector2i(x, y)
			grid.set_point_solid(cell, not walkable)
			if walkable:
				open_cells.append(cell)
	loaded = not open_cells.is_empty()
	return loaded

func world_to_cell(world: Vector2) -> Vector2i:
	if not loaded:
		return Vector2i.ZERO
	var pixel := Vector2(
		(world.x - (background_center.x - background_size.x * 0.5)) / background_size.x * texture_size.x,
		(background_center.y + background_size.y * 0.5 - world.y) / background_size.y * texture_size.y
	)
	return Vector2i(
		clampi(int(floor(pixel.x / cell_pixels)), 0, width - 1),
		clampi(int(floor(pixel.y / cell_pixels)), 0, height - 1)
	)

func cell_to_world(cell: Vector2i) -> Vector2:
	var pixel := Vector2((float(cell.x) + 0.5) * cell_pixels, (float(cell.y) + 0.5) * cell_pixels)
	return Vector2(
		background_center.x - background_size.x * 0.5 + pixel.x / texture_size.x * background_size.x,
		background_center.y + background_size.y * 0.5 - pixel.y / texture_size.y * background_size.y
	)

func nearest_open_cell(world: Vector2) -> Vector2i:
	if not loaded:
		return Vector2i.ZERO
	var target := world_to_cell(world)
	var nearest := open_cells[0]
	var best_distance := INF
	for cell in open_cells:
		var distance := Vector2(target).distance_squared_to(Vector2(cell))
		if distance < best_distance:
			best_distance = distance
			nearest = cell
	return nearest

func route_from(position: Vector2, target: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not loaded:
		return result
	var start := nearest_open_cell(position)
	var goal := nearest_open_cell(target)
	var path: Array[Vector2i] = grid.get_id_path(start, goal)
	if path.is_empty():
		return result
	for cell in _simplify_path(path):
		var point := cell_to_world(cell)
		if result.is_empty() or result[-1].distance_to(point) > 0.05:
			result.append(point)
	# Waypoint icons can sit just outside the painted road. Keep the exact
	# destination as a short final approach so existing arrival logic is intact.
	if result.is_empty() or result[-1].distance_to(target) > 0.05:
		result.append(target)
	return result

func _line_is_walkable(start: Vector2i, end: Vector2i) -> bool:
	var x: int = start.x
	var y: int = start.y
	var target_x: int = end.x
	var target_y: int = end.y
	var delta_x: int = absi(target_x - x)
	var delta_y: int = absi(target_y - y)
	var step_x: int = 1 if x < target_x else -1
	var step_y: int = 1 if y < target_y else -1
	var error: int = delta_x - delta_y
	while true:
		if grid.is_point_solid(Vector2i(x, y)):
			return false
		if x == target_x and y == target_y:
			return true
		var double_error: int = error * 2
		if double_error > -delta_y and double_error < delta_x:
			if grid.is_point_solid(Vector2i(x + step_x, y)) or grid.is_point_solid(Vector2i(x, y + step_y)):
				return false
		if double_error > -delta_y:
			error -= delta_y
			x += step_x
		if double_error < delta_x:
			error += delta_x
			y += step_y
	return false

func _simplify_path(path: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if path.is_empty():
		return result
	var anchor_index: int = 0
	result.append(path[0])
	while anchor_index < path.size() - 1:
		var furthest_index: int = anchor_index + 1
		for candidate_index in range(path.size() - 1, anchor_index, -1):
			if _line_is_walkable(path[anchor_index], path[candidate_index]):
				furthest_index = candidate_index
				break
		result.append(path[furthest_index])
		anchor_index = furthest_index
	return result

func route_segments_follow_road(route: Array[Vector2]) -> bool:
	if route.size() < 2:
		return false
	# The final segment may be a short approach from the road to an icon.
	for i in range(maxi(0, route.size() - 2)):
		if not _line_is_walkable(world_to_cell(route[i]), world_to_cell(route[i + 1])):
			return false
	return true

func is_world_point_near_road(world: Vector2, max_cells: float = 1.5) -> bool:
	if not loaded:
		return false
	var target := Vector2(world_to_cell(world))
	for cell in open_cells:
		if target.distance_to(Vector2(cell)) <= max_cells:
			return true
	return false
