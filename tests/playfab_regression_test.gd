extends SceneTree

const Settings := preload("res://scripts/online/playfab_config.gd")
const Profile := preload("res://scripts/online/local_online_profile.gd")
const Transport := preload("res://scripts/online/playfab_transport.gd")
const Client := preload("res://scripts/online/playfab_client.gd")
const Board := preload("res://scripts/online/leaderboard_controller.gd")
var errors := 0
var checks := 0
var profile_path := "res://tmp/regression/profile-%d.cfg" % Time.get_ticks_usec()

class FakeTransport extends Transport:
	var replies: Array[Dictionary] = []
	var calls: Array[Dictionary] = []
	func send(title_id: String, endpoint: String, payload: Dictionary, ticket: String = "") -> Dictionary:
		calls.append({"title": title_id, "endpoint": endpoint, "payload": payload.duplicate(true), "ticket": ticket})
		await get_tree().process_frame
		return replies.pop_front() if not replies.is_empty() else {"ok": false, "code": "NetworkError", "message": "模拟断网"}

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors += 1
		push_error(message)

func good(data: Dictionary = {}) -> Dictionary:
	return {"ok": true, "data": data}

func wire(status: int, envelope: Variant, result: int = HTTPRequest.RESULT_SUCCESS) -> Dictionary:
	return Transport.decode_response(result, status, JSON.stringify(envelope).to_utf8_buffer())

