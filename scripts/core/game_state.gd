extends RefCounted

## Per-run data shared by gameplay systems. No UI, audio or scene references.
const Config := preload("res://scripts/core/game_config.gd")

var day := 1
var clock_minutes := 10 * 60
var clock_accumulator := 0.0
var minute_seconds := 0.2
var money := 100
var capacity := 3
var occupied := 0
var courier_speed := 11.0
var speed_energy := 20.0
var slow_energy := 15.0
var speed_energy_max := 20.0
var slow_energy_max := 15.0
var upgrades_remaining := {"speed": 2, "capacity": 2, "speed_energy": 2, "slow_energy": 2}
var purchases_left := 2
var finished_count := 0
var day_start_finished := 0
var day_start_money := 100
var late_count := 0
var failed_count := 0
var wait_order: Dictionary = {}
var wait_until := 0
var weather := "晴天"
var weather_speed_factor := 1.0
var weather_price_bonus := 0
var next_order_id := 0
var orders: Array = []
var tasks: Array = []
var courier_pos := Config.COURIER_SPAWN
var courier_target := -1
var courier_target_kind := ""
var courier_route: Array[Vector2] = []
var courier_route_index := 0
var generated_timer := 3.0
var upgrade_visible := false
var game_finished := false

func reset_run() -> void:
	day = 1
	clock_minutes = 600
	clock_accumulator = 0.0
	money = 100
	capacity = 3
	occupied = 0
	courier_speed = 10.0 # Unity Reset uses 10; first launch uses 11.
	speed_energy_max = 20.0
	slow_energy_max = 15.0
	speed_energy = speed_energy_max
	slow_energy = slow_energy_max
	upgrades_remaining = {"speed": 2, "capacity": 2, "speed_energy": 2, "slow_energy": 2}
	purchases_left = 2
	finished_count = 0
	day_start_finished = 0
	day_start_money = 100
	late_count = 0
	failed_count = 0
	orders.clear()
	tasks.clear()
	wait_order = {}
	courier_route.clear()
	courier_pos = Config.COURIER_SPAWN
	next_order_id = 0
	generated_timer = 3.0
	game_finished = false
	upgrade_visible = false
