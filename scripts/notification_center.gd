extends Control

## UI time is unscaled so notices expire even during upgrades or time slowing.
const RULES := {
	&"day_started": {"title": "第 {day} 天 · 开工", "body": "天气：{weather} · 点击标记接单。", "tone": &"info", "duration": 3.5, "priority": 0},
	&"weather_sunny": {"title": "第 {day} 天 · 晴天", "body": "速度正常 · 标准接单时间。", "tone": &"info", "duration": 3.5, "priority": 1},
	&"weather_cloudy": {"title": "第 {day} 天 · 多云", "body": "速度正常 · 接单时间缩短。", "tone": &"info", "duration": 3.5, "priority": 1},
	&"weather_rainy": {"title": "第 {day} 天 · 雨天", "body": "速度 -23% · 每单 +$17。", "tone": &"info", "duration": 3.5, "priority": 1},
	&"weather_foggy": {"title": "第 {day} 天 · 雾天", "body": "速度 -12% · 接单时间延长。", "tone": &"info", "duration": 3.5, "priority": 1},
	&"assigned_intro": {"title": "指定单（!）", "body": "未接会扣款 · 请留意接单时限。", "tone": &"warning", "duration": 4.0, "priority": 1},
	&"hot_intro": {"title": "热门单（火焰）", "body": "报酬高 · 接单时间很短。", "tone": &"info", "duration": 4.0, "priority": 1},
	# These state changes are already visible in the map, task list, or waiting context.
	&"accepted": {"toast": false},
	&"picked_up": {"toast": false},
	&"food_ready": {"toast": false},
	&"delivered": {"toast": false},
	&"sorted": {"toast": false},
	&"urged": {"toast": false},
	&"late": {"title": "订单超时", "body": "扣除 ${amount}。", "tone": &"warning", "duration": 3.5, "priority": 2, "aggregate": true, "aggregate_body": "共扣除 ${amount}。"},
	&"cancelled": {"title": "订单已取消", "body": "严重超时，扣除 ${amount}。", "tone": &"error", "duration": 4.0, "priority": 2, "aggregate": true, "aggregate_body": "严重超时，共扣除 ${amount}。"},
	&"assigned_missed": {"title": "指定单未接取", "body": "超时扣除 ${amount}。", "tone": &"warning", "duration": 4.0, "priority": 2, "aggregate": true, "aggregate_body": "超时共扣除 ${amount}。"},
	&"full_bag": {"title": "背包已满", "body": "先完成一单。", "tone": &"warning", "duration": 2.8, "priority": 1, "cooldown": 1.5},
	&"no_order": {"title": "没有可接订单", "body": "点击有标记的地点。", "tone": &"info", "duration": 2.0, "priority": 0, "cooldown": 1.5},
	&"pickup_first": {"title": "请先取餐", "body": "不能先送达。", "tone": &"warning", "duration": 2.8, "priority": 1, "cooldown": 1.5},
	&"audio": {"title": "{state}", "body": "", "tone": &"info", "duration": 1.6, "priority": 1},
	&"funds": {"title": "资金不足", "body": "需要 $100，余额 ${money}。", "tone": &"warning", "duration": 3.2, "priority": 2, "cooldown": 1.5},
	&"max_upgrade": {"title": "升级已满", "body": "请选择其他项目。", "tone": &"info", "duration": 2.4, "priority": 1, "cooldown": 1.5},
	&"purchases_used": {"title": "今日次数已用完", "body": "下一天可继续升级。", "tone": &"info", "duration": 2.4, "priority": 1, "cooldown": 1.5},
	&"upgraded": {"title": "升级完成", "body": "{upgrade} · $100。", "tone": &"success", "duration": 2.6, "priority": 1},
}
const TONES := {&"info": Color("#c5c878"), &"success": Color("#9fc5ad"), &"warning": Color("#d4b77d"), &"error": Color("#d29b91")}
const MAX_NOTICES := 1
const WEATHER_EVENTS := {"晴天": &"weather_sunny", "多云": &"weather_cloudy", "雨天": &"weather_rainy", "雾天": &"weather_foggy"}

class NoticeIcon extends Control:
	var tone: StringName = &"info"
	var accent := Color.WHITE
	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 14, Color(accent, 0.12))
		if tone == &"success":
			draw_polyline(PackedVector2Array([center + Vector2(-8, 0), center + Vector2(-2, 6), center + Vector2(9, -7)]), accent, 2.5, true)
		elif tone == &"warning" or tone == &"error":
			draw_line(center + Vector2(0, -8), center + Vector2(0, 3), accent, 2.5, true)
			draw_circle(center + Vector2(0, 8), 1.7, accent)
		else:
			draw_circle(center + Vector2(0, -7), 1.7, accent)
			draw_line(center + Vector2(0, -1), center + Vector2(0, 8), accent, 2.5, true)

var stack: VBoxContainer
var active: Array[Dictionary] = []
var last_posted: Dictionary[StringName, float] = {}
var elapsed := 0.0
var context_card: Dictionary = {}
var seen_introductions: Dictionary[StringName, bool] = {}
var pending_introductions: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack = VBoxContainer.new()
	stack.name = "NoticeStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.anchor_top = 1.0
	stack.anchor_bottom = 1.0
	stack.anchor_right = 1.0
	stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.add_theme_constant_override("separation", 6)
	add_child(stack)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	for index in range(active.size() - 1, -1, -1):
		active[index]["remaining"] -= maxf(delta, 0.0)
		if active[index]["remaining"] <= 0.0:
			_remove(index)
	_show_next_introduction()

