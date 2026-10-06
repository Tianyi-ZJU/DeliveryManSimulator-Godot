extends Node

## The app-wide online session; independent of per-run gameplay state.
signal changed()
const Settings := preload("res://scripts/online/playfab_config.gd")
const Profile := preload("res://scripts/online/local_online_profile.gd")
const Transport := preload("res://scripts/online/playfab_transport.gd")
var configuration: Settings
var profile: Profile
var transport: Transport
var display_name := ""
var busy := false
var leaderboard: Array[Dictionary] = []
var submitted_runs: Dictionary = {}
var _ticket := ""

func _init(settings: Settings = null, local_profile: Profile = null, backend: Transport = null) -> void:
	configuration = settings if settings != null else Settings.new()
	if settings == null:
		configuration.load_file()
	profile = local_profile if local_profile != null else Profile.new()
	transport = backend if backend != null else Transport.new()

func _ready() -> void:
	add_child(transport)
	display_name = profile.display_name(configuration.title_id)

func has_session() -> bool:
	return not _ticket.is_empty() and not display_name.is_empty()

func _begin() -> Dictionary:
	if busy:
		return {"ok": false, "message": "正在处理上一次请求，请稍候。"}
	if not configuration.is_configured():
		return {"ok": false, "message": "排行榜尚未配置，仍可正常开始游戏。"}
	busy = true
	changed.emit()
	return {"ok": true}

func _finish(result: Dictionary) -> Dictionary:
	if result.get("code", "") in ["InvalidSessionTicket", "SessionTicketExpired", "NotAuthenticated"]:
		_ticket = ""
	busy = false
	changed.emit()
	return result

func connect_profile(nickname: String) -> Dictionary:
	nickname = nickname.strip_edges()
	if nickname.length() < 3 or nickname.length() > 25:
		return {"ok": false, "message": "昵称需要 3～25 个字符。"}
	var guard := _begin()
	if not guard.ok:
		return guard
	if _ticket.is_empty():
		var identity := profile.identity(configuration.title_id)
		if not identity.ok:
			return _finish(identity)
		var login: Dictionary = await transport.send(configuration.title_id, "LoginWithCustomID", {"TitleId": configuration.title_id, "CustomId": identity.custom_id, "CreateAccount": true})
		if not login.ok:
			return _finish(login)
		var ticket: String = str(login.data.get("SessionTicket", ""))
		if ticket.is_empty() or ticket.contains("\n") or ticket.contains("\r"):
			return _finish({"ok": false, "message": "服务器未返回有效连接，请重试。"})
		_ticket = ticket
	var result: Dictionary = await transport.send(configuration.title_id, "UpdateUserTitleDisplayName", {"DisplayName": nickname}, _ticket)
	if not result.ok:
		return _finish(result)
	display_name = str(result.data.get("DisplayName", nickname))
	if not profile.save_display_name(configuration.title_id, display_name):
		return _finish({"ok": false, "message": "已连接，但无法保存昵称；下次启动需要重新输入。"})
	return _finish({"ok": true, "message": "已连接排行榜。"})

func fetch_leaderboard() -> Dictionary:
	if not has_session():
		return {"ok": false, "message": "请先输入昵称并连接排行榜。"}
	var guard := _begin()
	if not guard.ok:
		return guard
	var result: Dictionary = await transport.send(configuration.title_id, "GetLeaderboard", {"StatisticName": configuration.statistic_name, "StartPosition": 0, "MaxResultsCount": 100}, _ticket)
	if not result.ok:
		return _finish(result)
	var entries: Variant = result.data.get("Leaderboard")
	if not entries is Array or entries.size() > 100:
		return _finish({"ok": false, "message": "排行榜数据格式不正确，请重试。"})
	var rows: Array[Dictionary] = []
	for entry: Variant in entries:
		if not entry is Dictionary:
			return _finish({"ok": false, "message": "排行榜数据格式不正确，请重试。"})
		var position: Variant = entry.get("Position")
		var score: Variant = entry.get("StatValue")
		if not (position is float or position is int) or not (score is float or score is int) or float(position) < 0.0:
			return _finish({"ok": false, "message": "排行榜数据格式不正确，请重试。"})
		var name_value: Variant = entry.get("DisplayName")
		rows.append({"rank": int(entry.Position) + 1, "name": str(name_value).left(25) if name_value != null and not str(name_value).is_empty() else "未命名玩家", "score": int(entry.StatValue)})
	leaderboard = rows
	return _finish({"ok": true, "message": "暂无成绩，来完成第一局吧。" if rows.is_empty() else "已更新排行榜。"})

func submit_score(score: int, run_key: String) -> Dictionary:
	if not has_session():
		return {"ok": false, "message": "请先连接排行榜。"}
	if run_key.is_empty() or score < -2147483648 or score > 2147483647:
		return {"ok": false, "message": "本局成绩无效。"}
	if submitted_runs.has(run_key):
		return {"ok": true, "message": "本局成绩已经提交。"}
	var guard := _begin()
	if not guard.ok:
		return guard
	var result: Dictionary = await transport.send(configuration.title_id, "UpdatePlayerStatistics", {"Statistics": [{"StatisticName": configuration.statistic_name, "Value": score}]}, _ticket)
	if not result.ok:
		return _finish(result)
	submitted_runs[run_key] = score
	return _finish({"ok": true, "message": "本局成绩已提交。"})
