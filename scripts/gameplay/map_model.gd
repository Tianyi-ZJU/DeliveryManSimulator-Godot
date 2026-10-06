extends RefCounted

## Map data and both routing graphs use the same projection as map hit testing.
const Config := preload("res://scripts/core/game_config.gd")
const RoadGraph := preload("res://scripts/road_graph.gd")
const VisualRoadGraph := preload("res://scripts/visual_road_graph.gd")
const MAP_PATH := "res://data/map.json"
const VISUAL_WAYPOINTS_PATH := "res://data/visual_waypoints.json"

var map_data: Dictionary = {}
var waypoints: Array = []
var roads: Array = []
var runtime_waypoints: Array = []
var vertex_min := Config.VIEW_WORLD_MIN
var vertex_max := Config.VIEW_WORLD_MAX
var road_graph := RoadGraph.new()
var visual_road_graph := VisualRoadGraph.new()

func load_data() -> void:
	map_data = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	if map_data.is_empty():
		map_data = {"waypoints": [], "roads": []}
	waypoints = map_data.get("waypoints", [])
	roads = map_data.get("roads", [])
	runtime_waypoints = waypoints.duplicate(true)
	var visual_waypoint_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(VISUAL_WAYPOINTS_PATH))
	if visual_waypoint_data is Dictionary and visual_waypoint_data.get("waypoints", []).size() == waypoints.size():
		runtime_waypoints = visual_waypoint_data["waypoints"]
	road_graph.build(map_data)
	visual_road_graph.load_mask()

func waypoint(point_id: int) -> Dictionary:
	return runtime_waypoints[point_id].duplicate()

func world_to_screen(world: Vector2) -> Vector2:
	var normalized := Vector2((world.x - vertex_min.x) / (vertex_max.x - vertex_min.x), 1.0 - (world.y - vertex_min.y) / (vertex_max.y - vertex_min.y))
	return Config.MAP_MARGIN.position + normalized * Config.MAP_MARGIN.size

func screen_to_world(screen: Vector2) -> Vector2:
	var normalized := (screen - Config.MAP_MARGIN.position) / Config.MAP_MARGIN.size
	return Vector2(lerpf(vertex_min.x, vertex_max.x, normalized.x), lerpf(vertex_max.y, vertex_min.y, normalized.y))
