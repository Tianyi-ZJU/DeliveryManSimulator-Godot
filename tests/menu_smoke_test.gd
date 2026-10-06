extends SceneTree

var errors := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors += 1
		push_error(message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/MainMenu.tscn", "F5 boots into the menu")
	var packed := load("res://scenes/MainMenu.tscn") as PackedScene
	if packed == null:
		push_error("MENU SCENE FAILED TO LOAD")
		quit(1)
		return
	var menu := packed.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	check(menu.get_node("Title").text == "DELIVERY MAN SIMULATOR", "English title matches the game name")
	check(root.get_node_or_null("DeliveryManMinimal") == null, "Menu does not start gameplay timers or orders")
	check(menu.start_button.pressed.is_connected(menu._on_start_pressed), "Start button is connected")
	check(menu.exit_button.pressed.is_connected(menu._on_exit_pressed), "Exit button is connected")
	check(menu.music_player.playing and menu.music_player.stream.loop, "Menu music loops")
	# Start.unity's AudioSource references GUID 131196e71ec6c8b4aaddbb03ef9492a7,
	# Assets/Resources/BGM/BGM1.mp3, rather than the similarly named menu.mp3.
	var music_hash := HashingContext.new()
	music_hash.start(HashingContext.HASH_SHA256)
	music_hash.update(menu.music_player.stream.data)
	check(music_hash.finish().hex_encode() == "1576aaa4a5c489c462192c05aa47a43947774d869bd4b298cacc89dec719e235", "Menu plays the original Unity startup track without re-encoding")
	check(menu.music_player.pitch_scale == 1.0, "Menu music plays at the original speed")
	check(menu.button_player.stream != null, "Menu button sound loads")
	var sky := menu.get_node("Sky") as TextureRect
	var horizon := sky.texture as AtlasTexture
	check(horizon != null and horizon.region.position.y > 2000.0, "Sky crops the mountain horizon instead of showing only blue sky")
	check(absf(sky.size.x / sky.size.y - horizon.region.size.x / horizon.region.size.y) < 0.01, "Mountain photograph retains its aspect ratio")
	var road_view := menu.get_node("RoadView/RoadViewport") as SubViewport
	check(road_view.transparent_bg, "Road viewport allows the horizon to remain visible")
	var camera := road_view.get_node("UnityStartCamera") as Camera3D
	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE and camera.fov == 60.0, "Road view uses the original perspective field of view")
	var badges: Array[Sprite3D] = []
	var badge_anchors: Array[Vector3] = []
	var projected_diameters: Array[float] = []
	for marker_name: String in ["HomeMarker", "RestaurantMarker"]:
		var badge := road_view.get_node(marker_name) as Sprite3D
		var icon := badge.get_node("Icon") as Sprite3D
		badges.append(badge)
		badge_anchors.append(badge.position)
		var icon_size := icon.get_aabb().size
		check(Vector2(icon_size.x, icon_size.y).length() < badge.texture.get_width() * badge.pixel_size * (480.0 / 512.0), marker_name + " icon fits inside its circle")
		check(icon.position == Vector3.ZERO, marker_name + " icon is centered")
		check(badge.billboard == BaseMaterial3D.BILLBOARD_ENABLED and icon.billboard == BaseMaterial3D.BILLBOARD_ENABLED, marker_name + " circle and icon face the camera without distortion")
		var half_width := badge.get_aabb().size.x * 0.5
		projected_diameters.append(camera.unproject_position(badge.position + camera.basis.x * half_width).distance_to(camera.unproject_position(badge.position - camera.basis.x * half_width)))
	check(projected_diameters[1] < projected_diameters[0] * 0.85, "Farther restaurant appears smaller than the home through perspective")
	var marker := road_view.get_node("RouteMarker") as MeshInstance3D
	var road := road_view.get_node("RoadSprite") as Sprite3D
	check(marker.rotation == road.rotation and absf(marker.position.z - road.position.z) < 0.05, "Blue marker shares the map plane and camera perspective")

	# Advance two minutes without waiting. A map tour must cover real distance,
	# turn smoothly, stay over the ground, and preserve the clickable UI layout.
	var title_position: Vector2 = menu.get_node("Title").position
	var start_position: Vector2 = menu.start_button.position
	var exit_position: Vector2 = menu.exit_button.position
	var road_box := road.get_aabb()
	var road_rect := Rect2(Vector2(road.position.x + road_box.position.x, road.position.y + road_box.position.y), Vector2(road_box.size.x, road_box.size.y))
	var floor_points: Array[Vector2] = [Vector2(0.0, 250.0), Vector2(1280.0, 250.0), Vector2(0.0, 675.0), Vector2(1280.0, 675.0)]
	var bounded := true
	var ground_covered := true
	var sky_covered := true
	var marker_left_view := false
	var marker_returned := false
	var badges_attached := true
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	var previous_position: Vector3 = menu.camera_origin
	var previous_velocity := Vector3.ZERO
	var steady_motion := true
	var smooth_turns := true
	menu.camera_elapsed = 0.0
	menu._update_menu_motion(0.0)
	for sample: int in range(480):
		menu._update_menu_motion(0.25)
		var drift: Vector3 = camera.position - menu.camera_origin
		minimum = minimum.min(drift)
		maximum = maximum.max(drift)
		bounded = bounded and drift.is_finite() and absf(drift.x) < 6.6 and drift.y >= -0.01 and drift.y < 9.1 and drift.z > -0.71 and drift.z <= 0.01
		var velocity := (camera.position - previous_position) / 0.25
		if menu.camera_elapsed > 8.0:
			steady_motion = steady_motion and velocity.length() > 0.5 and velocity.length() < 0.8
			if previous_velocity.length() > 0.5:
				smooth_turns = smooth_turns and velocity.normalized().dot(previous_velocity.normalized()) > 0.99
		previous_position = camera.position
		previous_velocity = velocity
		for screen_point: Vector2 in floor_points:
			var map_point: Vector3 = menu._map_point_at(screen_point)
			ground_covered = ground_covered and road_rect.has_point(Vector2(map_point.x, map_point.y))
		sky_covered = sky_covered and Rect2(sky.position, sky.size).encloses(Rect2(Vector2.ZERO, Vector2(1280.0, 250.0)))
		var marker_visible := Rect2(Vector2.ZERO, Vector2(road_view.size)).has_point(camera.unproject_position(marker.position))
		marker_returned = marker_returned or (marker_left_view and marker_visible)
		marker_left_view = marker_left_view or not marker_visible
		for index: int in range(badges.size()):
			badges_attached = badges_attached and badges[index].position == badge_anchors[index]
	check((maximum - minimum).x > 10.0 and (maximum - minimum).y > 7.0, "Camera tours a wide area instead of wobbling around one point")
	check(steady_motion, "Camera keeps moving through turns after the startup ramp")
	check(smooth_turns, "Tour direction changes continuously without sudden reversals")
	check(bounded, "Two-minute camera tour stays finite and within the map region")
	check(ground_covered and sky_covered, "Tour never exposes empty ground or skyline edges")
	check(marker_returned, "Foreground marker naturally returns into view on the next tour")
	check(badges_attached, "Place badges remain fixed in the map viewport during the tour")
	check(menu.get_node("Title").position == title_position and menu.start_button.position == start_position and menu.exit_button.position == exit_position, "Title and buttons stay still during the tour")

	if OS.get_cmdline_user_args().has("--test-exit"):
		if errors > 0:
			quit(1)
			return
		print("MENU EXIT: requesting quit through the Exit button")
		menu.exit_button.pressed.emit()
		await create_timer(0.5).timeout
		push_error("MENU EXIT RESULT: FAIL (window stayed open)")
		quit(1)
		return

	# Emit the same signal as a real click and check the resulting gameplay scene.
	menu.start_button.pressed.emit()
	check(menu.leaving_menu and menu.start_button.disabled and menu.exit_button.disabled, "Repeated clicks are blocked during scene transition")
	await create_timer(0.3).timeout
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/Main.tscn", "Start enters the existing gameplay scene")
	check(not is_instance_valid(menu), "Menu and its music player are released after Start")
	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	print("MENU SMOKE RESULT: ", "FAIL" if errors > 0 else "PASS", " (", checks, " checks)")
	quit(1 if errors > 0 else 0)
