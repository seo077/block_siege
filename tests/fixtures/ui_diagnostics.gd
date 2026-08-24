class_name UiDiagnostics
extends RefCounted

const SiegeBlock = preload("res://scripts/siege_block.gd")

static func assert_diagnostics(main: Node) -> bool:
	if not _assert_visible_state(main, &"ready", "initial"):
		return false
	var match_state = main.get("match_state")
	var attacker = match_state.players[0]
	if not main.call("fire_weapon", attacker.id, attacker.weapons[0].id, Vector2(80, -20)):
		return _fail("resolving", "play scene rejected the fixture shot")
	var shot_id: int = match_state.active_shot_block_id
	if not _assert_visible_state(main, &"resolving", "resolving"):
		return false
	var poses: Dictionary = main.call("collect_resolution_poses")
	var motions: Dictionary = main.call("collect_resolution_motion")
	match_state.enter_timeout(poses, motions)
	var resolution_state = main.get("resolution_state")
	resolution_state.status = &"timeout"
	resolution_state.retry_available = true
	main.set("resolution_retry_available", true)
	main.set("resolving_shot", false)
	main.call("update_ui", "timeout fixture")
	if not _assert_visible_state(main, &"timeout", "timeout"):
		return false
	var error := main.get_node_or_null("HUD/TimeoutError") as Label
	var retry := main.get_node_or_null("HUD/RetryButton") as Button
	if error == null or not error.visible or error.text.is_empty():
		return _fail("timeout error", "visible error text is missing")
	if retry == null or not retry.visible or retry.disabled:
		return _fail("timeout retry", "Retry is missing, hidden, or disabled")
	print("PASS REQ-010-UI timeout error and enabled Retry")
	retry.emit_signal("pressed")
	if match_state.active_shot_block_id != shot_id:
		return _fail("retry", "shot block ID changed")
	if main.call("current_adjudication_state") != &"resolving":
		return _fail("retry", "shot did not resume resolving")
	if retry.visible or not retry.disabled:
		return _fail("retry", "Retry did not immediately leave timeout state")
	if not _assert_visible_state(main, &"resolving", "retry refreshed"):
		return false
	print("PASS REQ-010-UI Retry preserved shot %d and refreshed the HUD" % shot_id)
	return true

static func _assert_visible_state(main: Node, expected_state: StringName, subcase: String) -> bool:
	var state_label := main.get_node_or_null("HUD/AdjudicationState") as Label
	var total_label := main.get_node_or_null("HUD/BlockTotal") as Label
	if state_label == null or total_label == null:
		return _fail(subcase, "required HUD labels are missing")
	var observed_state: StringName = main.call("current_adjudication_state")
	var scene_total := _scene_block_count(main)
	var ledger_total := _ledger_reference_count(main.get("match_state"))
	if observed_state != expected_state or state_label.text != "State: %s" % expected_state:
		return _fail(subcase, "visible state '%s' does not match observed '%s'" % [state_label.text, observed_state])
	if scene_total != 200 or ledger_total != 200:
		return _fail(subcase, "independent totals were scene=%d ledger=%d" % [scene_total, ledger_total])
	if "Blocks: %d/200" % scene_total not in total_label.text:
		return _fail(subcase, "visible total '%s' does not match independent totals" % total_label.text)
	print("PASS REQ-010-UI %s state=%s scene=%d ledger=%d" % [subcase, expected_state, scene_total, ledger_total])
	return true

static func _scene_block_count(main: Node) -> int:
	var count := 0
	for child in main.get_children():
		if child is SiegeBlock:
			count += 1
	return count

static func _ledger_reference_count(match_state) -> int:
	var count := int(match_state.active_shot_block_id >= 0)
	for player in match_state.players:
		count += player.reserve_block_ids.size()
		count += player.fortress_block_ids.size()
		for weapon in player.weapons:
			count += weapon.structure_block_ids.size()
			count += int(weapon.ammo_block_id >= 0)
	return count

static func _fail(subcase: String, detail: String) -> bool:
	push_error("FAIL REQ-010-UI %s: %s" % [subcase, detail])
	return false
