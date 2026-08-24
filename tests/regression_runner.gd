extends SceneTree

const BlockRecord = preload("res://scripts/core/block_record.gd")
const FixedScenario = preload("res://tests/fixtures/fixed_scenario.gd")
const FixedScenarioScene = preload("res://tests/fixtures/fixed_scenario_scene.gd")
const Main = preload("res://scripts/main.gd")
const FiringCases = preload("res://tests/fixtures/firing_cases.gd")
const StabilityCases = preload("res://tests/fixtures/stability_cases.gd")
const ResolutionState = preload("res://scripts/core/resolution_state.gd")
const CollapseCases = preload("res://tests/fixtures/collapse_cases.gd")
const WeaponState = preload("res://scripts/core/weapon_state.gd")
const PlayerState = preload("res://scripts/core/player_state.gd")
const ResolutionCases = preload("res://tests/fixtures/resolution_cases.gd")
const LedgerCases = preload("res://tests/fixtures/ledger_cases.gd")
const ResolutionTransaction = preload("res://scripts/core/resolution_transaction.gd")
const TurnAndVictoryCases = preload("res://tests/fixtures/turn_and_victory_cases.gd")
const RetryCases = preload("res://tests/fixtures/retry_cases.gd")
const ResolutionSnapshot = preload("res://scripts/core/resolution_snapshot.gd")
const UiDiagnostics = preload("res://tests/fixtures/ui_diagnostics.gd")
const FullRegression = preload("res://tests/fixtures/full_regression.gd")

func _init() -> void:
	var options := parse_arguments(OS.get_cmdline_user_args())
	if not options.valid:
		report_failure("arguments", "command line", options.error)
		quit(1)
		return
	var repeat_count: int = options.repeat
	var requirement: String = options.requirement
	var passed := run_all(repeat_count) if options.all else (_run_req010(repeat_count) if requirement == "REQ-010" else run_requirement(requirement))
	if passed:
		print("PASS %s" % requirement)
	else:
		push_error("FAIL %s" % requirement)
	quit(0 if passed else 1)

func run_requirement(requirement: String) -> bool:
	match requirement:
		"REQ-001":
			return _verify_fixed_scenario()
		"REQ-002":
			return _verify_player_list_model()
		"REQ-003":
			return _verify_guarded_firing()
		"REQ-004":
			return _verify_fixed_tick_resolution()
		"REQ-005":
			return _verify_collapse_classification()
		"REQ-006":
			return _verify_resolution_transaction()
		"REQ-007":
			return _verify_ledger_transitions()
		"REQ-008":
			return _verify_turns_and_victory()
		"REQ-009":
			return _verify_timeout_retry()
		"REQ-010":
			return _run_req010(1)
		"REQ-010-UI":
			return _verify_ui_diagnostics()
		"REQ-012":
			return _verify_utf8_hud()
		"REQ-013":
			return _verify_drag_launch()
		_:
			push_error("Unknown requirement: %s" % requirement)
			return false

func parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var result := {"valid": true, "requirement": "", "repeat": 1, "all": false, "error": ""}
	var index := 0
	while index < arguments.size():
		match arguments[index]:
			"--requirement":
				if index + 1 >= arguments.size(): return _argument_error(result, "--requirement needs a value")
				result.requirement = arguments[index + 1]
				index += 2
			"--repeat":
				if index + 1 >= arguments.size() or not arguments[index + 1].is_valid_int() or int(arguments[index + 1]) < 1:
					return _argument_error(result, "--repeat must be a positive integer")
				result.repeat = int(arguments[index + 1])
				index += 2
			"--all":
				result.all = true
				index += 1
			_:
				return _argument_error(result, "unknown argument: %s" % arguments[index])
	if not result.all and result.requirement.is_empty(): return _argument_error(result, "use --requirement REQ-NNN or --all")
	if result.all and not result.requirement.is_empty(): return _argument_error(result, "--all and --requirement are mutually exclusive")
	return result

func _argument_error(result: Dictionary, detail: String) -> Dictionary:
	result.valid = false
	result.error = detail
	return result

