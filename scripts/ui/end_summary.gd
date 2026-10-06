extends PanelContainer

signal restart_requested()
signal leaderboard_requested(score: int)
const GameState := preload("res://scripts/core/game_state.gd")
const EndRating := preload("res://scripts/end_rating.gd")
var state: GameState

func _init(shared_state: GameState) -> void:
	state = shared_state

func _ready() -> void:
	name = "EndSummary"
	position = Vector2(350, 130)
	size = Vector2(580, 430)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	for line in ["Delivery Man Simulator", "You Have Earned: $%d" % state.money, "Finished Order: %d" % state.finished_count, "Late Order: %d" % state.late_count, "Bad Order: %d" % state.failed_count, "Rank: " + EndRating.calculate(state.money, state.late_count, state.failed_count)]:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		box.add_child(label)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var restart := Button.new()
	restart.name = "Restart"
	restart.text = "Start a New Game"
	restart.pressed.connect(restart_requested.emit)
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(restart)
	var leaderboard := Button.new()
	leaderboard.name = "LeaderboardButton"
	leaderboard.text = "排行榜 / 提交成绩"
	leaderboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaderboard.pressed.connect(leaderboard_requested.emit.bind(state.money))
	buttons.add_child(leaderboard)