func run() -> void:
	root.size = Vector2i(1280, 675)
	var settings := Settings.new()
	settings.load_file()
	check(settings.title_id == "CDD5F" and settings.statistic_name == "Test", "Default settings preserve the original public title and statistic")
	var invalid := Settings.new()
	check(not invalid.is_configured(), "An unconfigured backend disables online features")
	invalid.title_id = "CDD5F/path"
	check(not invalid.is_configured(), "A title cannot inject an endpoint or host")
	check(wire(200, {"code": 200, "data": {"Leaderboard": []}}).ok, "Successful API envelope is decoded")
	check(not wire(200, []).ok and not wire(200, {"code": 200, "data": []}).ok, "Malformed JSON shapes fail safely")
	check(not Transport.decode_response(0, 200, "not json".to_utf8_buffer()).ok, "Non-JSON replies cannot crash the client")
	check(not wire(200, {}, HTTPRequest.RESULT_TIMEOUT).ok, "Network timeout is reported without a successful result")
	check(wire(400, {"error": "InvalidSessionTicket"}).code == "InvalidSessionTicket", "Expired credentials retain a machine-readable error code")
	check(wire(400, {"error": "NameNotAvailable"}).message.contains("昵称"), "Duplicate nickname has actionable feedback")
	check(not wire(503, {"error": "UnknownError", "errorMessage": "private diagnostic"}).message.contains("private"), "Raw server diagnostics are not exposed")
	var profile := Profile.new(profile_path)
	var identity := profile.identity("CDD5F")
	check(identity.ok and identity.custom_id.length() == 68, "New installation uses a cryptographically random identity")
	check(profile.identity("CDD5F").custom_id == identity.custom_id, "Device identity survives another read")
	check(profile.identity("ABC12").custom_id != identity.custom_id, "Different titles have independent identities")
	var fake := FakeTransport.new()
	var client := Client.new(settings, profile, fake)
	root.add_child(client)
	check(not client.has_session() and fake.calls.is_empty(), "Boot does not automatically connect or create an online account")
	var result: Dictionary = await client.fetch_leaderboard()
	check(not result.ok and fake.calls.is_empty(), "Leaderboard requires an explicit connection")
	result = await client.connect_profile("ab")
	check(not result.ok and fake.calls.is_empty(), "Invalid names fail before a network request")
	fake.replies = [good({"SessionTicket": "fake-session-ticket"}), good({"DisplayName": "骑手甲"})]
	result = await client.connect_profile("  骑手甲  ")
	check(result.ok and client.has_session() and not client.busy, "Login and name update produce a usable session")
	check(fake.calls[0].endpoint == "LoginWithCustomID" and fake.calls[0].payload.CustomId == identity.custom_id, "Login uses device identity rather than the nickname")
	check(fake.calls[0].payload.TitleId == "CDD5F" and fake.calls[0].payload.CreateAccount and fake.calls[0].ticket.is_empty(), "Login follows the PlayFab client contract")
	check(fake.calls[1].endpoint == "UpdateUserTitleDisplayName" and fake.calls[1].payload.DisplayName == "骑手甲" and fake.calls[1].ticket == "fake-session-ticket", "Nickname update uses the authenticated session")
	check(profile.display_name("CDD5F") == "骑手甲", "Nickname is saved for the next launch")
	check(not FileAccess.get_file_as_string(profile_path).contains("fake-session-ticket"), "Session credentials are never saved in the profile")
	fake.replies = [good({"DisplayName": "骑手乙"})]
	result = await client.connect_profile("骑手乙")
	check(result.ok and fake.calls.size() == 3 and profile.identity("CDD5F").custom_id == identity.custom_id, "Changing a nickname preserves the account and does not log in as another player")
	fake.replies = [good({"Leaderboard": [{"Position": 0, "DisplayName": "骑手乙", "StatValue": 340}, {"Position": 1, "DisplayName": null, "StatValue": -12}]})]
	result = await client.fetch_leaderboard()
	check(result.ok and client.leaderboard[0].rank == 1 and client.leaderboard[1].name == "未命名玩家", "Leaderboard uses one-based ranks and handles unnamed players")
	check(client.leaderboard[1].score == -12, "Negative income remains an honest score")
	var request: Dictionary = fake.calls.back().payload
	check(request == {"StatisticName": "Test", "StartPosition": 0, "MaxResultsCount": 100}, "Leaderboard requests the original top 100")
	fake.replies = [good({"Leaderboard": [{"Position": "bad", "StatValue": 20}]})]
	result = await client.fetch_leaderboard()
	check(not result.ok and client.leaderboard.size() == 2, "Malformed entries preserve the last valid leaderboard")
	fake.replies = [good({"Leaderboard": []})]
	client.fetch_leaderboard()
	check(client.busy, "An asynchronous request owns the busy guard")
	var call_count := fake.calls.size()
	result = await client.fetch_leaderboard()
	check(not result.ok and fake.calls.size() == call_count, "Repeated clicks cannot create overlapping requests")
	await process_frame
	await process_frame
	check(not client.busy and client.leaderboard.is_empty(), "Empty leaderboard is a successful result and releases the guard")
	fake.replies = [good()]
	result = await client.submit_score(340, "run-one")
	check(result.ok and fake.calls.back().payload == {"Statistics": [{"StatisticName": "Test", "Value": 340}]}, "Submission sends final income to the original statistic")
	call_count = fake.calls.size()
	result = await client.submit_score(340, "run-one")
	check(result.ok and fake.calls.size() == call_count, "Reopening the same run never submits it twice")
	result = await client.submit_score(2147483648, "too-large")
	check(not result.ok and fake.calls.size() == call_count, "Out-of-range scores cannot be silently truncated")
	fake.replies = [{"ok": false, "code": "NetworkError", "message": "模拟断网"}]
	result = await client.submit_score(500, "retry-run")
	check(not result.ok and not client.submitted_runs.has("retry-run"), "Failed score submission remains retryable")
	fake.replies = [good()]
	result = await client.submit_score(500, "retry-run")
	check(result.ok and client.submitted_runs.has("retry-run"), "Explicit retry commits the score once")
	fake.replies = [wire(400, {"error": "InvalidSessionTicket"})]
	result = await client.fetch_leaderboard()
	check(not result.ok and not client.has_session() and not client.busy, "Expired session returns to the connection flow")
	fake.replies = [good({"SessionTicket": "second-fake-ticket"}), good({"DisplayName": "骑手乙"})]
	result = await client.connect_profile("骑手乙")
	check(result.ok and fake.calls[-2].payload.CustomId == identity.custom_id, "Reconnecting restores the existing device account")
	var board := Board.new(client, 780, "ui-run")
	root.add_child(board)
	await process_frame
	await process_frame
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 675))
	check(bounds.encloses(board.view.get_global_rect()) and bounds.encloses(board.view.submit_button.get_global_rect()) and bounds.encloses(board.view.status.get_global_rect()), "Leaderboard layout and its actions fit the game viewport")
	check(board.view.submit_button != null and not board.view.submit_button.disabled, "Final-score overlay enables explicit submission for a connected player")
	fake.replies = [good(), {"ok": false, "code": "NetworkError", "message": "模拟断网"}]
	board.view.submit_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	check(client.submitted_runs.has("ui-run") and board.view.submit_button.disabled and board.view.status.text.contains("刷新失败"), "Refresh failure after a successful upload never invites resubmission")
	board.queue_free()
	await process_frame
	board = Board.new(client)
	root.add_child(board)
	check(board.view.submit_button == null, "Menu overlay has no score submission button")
	fake.replies = [good({"Leaderboard": []})]
	board.view.refresh_button.pressed.emit()
	board.queue_free()
	await process_frame
	await process_frame
	check(not client.busy, "Closing the modal during a request releases the service normally")
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	menu.leaderboard_button.pressed.emit()
	check(is_instance_valid(menu.leaderboard) and menu.leaderboard.run_score == null and not menu.leaving_menu, "Menu ranking button opens the modal without entering gameplay")
	menu.queue_free()
	await process_frame
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.state.money = 999
	game.day_cycle.finish_run()
	game.end_summary.find_child("LeaderboardButton", true, false).pressed.emit()
	check(is_instance_valid(game.leaderboard) and game.leaderboard.run_score == 999, "Final view passes the actual run income to the overlay")
	game.day_cycle.restart()
	await process_frame
	check(not is_instance_valid(game.leaderboard) and game.state.money == 100, "Restart disposes the old score view without resetting the online session")
	game.queue_free()
	client.queue_free()
	await process_frame
	await process_frame
	var corrupt := ConfigFile.new()
	corrupt.set_value("CDD5F", "custom_id", "nickname-as-identity")
	corrupt.save(profile_path)
	check(not profile.identity("CDD5F").ok, "Damaged identity does not silently create a different account")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	print("PLAYFAB REGRESSION RESULT: %s (%d checks)" % ["PASS" if errors == 0 else "FAIL", checks])
	quit(0 if errors == 0 else 1)
