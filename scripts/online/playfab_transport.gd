extends Node

## HTTPS/JSON boundary. Return safe errors without logging tickets or payloads.
const ERROR_MESSAGES := {
	"InvalidTitleId": "排行榜项目配置无效。",
	"NameNotAvailable": "这个昵称已被使用，请换一个。",
	"DisplayNameTooShort": "昵称需要 3～25 个字符。",
	"DisplayNameTooLong": "昵称需要 3～25 个字符。",
	"InvalidDisplayName": "昵称不符合要求，请换一个。",
	"ProfaneDisplayName": "昵称不符合要求，请换一个。",
	"InvalidSessionTicket": "连接已过期，请重新连接。",
	"SessionTicketExpired": "连接已过期，请重新连接。",
	"NotAuthenticated": "请先连接排行榜。",
	"APINotEnabledForGameClientAccess": "排行榜接口尚未在服务器启用。",
	"ClientNotAllowedToCreateAccounts": "服务器未开放新玩家注册，请联系游戏维护者。",
	"AccountCreationDisabled": "服务器未开放新玩家注册，请联系游戏维护者。",
	"APIClientRequestRateLimitExceeded": "请求过于频繁，请稍后重试。",
	"ServiceUnavailable": "排行榜暂时不可用，请稍后重试。"
}
var proxy_host := ""
var proxy_port := -1

func _ready() -> void:
	var settings := ConfigFile.new()
	var loaded := settings.load("user://playfab_network.cfg") == OK
	if not loaded and OS.has_feature("editor"):
		loaded = settings.load("res://.local/playfab_network.cfg") == OK
	if loaded:
		proxy_host = str(settings.get_value("network", "https_proxy_host", "")).strip_edges()
		proxy_port = int(settings.get_value("network", "https_proxy_port", -1))

func _origin(title_id: String) -> String:
	return "https://%s.playfabapi.com" % title_id

func send(title_id: String, endpoint: String, payload: Dictionary, ticket: String = "") -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 12.0
	request.body_size_limit = 1024 * 1024
	# Small JSON replies do not need compression; some proxies alter gzip framing.
	request.accept_gzip = false
	add_child(request)
	if not proxy_host.is_empty() and proxy_port > 0 and proxy_port <= 65535:
		request.set_https_proxy(proxy_host, proxy_port)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not ticket.is_empty():
		headers.append("X-Authorization: " + ticket)
	var error := request.request(_origin(title_id) + "/Client/" + endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		return {"ok": false, "code": "NetworkError", "message": "无法连接排行榜，请检查网络后重试。"}
	var response: Array = await request.request_completed
	request.queue_free()
	return decode_response(int(response[0]), int(response[1]), response[3])

static func decode_response(result: int, status_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": "NetworkError", "http_result": result, "message": "连接超时或网络不可用，请稍后重试。"}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"ok": false, "code": "InvalidResponse", "message": "排行榜返回了无效数据，请稍后重试。"}
	var envelope: Dictionary = json.data
	if status_code != 200 or int(envelope.get("code", 0)) != 200:
		var code: String = str(envelope.get("error", "ServerError"))
		return {"ok": false, "code": code, "message": ERROR_MESSAGES.get(code, "排行榜请求失败，请稍后重试。")}
	if not envelope.get("data") is Dictionary:
		return {"ok": false, "code": "InvalidResponse", "message": "排行榜返回了无效数据，请稍后重试。"}
	return {"ok": true, "data": envelope.data}
