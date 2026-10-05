extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors := 0
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("MAIN SCENE FAILED TO LOAD")
		errors += 1
	else:
		var node: Node = packed.instantiate()
		root.add_child(node)
		print("SMOKE-NODE ", node.name, " ", node.get_class())
		await process_frame
		await process_frame
		var waypoints: Array = node.get("waypoints") as Array
		var roads: Array = node.get("roads") as Array
		if waypoints.size() != 30:
			push_error("EXPECTED 30 waypoints, GOT %d" % waypoints.size())
			errors += 1
		if roads.size() != 93:
			push_error("EXPECTED 93 roads, GOT %d" % roads.size())
			errors += 1
		if node.get("map_texture") == null:
			push_error("MAP TEXTURE DID NOT LOAD")
			errors += 1
		node.queue_free()
	print("SMOKE RESULT: ", "FAIL" if errors > 0 else "PASS")
	quit(1 if errors > 0 else 0)