func introduce(event: StringName, values: Dictionary = {}) -> bool:
	if not RULES.has(event):
		push_error("Unknown introduction event: " + String(event))
		return false
	if seen_introductions.has(event):
		return false
	seen_introductions[event] = true
	pending_introductions.append({"event": event, "values": values.duplicate()})
	_show_next_introduction()
	return true

func _show_next_introduction() -> void:
	if not active.is_empty() or pending_introductions.is_empty():
		return
	var introduction: Dictionary = pending_introductions.pop_front()
	if post(introduction["event"], introduction["values"]):
		active.back()["introduction"] = introduction

func post(event: StringName, values: Dictionary = {}) -> bool:
	if not RULES.has(event):
		push_error("Unknown notice event: " + String(event))
		return false
	var rule: Dictionary = RULES[event]
	if not rule.get("toast", true):
		return false
	var cooldown := float(rule.get("cooldown", 0.0))
	if elapsed - last_posted.get(event, -1000.0) < cooldown:
		return false
	var title: String = String(rule["title"]).format(values)
	var body: String = String(rule["body"]).format(values)
	for notice: Dictionary in active:
		if notice["event"] == event:
			if rule.get("aggregate", false):
				notice["count"] += 1
				notice["amount"] += int(values.get("amount", 0))
				title += " · %d 单" % int(notice["count"])
				body = String(rule["aggregate_body"]).format({"amount": notice["amount"]})
			_update_card(notice, title, body)
			notice["remaining"] = float(rule["duration"])
			last_posted[event] = elapsed
			return true
	var priority := int(rule["priority"])
	if active.size() >= MAX_NOTICES:
		var lowest := 0
		for index in range(1, active.size()):
			if int(active[index]["priority"]) < int(active[lowest]["priority"]):
				lowest = index
		if priority < int(active[lowest]["priority"]):
			return false
		if active[lowest].has("introduction") and priority == int(active[lowest]["priority"]):
			return false
		# A penalty can interrupt a first-time guide, but must not silently lose it.
		if active[lowest].has("introduction"):
			pending_introductions.push_front(active[lowest]["introduction"])
		_remove(lowest)
	var notice := _make_card(title, body, rule["tone"], rule.get("key", ""), rule.get("action", ""))
	notice["event"] = event
	notice["priority"] = priority
	notice["remaining"] = float(rule["duration"])
	notice["count"] = 1
	notice["amount"] = int(values.get("amount", 0))
	active.append(notice)
	last_posted[event] = elapsed
	if not context_card.is_empty():
		stack.move_child(context_card["node"], stack.get_child_count() - 1)
	return true

func set_waiting(minutes: int) -> void:
	if minutes < 0:
		clear_context()
		return
	var body := "还需 %d 分钟" % minutes if minutes > 0 else "即将出餐"
	if context_card.is_empty():
		context_card = _make_card("等待出餐", body, &"info", "SPACE", "催餐 -2 分钟")
	else:
		_update_card(context_card, "等待出餐", body)

func clear_context() -> void:
	if context_card.is_empty():
		return
	var node: Control = context_card["node"]
	stack.remove_child(node)
	node.queue_free()
	context_card.clear()

func clear() -> void:
	for index in range(active.size() - 1, -1, -1):
		_remove(index)
	clear_context()
	last_posted.clear()
	# Transitions discard stale cards but keep first-encounter history for this run.
	pending_introductions.clear()

func reset_introductions() -> void:
	clear()
	seen_introductions.clear()

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for notice: Dictionary in active:
		result.append({"event": String(notice["event"]), "title": notice["title"].text, "body": notice["body"].text, "remaining": notice["remaining"], "priority": notice["priority"], "count": notice["count"]})
	return result

func _remove(index: int) -> void:
	var notice: Dictionary = active.pop_at(index)
	var node: Control = notice["node"]
	stack.remove_child(node)
	node.queue_free()

func _update_card(card: Dictionary, title: String, body: String) -> void:
	card["title"].text = title
	card["body"].text = body

func _make_card(title: String, body: String, tone: StringName, key: String, action: String) -> Dictionary:
	var accent: Color = TONES[tone]
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.24, 0.88)
	style.set_corner_radius_all(12)
	style.border_color = Color(accent, 0.24)
	style.set_border_width_all(1)
	style.shadow_color = Color(0.02, 0.04, 0.06, 0.22)
	style.shadow_size = 3
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	card.add_theme_stylebox_override("panel", style)
	stack.add_child(card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var icon := NoticeIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.tone = tone
	icon.accent = accent
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 3)
	row.add_child(text)
	var heading := _label(title, 14, accent)
	text.add_child(heading)
	var detail := _label(body, 12, Color("#c4ced3"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(detail)
	if not key.is_empty():
		var shortcut := HBoxContainer.new()
		shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shortcut.add_theme_constant_override("separation", 8)
		text.add_child(shortcut)
		var keycap := PanelContainer.new()
		keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_style := StyleBoxFlat.new()
		key_style.bg_color = Color(0.26, 0.33, 0.40, 0.75)
		key_style.set_corner_radius_all(5)
		key_style.content_margin_left = 6
		key_style.content_margin_right = 6
		key_style.content_margin_top = 1
		key_style.content_margin_bottom = 1
		keycap.add_theme_stylebox_override("panel", key_style)
		keycap.add_child(_label(key, 11, Color("#eef1ed")))
		shortcut.add_child(keycap)
		shortcut.add_child(_label(action, 11, Color("#aebbc7")))
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.14)
	return {"node": card, "title": heading, "body": detail}

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
