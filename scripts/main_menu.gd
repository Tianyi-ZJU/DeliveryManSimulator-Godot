extends Control

## Recreates the original game's start screen around its mountain skyline and
## dark blue road plane. The menu stays independent from the gameplay scene so
## opening the game does not start orders, timers, or day music.

const SKY_TEXTURE: Texture2D = preload("res://assets/sky.jpg")
const MAP_TEXTURE: Texture2D = preload("res://assets/background_ui.png")
const MENU_FONT: Font = preload("res://assets/fonts/BarlowCondensed/BarlowCondensed-SemiBold.ttf")
const ROUTE_MARKER_SHADER: Shader = preload("res://shaders/menu_route_marker.gdshader")
const HOME_TEXTURE: Texture2D = preload("res://assets/home.png")
const RESTAURANT_TEXTURE: Texture2D = preload("res://assets/restaurant.png")
const LOCATION_BADGE_TEXTURE: Texture2D = preload("res://assets/menu_location_badge.svg")
const MENU_MUSIC_PATH := "res://assets/audio/menu/menu.mp3"
const BUTTON_SOUND_PATH := "res://assets/audio/menu/button.mp3"
const Leaderboard := preload("res://scripts/online/leaderboard_controller.gd")

const BASE_SIZE := Vector2(1280.0, 675.0)
const SKY_ORIGIN := Vector2(-12.0, -8.0)
const CAMERA_ROAM_SIZE := Vector3(6.5, 4.5, 0.35)
const CAMERA_ROAM_SPEED := 0.65
const CAMERA_START_EASE := 1.6

var music_player: AudioStreamPlayer
var button_player: AudioStreamPlayer
var start_button: Button
var exit_button: Button
var leaderboard_button: Button
var leaderboard: Leaderboard
var leaving_menu := false
var road_camera: Camera3D
var sky_layer: TextureRect
var camera_origin := Vector3.ZERO
var camera_elapsed := 0.0
var camera_roam := Curve3D.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_camera_roam()
	_build_markers()
	_build_title()
	_build_buttons()
	_start_menu_audio()

func _process(delta: float) -> void:
	if not leaving_menu:
		_update_menu_motion(delta)

func _update_menu_motion(delta: float) -> void:
	camera_elapsed += delta
	# Travel at a steady world speed along a broad, closed curve. The short
	# startup ramp eases into the tour; turns never stop or reverse the camera.
	var distance := CAMERA_ROAM_SPEED * (camera_elapsed - CAMERA_START_EASE * (1.0 - exp(-camera_elapsed / CAMERA_START_EASE)))
	var offset := camera_roam.sample_baked(fposmod(distance, camera_roam.get_baked_length()), true)
	road_camera.position = camera_origin + offset
	# The distant skyline has less parallax; its padded crop covers the full tour.
	sky_layer.position = SKY_ORIGIN + Vector2(offset.x * 1.5, offset.y * 0.5)

func _build_camera_roam() -> void:
	# Four cubic arcs make a continuous oval across the map. The camera retains
	# the original viewing angle while its position explores a much wider area.
	var handles := CAMERA_ROAM_SIZE * 0.55228475
	var horizontal := Vector3(handles.x, 0.0, 0.0)
	var depth := Vector3(0.0, handles.y, -handles.z)
	camera_roam.bake_interval = 0.05
	camera_roam.add_point(Vector3.ZERO, -horizontal, horizontal)
	camera_roam.add_point(Vector3(CAMERA_ROAM_SIZE.x, CAMERA_ROAM_SIZE.y, -CAMERA_ROAM_SIZE.z), -depth, depth)
	camera_roam.add_point(Vector3(0.0, CAMERA_ROAM_SIZE.y * 2.0, -CAMERA_ROAM_SIZE.z * 2.0), horizontal, -horizontal)
	camera_roam.add_point(Vector3(-CAMERA_ROAM_SIZE.x, CAMERA_ROAM_SIZE.y, -CAMERA_ROAM_SIZE.z), depth, -depth)
	camera_roam.add_point(Vector3.ZERO, -horizontal, horizontal)

