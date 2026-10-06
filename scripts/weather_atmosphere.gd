extends RefCounted

## Occasional broad weather passes. A separate RNG keeps effects out of gameplay
## randomness, and drawing inside the map pass leaves all markers/UI above them.
const CLOUD: Texture2D = preload("res://assets/weather/cloud_soft.svg")
const FOG: Texture2D = preload("res://assets/weather/fog_wisp.svg")
const SUNBEAM: Texture2D = preload("res://assets/weather/sunbeam_soft.svg")
const SUN_MOTE: Texture2D = preload("res://assets/weather/sun_mote.svg")
const RAIN: Texture2D = preload("res://assets/weather/rain_streak.svg")
# Logical map coordinates scale with the game's canvas, including window resizing.
const EFFECT_AREA := Rect2(0, 0, 1280, 675)
const PROFILES := {
	"多云": {"duration": Vector2(20, 24), "gap": Vector2(26, 38), "alpha": 0.23},
	"雾天": {"duration": Vector2(12, 16), "gap": Vector2(30, 44), "alpha": 0.145},
	"晴天": {"duration": Vector2(10, 14), "gap": Vector2(30, 44), "alpha": 0.32},
	"雨天": {"duration": Vector2(12, 16), "gap": Vector2(24, 36), "alpha": 0.56},
}

var weather := ""
var running := true
var rng := RandomNumberGenerator.new()
var event: Dictionary = {}
var quiet_remaining := 0.0
var age := 0.0

func _init() -> void:
	rng.randomize()

func reset(weather_name: String) -> void:
	weather = weather_name
	running = true
	event.clear()
	age = 0.0
	quiet_remaining = rng.randf_range(6.0, 10.0)

func set_weather(weather_name: String) -> void:
	if weather != weather_name:
		reset(weather_name)

func set_running(value: bool) -> void:
	if running == value:
		return
	running = value
	event.clear()
	age = 0.0
	quiet_remaining = rng.randf_range(6.0, 10.0)

func advance(delta: float) -> void:
	if not running or not PROFILES.has(weather) or delta <= 0.0:
		return
	if event.is_empty():
		quiet_remaining -= delta
		if quiet_remaining <= 0.0:
			_begin_event()
		return
	age += delta
	if age >= float(event["duration"]):
		event.clear()
		age = 0.0
		var gap: Vector2 = PROFILES[weather]["gap"]
		quiet_remaining = rng.randf_range(gap.x, gap.y)

func _begin_event() -> void:
	var profile: Dictionary = PROFILES[weather]
	var duration: Vector2 = profile["duration"]
	var dimensions := Vector2.ZERO
	var travel := Vector2.ZERO
	var origin := Vector2.ZERO
	match weather:
		"多云":
			dimensions = Vector2(600, 225)
			origin = Vector2(-dimensions.x, rng.randf_range(105, 300))
			travel = Vector2(EFFECT_AREA.size.x + dimensions.x, 0)
		"雾天":
			dimensions = Vector2(1480, 780)
			origin = Vector2(-100, -50)
			travel = Vector2(50, 0)
		"晴天":
			dimensions = Vector2(560, 900)
			origin = Vector2(rng.randf_range(120, 620), -110)
			travel = Vector2(-45, 35)
		"雨天":
			dimensions = Vector2(600, 835)
			origin = Vector2(EFFECT_AREA.size.x, -80)
			travel = Vector2(-EFFECT_AREA.size.x - dimensions.x, 0)
	event = {
		"duration": rng.randf_range(duration.x, duration.y),
		"origin": origin, "size": dimensions, "travel": travel, "particles": [],
	}
	if weather == "晴天":
		for i in range(8):
			event["particles"].append({
				"offset": Vector2(rng.randf_range(145, 290), rng.randf_range(130, 660)),
				"size": rng.randf_range(6, 10), "drift": rng.randf_range(100, 160),
			})
	elif weather == "雨天":
		for i in range(96):
			event["particles"].append({
				"offset": rng.randf_range(28, 575), "phase": rng.randf_range(0, 790),
				"speed": rng.randf_range(440, 660), "length": rng.randf_range(24, 44),
			})
	age = 0.0

func opacity() -> float:
	if event.is_empty() or not running:
		return 0.0
	var duration: float = event["duration"]
	var envelope := smoothstep(0.0, 2.0, age) * (1.0 - smoothstep(duration - 2.0, duration, age))
	return float(PROFILES[weather]["alpha"]) * envelope

func draw_on(canvas: CanvasItem) -> void:
	var alpha := opacity()
	if alpha <= 0.0:
		return
	var progress := clampf(age / float(event["duration"]), 0.0, 1.0)
	var origin: Vector2 = event["origin"] + event["travel"] * progress
	var dimensions: Vector2 = event["size"]
	var rect := Rect2(origin, dimensions)
	match weather:
		"多云":
			canvas.draw_texture_rect(CLOUD, rect, false, Color(1, 1, 1, alpha))
		"雾天":
			canvas.draw_rect(EFFECT_AREA, Color(0.77, 0.84, 0.88, alpha))
			canvas.draw_texture_rect(FOG, rect, false, Color(1, 1, 1, alpha * 0.45))
		"晴天":
			canvas.draw_rect(EFFECT_AREA, Color(1.0, 0.73, 0.37, alpha * 0.10))
			canvas.draw_texture_rect(SUNBEAM, rect, false, Color(1, 1, 1, alpha))
			for particle: Dictionary in event["particles"]:
				var point: Vector2 = origin + particle["offset"] + Vector2(-8, particle["drift"]) * progress
				var mote_size := Vector2.ONE * float(particle["size"])
				canvas.draw_texture_rect(SUN_MOTE, Rect2(point, mote_size), false, Color(1, 1, 1, alpha * 0.75))
		"雨天":
			canvas.draw_texture_rect(FOG, rect, false, Color(0.70, 0.84, 1.0, alpha * 0.10))
			for particle: Dictionary in event["particles"]:
				var fall := fposmod(age * float(particle["speed"]) + float(particle["phase"]), 790.0)
				var point := origin + Vector2(float(particle["offset"]) - fall * 0.045, fall)
				var drop_size := Vector2(6, float(particle["length"]))
				var drop_fade := smoothstep(0.0, 30.0, fall) * (1.0 - smoothstep(740.0, 790.0, fall))
				drop_fade *= smoothstep(0.0, 70.0, point.x - origin.x) * (1.0 - smoothstep(520.0, 600.0, point.x - origin.x))
				canvas.draw_texture_rect(RAIN, Rect2(point, drop_size), false, Color(1, 1, 1, alpha * drop_fade))