func run_all(repeat_count: int = 1) -> bool:
	if repeat_count < 1:
		report_failure("all", "matrix", "repeat_count must be positive")
		return false
	for repetition in range(1, repeat_count + 1):
		print("REGRESSION repetition %d/%d" % [repetition, repeat_count])
		for scenario in FullRegression.scenarios():
			var requirement: String = scenario.requirement
			var fixture: String = scenario.fixture
			print("RUN %s [%s]" % [requirement, fixture])
			if not run_requirement(requirement):
				report_failure(requirement, fixture, "verifier returned false in repetition %d" % repetition)
				return false
	return true

func _run_req010(repeat_count: int) -> bool:
	return run_all(repeat_count)

func report_failure(requirement, fixture, detail) -> void:
	push_error("REGRESSION FAILURE requirement=%s fixture=%s detail=%s" % [requirement, fixture, detail])

func _verify_utf8_hud() -> bool:
	var oracle := PackedStringArray([
		"플레이어 1의 턴", "[1] 투석기  [2] 전차  |  마우스 드래그: 발사\n전차 선택 중 WASD: 이동  |  [Enter]: 턴 종료",
		"투석기 선택", "전차 선택", "드래그가 너무 짧습니다", "이 병기는 이번 턴에 이미 발사했습니다",
		"이 병기는 장전되지 않았습니다", "물리 판정 중…", "발사 판정 완료", "플레이어 %d 승리 — 요새 완파",
		"턴 전환", "플레이어 %d 판정승", "무승부", "라운드 %d/%d  |  플레이어 %d  |  %s",
		"예비 블럭 P1: %d  P2: %d  |  %s", "프로토타입 종료", "투석기", "전차",
	])
	if Main.APPROVED_KOREAN_STRINGS != oracle:
		return false
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if source.contains("�") or source.contains("íˆ¬") or source.contains("ì „"):
		return false
	var main := Main.new()
	root.add_child(main)
	main.create_match()
	main.create_ui()
	var snapshot: Dictionary = main.web_test_snapshot()
	var passed := snapshot.has_all(["hud_strings", "approved_korean_strings", "pointer_events", "shot_id", "shot_count", "initial_velocity", "impulse_magnitude", "normalized_direction", "active_player", "adjudication_state"])
	passed = passed and snapshot.approved_korean_strings == oracle and snapshot.hud_strings.has(oracle[1])
	main.free()
	return passed and oracle != PackedStringArray(["주입된 불일치"])

func _verify_drag_launch() -> bool:
	var main := Main.new()
	root.add_child(main)
	for player_index in 2:
		if main.launch_solution(player_index, 0, Vector2(23.999, 0)).accepted:
			main.free()
			return false
		if not main.launch_solution(player_index, 0, Vector2(24, 0)).accepted:
			main.free()
			return false
		var forward := Vector3.RIGHT if player_index == 0 else Vector3.LEFT
		var camera_right := forward.cross(Vector3.UP).normalized()
		var right: Dictionary = main.launch_solution(player_index, 0, Vector2(80, 0))
		var left: Dictionary = main.launch_solution(player_index, 0, Vector2(-80, 0))
		if right.normalized_direction.dot(camera_right) <= 0.0 or left.normalized_direction.dot(camera_right) >= 0.0:
			main.free()
			return false
		if right.normalized_direction.dot(forward) <= 0.0:
			main.free()
			return false
		var level: Dictionary = main.launch_solution(player_index, 0, Vector2(0, 80))
		var upward: Dictionary = main.launch_solution(player_index, 0, Vector2(0, -80))
		if upward.normalized_direction.y <= level.normalized_direction.y:
			main.free()
			return false
	var impulses: Array[float] = []
	for length in [40.0, 120.0, 240.0]:
		impulses.append(main.launch_solution(0, 0, Vector2(length, 0)).impulse_magnitude)
	main.free()
	return impulses[0] < impulses[1] and impulses[1] < impulses[2]