func _build_backdrop() -> void:
	# Crop the dusk horizon from the original photograph at its natural aspect
	# ratio. Compressing the whole image here would flatten the mountain peaks.
	var horizon_texture := AtlasTexture.new()
	horizon_texture.atlas = SKY_TEXTURE
	horizon_texture.region = Rect2(0.0, 2520.0, SKY_TEXTURE.get_width(), SKY_TEXTURE.get_height() - 2520.0)
	var sky := TextureRect.new()
	sky.name = "Sky"
	sky.texture = horizon_texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -30
	add_child(sky)
	sky_layer = sky
	sky.position = SKY_ORIGIN
	var sky_width := BASE_SIZE.x - SKY_ORIGIN.x * 2.0
	sky.size = Vector2(sky_width, horizon_texture.region.size.y * sky_width / horizon_texture.region.size.x)

	_build_road_view()

func _build_road_view() -> void:
	# Unity's start screen used a perspective camera looking at a large sprite
	# plane. A transparent SubViewport lets that projection sit over the real
	# mountain photograph while the rest of the menu remains ordinary Control UI.
	var container := SubViewportContainer.new()
	container.name = "RoadView"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.z_index = -20
	add_child(container)

	var viewport := SubViewport.new()
	viewport.name = "RoadViewport"
	viewport.size = Vector2i(int(BASE_SIZE.x), int(BASE_SIZE.y))
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	container.add_child(viewport)

	var camera := Camera3D.new()
	camera.name = "UnityStartCamera"
	camera.position = Vector3(0.0, -10.0, -8.0)
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 400.0
	camera.current = true
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 10.0, 0.0), Vector3.UP)
	road_camera = camera
	camera_origin = camera.position

	var road := Sprite3D.new()
	road.name = "RoadSprite"
	road.texture = MAP_TEXTURE
	road.pixel_size = 120.0 / float(MAP_TEXTURE.get_width())
	road.position = Vector3(0.0, 30.0, 0.0)
	road.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	road.no_depth_test = true
	viewport.add_child(road)
	_build_route_marker(viewport)

func _build_route_marker(viewport: SubViewport) -> void:
	# The marker is a true circle on the same XY plane as the map, so the camera
	# gives its near/far edges the same perspective as the roads underneath it.
	var marker := MeshInstance3D.new()
	marker.name = "RouteMarker"
	marker.position = Vector3(4.8, 0.0, -0.02)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(6.2, 6.2)
	marker.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = ROUTE_MARKER_SHADER
	material.render_priority = 1
	marker.material_override = material
	viewport.add_child(marker)

func _build_markers() -> void:
	var home_anchor := _map_point_at(Vector2(309.0, 279.0))
	var restaurant_anchor := _map_point_at(Vector2(1033.0, 235.0))
	# Both places have the same world diameter. The camera makes the farther
	# restaurant smaller naturally, instead of keeping two fixed-size UI badges.
	var home_depth := -road_camera.to_local(home_anchor).z
	var focal_pixels := BASE_SIZE.y * 0.5 / tan(deg_to_rad(road_camera.fov * 0.5))
	var world_diameter := 66.0 * home_depth / focal_pixels
	_add_marker("HomeMarker", home_anchor, world_diameter, HOME_TEXTURE)
	_add_marker("RestaurantMarker", restaurant_anchor, world_diameter, RESTAURANT_TEXTURE)

func _map_point_at(screen_point: Vector2) -> Vector3:
	var ray_origin := road_camera.project_ray_origin(screen_point)
	var ray_direction := road_camera.project_ray_normal(screen_point)
	return ray_origin + ray_direction * (-ray_origin.z / ray_direction.z)

