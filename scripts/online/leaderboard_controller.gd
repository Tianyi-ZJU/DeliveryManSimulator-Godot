extends CanvasLayer

## Own the modal and asynchronous flow, never the gameplay score calculation.
const Client := preload("res://scripts/online/playfab_client.gd")
const View := preload("res://scripts/ui/leaderboard_view.gd")
var client: Client
var view: View
var run_score: Variant
var run_key := ""
var _message := ""
var _phase := ""

func _init(service: Client, score: Variant = null, submission_key: String = "") -> void:
	client = service
	run_score = score
	run_key = submission_key

func _ready() -> void:
	name = "Leaderboard"
	layer = 40
	view = View.new(run_score)
	add_child(view)
	view.connect_requested.connect(_connect_profile)
	view.refresh_requested.connect(_fetch)
	view.submit_requested.connect(_submit)
	view.close_requested.connect(queue_free)
	client.changed.connect(_refresh_view)
	_refresh_view()

func _refresh_view() -> void:
	var message := _phase if client.busy else _message
	if client.busy and message.is_empty():
		message = "正在处理，请稍候…"
	elif not client.configuration.is_configured():
		message = "排行榜尚未配置，仍可正常开始游戏。"
	elif message.is_empty():
		message = "输入昵称并连接，即可查看排行榜。" if not client.has_session() else "可以刷新排行榜。"
	view.render({"connected": client.has_session(), "busy": client.busy, "configured": client.configuration.is_configured(), "nickname": client.display_name, "message": message, "rows": client.leaderboard, "submitted": client.submitted_runs.has(run_key)})

func _connect_profile(nickname: String) -> void:
	_phase = "正在连接…"
	var result: Dictionary = await client.connect_profile(nickname)
	_message = result.message
	if result.ok:
		await _fetch()
	_refresh_view()

func _fetch() -> Dictionary:
	_phase = "正在读取排行榜…"
	var result: Dictionary = await client.fetch_leaderboard()
	_message = result.message
	_refresh_view()
	return result

func _submit() -> void:
	if run_score == null:
		return
	_phase = "正在提交成绩…"
	var result: Dictionary = await client.submit_score(int(run_score), run_key)
	_message = result.message
	if result.ok:
		var refresh_result: Dictionary = await _fetch()
		_message = "本局成绩已提交。" if refresh_result.ok else "成绩已提交，榜单刷新失败；可稍后刷新。"
	_refresh_view()
