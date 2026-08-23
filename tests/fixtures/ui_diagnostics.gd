class_name UiDiagnostics
extends RefCounted

static func assert_diagnostics(main) -> bool:
	main.create_match()
	main.create_ui()
	main.update_ui("initial")
	if not _shows(main, "ready", "Blocks: 200/200", "Ledger: valid"):
		return false
	main.match_state.resolving_shot = true
	main.update_ui("resolving")
	if not _shows(main, "resolving", "Blocks: 200/200", "Ledger: valid"):
		return false
	main.match_state.resolving_shot = false
	var attacker = main.match_state.players[0]
	if not main.fire_weapon(attacker.id, attacker.weapons[0].id, Vector2(80, -20)):
		return false
	var poses: Dictionary = main.collect_resolution_poses()
	var motions: Dictionary = main.collect_resolution_motion()
	main.match_state.enter_timeout(poses, motions)
	main.resolution_state.status = &"timeout"
	main.resolution_state.retry_available = true
	main.resolution_retry_available = true
	main.resolving_shot = false
	main.update_ui("timeout")
	var retry = main.get_node("HUD/RetryButton")
	var error = main.get_node("HUD/TimeoutError")
	if not _shows(main, "timeout", "Blocks: 200/200", "Ledger: valid") or not retry.visible or retry.disabled or not error.visible:
		return false
	main.on_retry_pressed()
	if main.current_adjudication_state() != &"resolving" or retry.visible:
		return false
	main.match_state.players[0].reserve_block_ids.append(main.match_state.players[0].reserve_block_ids[0])
	main.update_ui("invalid")
	if "Ledger: invalid" not in main.diagnostic_text():
		return false
	main.match_state.players[0].reserve_block_ids.pop_back()
	main.match_state.resolving_shot = false
	main.resolving_shot = false
	main.resolution_state = null
	main.match_state.match_result.final = true
	main.update_ui("final")
	return _shows(main, "final", "Blocks: 200/200", "Ledger: valid")

static func _shows(main, state: String, blocks: String, ledger: String) -> bool:
	var text: String = main.diagnostic_text()
	return "State: %s" % state in text and blocks in text and ledger in text