func _verify_fixed_scenario() -> bool:
	var first := FixedScenario.build()
	var second := FixedScenario.build()
	if first.total_block_count() != 200 or not first.validate_ledger().valid:
		return false
	if first.blocks.keys() != second.blocks.keys():
		return false
	for player_id in [1, 2]:
		var player := first.get_player(player_id)
		if player == null or player.reserve_block_ids.size() != 87 or player.fortress_block_ids.size() != 6:
			return false
		if player.weapons.size() != 2 or not player.weapons[0].can_fire() or not player.weapons[1].can_fire():
			return false
		if player.weapons[0].kind != &"catapult" or player.weapons[1].kind != &"tank":
			return false
		var owned := player.reserve_block_ids.size() + player.fortress_block_ids.size()
		for weapon in player.weapons:
			owned += weapon.structure_block_ids.size() + int(weapon.ammo_block_id >= 0)
		if owned != 100:
			return false
	var main := Main.new()
	root.add_child(main)
	main.create_match()
	var scene_valid := FixedScenarioScene.assert_scene_binding(main)
	main.free()
	return scene_valid

func _verify_ui_diagnostics() -> bool:
	var scene := load("res://main.tscn") as PackedScene
	if scene == null:
		report_failure("REQ-010-UI", "play scene", "res://main.tscn could not be loaded")
		return false
	var main := scene.instantiate()
	root.add_child(main)
	main.call("create_match")
	main.call("create_ui")
	var passed := UiDiagnostics.assert_diagnostics(main)
	main.free()
	return passed

func _verify_player_list_model() -> bool:
	for ids in [[7, 3], [30, 10, 20], [20, 30, 10]]:
		var typed_ids: Array[int] = []
		typed_ids.assign(ids)
		var match_state = FixedScenario.build(typed_ids)
		if match_state.players.size() != ids.size() or not match_state.validate_ledger().valid:
			return false
		for index in ids.size():
			var expected_id: int = ids[index]
			var player = match_state.players[index]
			if player.id != expected_id or match_state.get_player(expected_id) != player:
				return false
			for block_id in player.reserve_block_ids + player.fortress_block_ids:
				if (match_state.blocks[block_id] as BlockRecord).owner_id != expected_id:
					return false
		var action_owner = match_state.get_player(ids[0])
		action_owner.turn_actions.shots_fired = 1
		for other in match_state.players:
			if other.id != action_owner.id and other.turn_actions.shots_fired != 0:
				return false
	return true

func _verify_guarded_firing() -> bool:
	for firing_case in FiringCases.cases():
		var main := Main.new()
		root.add_child(main)
		main.create_match()
		var player = main.match_state.players[firing_case.player_index]
		var weapon = player.weapons[firing_case.weapon_index]
		var ammo_id: int = weapon.ammo_block_id
		if firing_case.kind == &"unloaded":
			weapon.ammo_block_id = -1
		if firing_case.kind == &"repeated":
			if not main.fire_weapon(player.id, weapon.id, firing_case.drag):
				main.free()
				return false
		var accepted: bool = main.fire_weapon(player.id, weapon.id, firing_case.drag)
		if accepted != firing_case.expected:
			main.free()
			return false
		var projectile_count := 0
		for body in main.block_bodies.values():
			if body.is_in_group("projectile"):
				projectile_count += 1
		var expected_count := 1 if firing_case.kind in [&"valid", &"repeated"] else 0
		if projectile_count != expected_count:
			main.free()
			return false
		if expected_count == 1:
			var projectile = main.body_for_block(ammo_id)
			if projectile == null or projectile.block_id != ammo_id or not projectile.is_in_group("projectile"):
				main.free()
				return false
			if weapon.ammo_block_id != -1 or not weapon.fired_this_turn:
				main.free()
				return false
		main.free()
	return true

