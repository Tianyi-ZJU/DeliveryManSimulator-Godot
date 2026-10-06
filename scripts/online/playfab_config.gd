extends RefCounted

## Public connection settings only. Never put a developer secret key here.
var title_id := ""
var statistic_name := "Test"

func load_file(path: String = "res://data/playfab.cfg") -> void:
	var file := ConfigFile.new()
	if file.load(path) == OK:
		title_id = str(file.get_value("playfab", "title_id", "")).strip_edges()
		statistic_name = str(file.get_value("playfab", "statistic_name", "Test")).strip_edges()

func is_configured() -> bool:
	return not title_id.is_empty() and title_id.length() <= 16 and title_id.is_valid_hex_number() and not statistic_name.is_empty() and statistic_name.length() <= 64
