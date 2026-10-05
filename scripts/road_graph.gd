extends RefCounted

## Preserve the Unity road graph, including waypoints located inside edges.
## Integer graph IDs are local; Unity prefab IDs stay strings to avoid JSON float loss.
var graph := AStar2D.new()
var waypoint_nodes: Dictionary = {}
var segments: Array = []
var temporary_id := -1

func build(data: Dictionary) -> void:
	graph.clear()
	waypoint_nodes.clear()
	segments.clear()
	var vertex_nodes: Dictionary = {}
	var vertices: Array = data["vertices"]
	var vertex_ids: Array = data["vertex_ids"]
	for i in vertices.size():
		vertex_nodes[String(vertex_ids[i])] = i
		graph.add_point(i, Vector2(float(vertices[i][0]), float(vertices[i][1])))
	for point in data["waypoints"]:
		var node_id: int = graph.get_point_count()
		waypoint_nodes[int(point["id"])] = node_id
		graph.add_point(node_id, Vector2(float(point["x"]), float(point["y"])))
	for road in data["roads"]:
		var chain: Array = [{"id": vertex_nodes[String(road["start"])], "ratio": 0.0}, {"id": vertex_nodes[String(road["end"])], "ratio": 1.0}]
		for point in data["waypoints"]:
			if point["road"] == road["instance"]:
				chain.append({"id": waypoint_nodes[int(point["id"])], "ratio": float(point["ratio"])})
		chain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ratio"]) < float(b["ratio"]))
		for i in range(chain.size() - 1):
			var a: int = chain[i]["id"]
			var b: int = chain[i + 1]["id"]
			graph.connect_points(a, b)
			segments.append({"a": a, "b": b})
	temporary_id = graph.get_point_count()

func route_from(position: Vector2, waypoint_id: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not waypoint_nodes.has(waypoint_id) or segments.is_empty():
		return result
	var nearest: Dictionary = {}
	var best_distance := INF
	for segment in segments:
		var a := graph.get_point_position(int(segment["a"]))
		var b := graph.get_point_position(int(segment["b"]))
		var projection := Geometry2D.get_closest_point_to_segment(position, a, b)
		var distance := position.distance_squared_to(projection)
		if distance < best_distance:
			best_distance = distance
			nearest = segment
	graph.add_point(temporary_id, position)
	graph.connect_points(temporary_id, int(nearest["a"]))
	graph.connect_points(temporary_id, int(nearest["b"]))
	var path := graph.get_point_path(temporary_id, int(waypoint_nodes[waypoint_id]))
	graph.remove_point(temporary_id)
	for point in path:
		if position.distance_to(point) > 0.001 or not result.is_empty():
			result.append(point)
	return result