func _verify_fixed_tick_resolution() -> bool:
	for stability_case in StabilityCases.cases():
		var threshold_state := ResolutionState.begin(1, [2])
		var motion := {1: {"linear": stability_case.linear, "angular": stability_case.angular}, 2: {"linear": 0.0, "angular": 0.0}}
		threshold_state.advance_fixed_tick(0.81, motion)
		if (threshold_state.quiet_elapsed > 0.0) != stability_case.quiet:
			push_error("threshold case failed: %s quiet=%f" % [stability_case.kind, threshold_state.quiet_elapsed])
			return false
	var state := ResolutionState.begin(1, [2])
	var quiet := {1: {"linear": 0.12, "angular": 0.2}, 2: {"linear": 0.0, "angular": 0.0}}
	for index in 8:
		if state.advance_fixed_tick(0.1, quiet) != &"resolving":
			return false
	for index in 6:
		if state.advance_fixed_tick(0.1, quiet) != &"resolving":
			return false
	if state.advance_fixed_tick(0.1, quiet) != &"resolved":
		push_error("quiet resolution failed: elapsed=%f quiet=%f status=%s" % [state.elapsed, state.quiet_elapsed, state.status])
		return false
	var reset_state := ResolutionState.begin(1, [2])
	for index in 8:
		reset_state.advance_fixed_tick(0.1, quiet)
	for index in 5:
		reset_state.advance_fixed_tick(0.1, quiet)
	reset_state.advance_fixed_tick(0.1, {1: {"linear": 0.121, "angular": 0.2}, 2: {"linear": 0.0, "angular": 0.0}})
	if reset_state.quiet_elapsed != 0.0:
		push_error("moving tick did not reset quiet time")
		return false
	var timeout := ResolutionState.begin(1, [2])
	var moving := {1: {"linear": 0.121, "angular": 0.201}, 2: {"linear": 0.0, "angular": 0.0}}
	for index in 79:
		if timeout.advance_fixed_tick(0.1, moving) != &"resolving":
			return false
	if timeout.advance_fixed_tick(0.1, moving) != &"timeout" or not timeout.retry_available:
		push_error("timeout failed: elapsed=%f status=%s" % [timeout.elapsed, timeout.status])
		return false
	timeout.retry()
	return timeout.status == &"resolving" and timeout.elapsed == 0.0 and not timeout.retry_available

func _verify_collapse_classification() -> bool:
	var first := BlockRecord.create(1, 1, &"fortress", 1)
	var second := BlockRecord.create(2, 1, &"fortress", 1)
	var first_baseline := Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0.3)), Vector3(2.0, 3.0, 4.0))
	var second_baseline := Transform3D(Basis.from_euler(Vector3(-0.2, 0.4, -0.1)), Vector3(-3.0, 1.0, 7.0))
	first.capture_baseline(first_baseline)
	second.capture_baseline(second_baseline)
	for collapse_case in CollapseCases.cases():
		var pose := first_baseline
		pose.origin += collapse_case.offset
		pose.basis = first_baseline.basis * Basis(Vector3.RIGHT, deg_to_rad(collapse_case.degrees))
		if first.is_fallen_at(pose) != collapse_case.fallen:
			return false
	if not second.is_fallen_at(first_baseline):
		return false
	if not first.is_fallen_at(second_baseline):
		return false
	var blocks := {1: first, 2: second}
	var poses := {1: first_baseline.translated(Vector3(0.1, 0.0, 0.0)), 2: second_baseline}
	var player := PlayerState.create(1, [], [1, 2], [])
	if player.is_fortress_destroyed(blocks, poses):
		return false
	poses[2] = second_baseline * Transform3D(Basis(Vector3.UP, deg_to_rad(30.0)), Vector3.ZERO)
	if not player.is_fortress_destroyed(blocks, poses):
		return false
	var ammo := BlockRecord.create(3, 1, &"weapon", 1, true)
	ammo.capture_baseline(Transform3D.IDENTITY)
	blocks[3] = ammo
	poses[1] = first_baseline
	poses[2] = second_baseline
	poses[3] = Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0))
	var weapon := WeaponState.create(1, 1, &"catapult", [1, 2], 3)
	if weapon.is_destroyed(blocks, poses):
		return false
	poses[1] = first_baseline.translated(Vector3(0.1, 0.0, 0.0))
	poses[2] = second_baseline.translated(Vector3(0.1, 0.0, 0.0))
	return weapon.is_destroyed(blocks, poses)

func _poses_for(state, destroyed_indices: Array) -> Dictionary:
	var poses := {}
	for block_id in state.blocks:
		var block := state.blocks[block_id] as BlockRecord
		if not block.baseline_ready: block.capture_baseline(Transform3D.IDENTITY)
		poses[block_id] = block.baseline_transform
	var defender = state.players[1]
	for index in destroyed_indices:
		for block_id in defender.weapons[index].structure_block_ids:
			poses[block_id] = Transform3D(Basis.IDENTITY, Vector3(0.1, 0.0, 0.0))
	return poses