func _filtered_marker_texture(source: Texture2D) -> ImageTexture:
	var image := source.get_image()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _add_marker(marker_name: String, marker_position: Vector3, world_diameter: float, icon: Texture2D) -> void:
	# Render camera-facing sprites in the map viewport. Positions and perspective
	# are resolved in the same frame as the roads, with no Control pixel snapping.
	var marker := Sprite3D.new()
	marker.name = marker_name
	marker.position = marker_position
	marker.texture = _filtered_marker_texture(LOCATION_BADGE_TEXTURE)
	# The SVG circle occupies 480 of its 512 pixels; the rest is shadow padding.
	marker.pixel_size = world_diameter / 480.0
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	marker.no_depth_test = true
	marker.render_priority = 2
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road_camera.get_parent().add_child(marker)

	var icon_sprite := Sprite3D.new()
	icon_sprite.name = "Icon"
	icon_sprite.texture = _filtered_marker_texture(icon)
	icon_sprite.pixel_size = world_diameter * (40.0 / 66.0) / float(maxi(icon.get_width(), icon.get_height()))
	icon_sprite.modulate = Color(0.07, 0.08, 0.12, 1.0)
	icon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon_sprite.no_depth_test = true
	icon_sprite.render_priority = 3
	icon_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(icon_sprite)

func _build_title() -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = "DELIVERY MAN SIMULATOR"
	var title_font := FontVariation.new()
	title_font.base_font = MENU_FONT
	title_font.spacing_glyph = 2
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 0.98))
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.08, 0.65))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_constant_override("shadow_outline_size", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.z_index = 2
	add_child(title)
	title.position = Vector2(66.0, 119.0)
	title.size = Vector2(800.0, 68.0)

func _build_buttons() -> void:
	leaderboard_button = _make_button("RANKING", Vector2(1096.0, 488.0))
	leaderboard_button.name = "LeaderboardButton"
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	start_button = _make_button("START", Vector2(1096.0, 546.0))
	start_button.name = "StartButton"
	start_button.pressed.connect(_on_start_pressed)
	exit_button = _make_button("EXIT", Vector2(1096.0, 604.0))
	exit_button.name = "ExitButton"
	exit_button.pressed.connect(_on_exit_pressed)

func _on_leaderboard_pressed() -> void:
	if leaving_menu or is_instance_valid(leaderboard):
		return
	_play_button_sound()
	leaderboard = Leaderboard.new(get_node("/root/OnlineService"))
	add_child(leaderboard)

func _make_button(label: String, button_position: Vector2) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = Vector2(148.0, 42.0)
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var button_font := FontVariation.new()
	button_font.base_font = MENU_FONT
	button_font.spacing_glyph = 1
	button.add_theme_font_override("font", button_font)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.12, 0.15, 0.2, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.96, 0.97, 0.98, 0.96), Color(1.0, 1.0, 1.0, 0.0)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.96, 0.58, 0.08, 0.98), Color(1.0, 0.8, 0.35, 0.9)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.8, 0.38, 0.03, 1.0), Color(1.0, 0.75, 0.25, 1.0)))
	button.z_index = 4
	add_child(button)
	return button

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 5
	return style

func _start_menu_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MenuMusic"
	music_player.bus = &"Music"
	var music := load(MENU_MUSIC_PATH) as AudioStreamMP3
	if music != null:
		music = music.duplicate() as AudioStreamMP3
		music.loop = true
		music_player.stream = music
	add_child(music_player)
	if music_player.stream != null:
		music_player.play()

	button_player = AudioStreamPlayer.new()
	button_player.name = "MenuButtonSound"
	button_player.bus = &"SFX"
	button_player.stream = load(BUTTON_SOUND_PATH) as AudioStreamMP3
	add_child(button_player)

func _play_button_sound() -> void:
	if button_player != null and button_player.stream != null:
		button_player.play()

func _on_start_pressed() -> void:
	if leaving_menu:
		return
	leaving_menu = true
	start_button.disabled = true
	exit_button.disabled = true
	_play_button_sound()
	await get_tree().create_timer(0.12).timeout
	if music_player != null:
		music_player.stop()
	var result := get_tree().change_scene_to_file("res://scenes/Main.tscn")
	if result != OK:
		push_error("Unable to enter main game: " + error_string(result))
		leaving_menu = false
		start_button.disabled = false
		exit_button.disabled = false
		music_player.play()

func _on_exit_pressed() -> void:
	if leaving_menu:
		return
	leaving_menu = true
	start_button.disabled = true
	exit_button.disabled = true
	_play_button_sound()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()

func _exit_tree() -> void:
	for player: AudioStreamPlayer in [music_player, button_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
