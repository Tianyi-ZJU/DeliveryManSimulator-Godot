extends RefCounted

## A random device identity per title; a display name is never a login key.
## Session tickets stay in memory in PlayFabClient, never in this file.
var path := "user://playfab_profile.cfg"

func _init(storage_path: String = "user://playfab_profile.cfg") -> void:
	path = storage_path

func _read() -> Dictionary:
	var file := ConfigFile.new()
	var error := file.load(path)
	return {"ok": error == OK or error == ERR_FILE_NOT_FOUND, "file": file}

func display_name(title_id: String) -> String:
	var result := _read()
	return str(result.file.get_value(title_id, "display_name", "")) if result.ok else ""

func identity(title_id: String) -> Dictionary:
	var result := _read()
	if not result.ok:
		return {"ok": false, "message": "无法读取本机排行榜身份，请检查本地文件权限。"}
	var file: ConfigFile = result.file
	var custom_id: String = str(file.get_value(title_id, "custom_id", ""))
	if not custom_id.is_empty():
		if not custom_id.begins_with("dms-") or custom_id.length() != 68 or not custom_id.substr(4).is_valid_hex_number():
			return {"ok": false, "message": "本机排行榜身份文件损坏，请先恢复备份。"}
		return {"ok": true, "custom_id": custom_id}
	var bytes := Crypto.new().generate_random_bytes(32)
	if bytes.size() != 32:
		return {"ok": false, "message": "无法生成排行榜身份，请重试。"}
	custom_id = "dms-" + bytes.hex_encode()
	file.set_value(title_id, "custom_id", custom_id)
	if file.save(path) != OK:
		return {"ok": false, "message": "无法保存本机排行榜身份，请检查本地文件权限。"}
	return {"ok": true, "custom_id": custom_id}

func save_display_name(title_id: String, nickname: String) -> bool:
	var result := _read()
	if not result.ok:
		return false
	var file: ConfigFile = result.file
	file.set_value(title_id, "display_name", nickname)
	return file.save(path) == OK