func _verify_resolution_transaction() -> bool:
	for resolution_case in ResolutionCases.cases():
		var state = FixedScenario.build()
		var attacker = state.players[0]
		var defender = state.players[1]
		var fired_id: int = attacker.weapons[0].ammo_block_id
		var expected: Array[int] = [fired_id]
		for index in resolution_case.destroyed_weapon_indices:
			expected.append_array(defender.weapons[index].structure_block_ids)
			expected.append(defender.weapons[index].ammo_block_id)
		if not state.request_fire(attacker.id, attacker.weapons[0].id, Vector2.ONE).accepted: return false
		var tx = ResolutionTransaction.build(state, _poses_for(state, resolution_case.destroyed_weapon_indices))
		if resolution_case.kind == &"invalid_plan":
			attacker.reserve_block_ids.append(attacker.reserve_block_ids[0])
			var invalid_before := _transaction_snapshot(state)
			var rejected = tx.apply(state)
			if rejected.applied or rejected.reason != "ledger_rejected" or invalid_before != _transaction_snapshot(state): return false
			continue
		var result = tx.apply(state)
		if not result.applied or not result.ledger.valid: return false
		expected.sort()
		if tx.affected_block_ids() != expected: return false
		var destination = defender if resolution_case.kind == &"failure" else attacker
		for block_id in expected:
			var block := state.blocks[block_id] as BlockRecord
			if block.owner_id != destination.id or block.location != &"reserve" or not destination.reserve_block_ids.has(block_id): return false
		if resolution_case.kind == &"single":
			for block_id in defender.weapons[1].structure_block_ids:
				if (state.blocks[block_id] as BlockRecord).owner_id != defender.id: return false
		var before := state.ownership_snapshot()
		var duplicate = tx.apply(state)
		if duplicate.applied or duplicate.reason != "duplicate" or before != state.ownership_snapshot(): return false
	return true

func _verify_ledger_transitions() -> bool:
	var state = FixedScenario.build()
	var attacker = state.players[0]
	var fired := false
	var tx = null
	for ledger_case in LedgerCases.cases():
		match ledger_case.kind:
			&"fired":
				fired = state.request_fire(attacker.id, attacker.weapons[0].id, Vector2.ONE).accepted
			&"resolved":
				tx = ResolutionTransaction.build(state, _poses_for(state, [0, 1]))
				if not tx.apply(state).applied: return false
			&"duplicate":
				var before := state.ownership_snapshot()
				if tx.apply(state).applied or before != state.ownership_snapshot(): return false
			&"duplicate_reference":
				var duplicate_id: int = attacker.reserve_block_ids[0]
				attacker.reserve_block_ids.append(duplicate_id)
				var duplicate_ledger := state.validate_ledger()
				if duplicate_ledger.valid or duplicate_ledger.duplicate_count != 1: return false
				attacker.reserve_block_ids.pop_back()
			_:
				pass # delete-pending, timeout, and retry do not mutate ownership.
		var ledger := state.validate_ledger()
		if not ledger.valid or ledger.block_count != ledger.expected_count or ledger.unique_count != ledger.expected_count or ledger.duplicate_count != 0 or not ledger.missing.is_empty() or not ledger.unknown.is_empty(): return false
	if not fired: return false
	return true

func _transaction_snapshot(state) -> Dictionary:
	var players_snapshot := []
	for player in state.players:
		var weapons_snapshot := []
		for weapon in player.weapons:
			weapons_snapshot.append([weapon.id, weapon.structure_block_ids.duplicate(), weapon.ammo_block_id])
		players_snapshot.append([player.id, player.reserve_block_ids.duplicate(), weapons_snapshot])
	return {
		"ownership": state.ownership_snapshot(),
		"players": players_snapshot,
		"active": [state.active_shot_block_id, state.active_shot_attacker_id, state.active_shot_weapon_id, state.resolving_shot],
		"resolved": state.resolved_shot_keys.duplicate(true),
	}

func _verify_timeout_retry() -> bool:
	var main := Main.new()
	root.add_child(main)
	main.create_match()
	var scene_attacker = main.match_state.players[0]
	if not main.fire_weapon(scene_attacker.id, scene_attacker.weapons[0].id, Vector2(80, -20)): return false
	var scene_shot: int = main.match_state.active_shot_block_id
	var scene_body = main.body_for_block(scene_shot)
	var timeout_pose := Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0.3)), Vector3(3, 4, 5))
	var timeout_linear := Vector3(4, 5, 6)
	var timeout_angular := Vector3(1, 2, 3)
	scene_body.global_transform = timeout_pose
	scene_body.linear_velocity = timeout_linear
	scene_body.angular_velocity = timeout_angular
	var scene_poses := main.collect_resolution_poses()
	var scene_motions := main.collect_resolution_motion()
	main.match_state.enter_timeout(scene_poses, scene_motions)
	main.freeze_timeout_bodies()
	main.resolving_shot = false
	for tick in 12: main._physics_process(0.1)
	if not scene_body.freeze or scene_body.transform != timeout_pose: return false
	if scene_body.linear_velocity != timeout_linear or scene_body.angular_velocity != timeout_angular: return false
	if not main.match_state.timeout_snapshot.equals_runtime(main.match_state, scene_poses, scene_motions): return false
	main.free()
	for retry_case in RetryCases.cases():
		var state = FixedScenario.build()
		var attacker = state.players[0]
		var shot_id: int = attacker.weapons[0].ammo_block_id
		if not state.request_fire(attacker.id, attacker.weapons[0].id, Vector2.ONE).accepted: return false
		var ownership := state.ownership_snapshot()
		var gameplay_before := _transaction_snapshot(state)
		var early_resolution := ResolutionState.begin(shot_id, [])
		if state.authorize_settled_resolution(early_resolution): return false
		for spam in 4:
			var early_callback = state.resolve_shot_once(_poses_for(state, []))
			if early_callback.applied or early_callback.reason != "resolution_not_settled": return false
		if gameplay_before != _transaction_snapshot(state) or state.ownership_snapshot() != ownership or state.resolution_apply_count() != 0: return false
		var poses := {shot_id: Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))}
		var motions := {shot_id: {"linear_velocity": Vector3(4, 5, 6), "angular_velocity": Vector3(1, 2, 3)}}
		state.enter_timeout(poses, motions)
		if not state.resolution_timeout_error or not state.combat_input_locked: return false
		var saved_snapshot = state.timeout_snapshot
		if not saved_snapshot.equals_runtime(state, poses, motions): return false
		poses[shot_id] = Transform3D.IDENTITY
		motions[shot_id].linear_velocity = Vector3.ZERO
		if saved_snapshot.equals_runtime(state, poses, motions): return false
		if state.request_fire(attacker.id, attacker.weapons[1].id, Vector2.ONE).accepted: return false
		if state.request_end_turn(attacker.id).accepted: return false
		for spam in 4:
			if state.resolve_shot_once(_poses_for(state, [])).applied: return false
		if gameplay_before != _transaction_snapshot(state) or state.ownership_snapshot() != ownership or state.resolution_apply_count() != 0: return false
		var resolution := ResolutionState.begin(shot_id, [state.players[1].fortress_block_ids[0]])
		var moving := {shot_id: {"linear": 1.0, "angular": 1.0}, state.players[1].fortress_block_ids[0]: {"linear": 1.0, "angular": 1.0}}
		for tick in 80:
			if resolution.advance_fixed_tick(0.1, moving) != (&"timeout" if tick == 79 else &"resolving"): return false
		if not is_equal_approx(resolution.elapsed, 8.0): return false
		for timeout_index in retry_case.timeouts:
			var restored := state.retry_timed_out_shot()
			if restored.is_empty() or restored.poses[shot_id].origin != Vector3(1, 2, 3): return false
			if restored.motions[shot_id].linear_velocity != Vector3(4, 5, 6): return false
			if state.active_shot_block_id != shot_id or state.ownership_snapshot() != ownership: return false
			resolution.retry()
			if resolution.elapsed != 0.0 or resolution.quiet_elapsed != 0.0 or resolution.shot_block_id != shot_id or resolution.target_block_ids != [shot_id, state.players[1].fortress_block_ids[0]]: return false
			if timeout_index + 1 < retry_case.timeouts:
				state.enter_timeout(restored.poses, restored.motions)
				for tick in 80:
					if resolution.advance_fixed_tick(0.1, moving) != (&"timeout" if tick == 79 else &"resolving"): return false
				if not is_equal_approx(resolution.elapsed, 8.0): return false
		# Fixed-tick stability is the only path that authorizes the callback.
		var quiet := {shot_id: {"linear": 0.0, "angular": 0.0}, state.players[1].fortress_block_ids[0]: {"linear": 0.0, "angular": 0.0}}
		for tick in 15:
			if resolution.advance_fixed_tick(0.1, quiet) != (&"resolved" if tick == 14 else &"resolving"): return false
		if not state.authorize_settled_resolution(resolution): return false
		var resolved = state.resolve_shot_once(_poses_for(state, []))
		if not resolved.applied or state.resolution_apply_count() != 1: return false
		var duplicate = state.resolve_shot_once(_poses_for(state, []))
		if duplicate.applied or state.resolution_apply_count() != 1: return false
		if not state.validate_ledger().valid: return false
	return true

func _verify_turns_and_victory() -> bool:
	for test_case in TurnAndVictoryCases.cases():
		match test_case.kind:
			&"ordered_turns":
				var ids: Array[int] = []
				ids.assign(test_case.players)
				var state = FixedScenario.build(ids)
				for expected in test_case.expected:
					if state.round_number != expected[0] or state.active_player_id != expected[1]: return false
					if expected != test_case.expected[-1] and not state.request_end_turn(state.active_player_id).accepted: return false
			&"rejected_turns":
				var state = FixedScenario.build([1, 2, 3])
				if state.request_end_turn(2).accepted: return false
				state.resolving_shot = true
				if state.request_end_turn(1).accepted: return false
				state.resolving_shot = false
				state.combat_input_locked = true
				if state.request_end_turn(1).accepted: return false
			&"fortress_all", &"fortress_partial":
				var state = FixedScenario.build([1, 2])
				var poses := {}
				for block_id in state.blocks:
					var block := state.blocks[block_id] as BlockRecord
					block.capture_baseline(Transform3D.IDENTITY)
					poses[block_id] = Transform3D.IDENTITY
				for index in test_case.destroyed:
					poses[state.players[1].fortress_block_ids[index]] = Transform3D(Basis.IDENTITY, Vector3(0.1, 0.0, 0.0))
				var before := poses.duplicate(true)
				var result = state.adjudicate_fortress_victory(1, poses)
				if result.final != test_case.final or poses != before: return false
				if result.final:
					if result.winner_ids != [1] or state.request_end_turn(1).accepted: return false
					if state.adjudicate_round_limit() != result: return false
			&"round_boundary":
				var state = FixedScenario.build([1, 2, 3])
				state.round_number = 19
				for player_id in [1, 2, 3]:
					if not state.request_end_turn(player_id).accepted: return false
				if state.round_number != 20 or state.result_snapshot().final: return false
				for player_id in [1, 2]:
					if not state.request_end_turn(player_id).accepted or state.result_snapshot().final: return false
				if not state.request_end_turn(3).accepted or state.round_number != 20 or not state.result_snapshot().final: return false
			&"total_score", &"fortress_score", &"draw_score":
				var state = _score_state(test_case.totals, test_case.fortress)
				var result = state.adjudicate_round_limit()
				if test_case.winner < 0:
					if result.outcome != &"draw" or not result.winner_ids.is_empty(): return false
				elif result.outcome != &"victory" or result.winner_ids != [test_case.winner]: return false
	return true

func _score_state(totals: Array, fortress: Array):
	var players: Array[PlayerState] = [PlayerState.create(1, [], [], []), PlayerState.create(2, [], [], [])]
	var score_blocks := {}
	var next_id := 1
	for player_index in 2:
		for index in totals[player_index]:
			var location: StringName = &"fortress" if index < fortress[player_index] else &"reserve"
			score_blocks[next_id] = BlockRecord.create(next_id, player_index + 1, location, 0)
			next_id += 1
	return load("res://scripts/core/match_state.gd").create_from_players(players, score_blocks)
