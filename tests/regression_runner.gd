extends SceneTree

const BlockRecord = preload("res://scripts/core/block_record.gd")
const FixedScenario = preload("res://tests/fixtures/fixed_scenario.gd")
const FixedScenarioScene = preload("res://tests/fixtures/fixed_scenario_scene.gd")
const Main = preload("res://scripts/main.gd")
const FiringCases = preload("res://tests/fixtures/firing_cases.gd")
const StabilityCases = preload("res://tests/fixtures/stability_cases.gd")
const ResolutionState = preload("res://scripts/core/resolution_state.gd")

func _init() -> void:
	var requirement := _read_requirement()
	var passed := run_requirement(requirement)
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
		_:
			push_error("Unknown requirement: %s" % requirement)
			return false

func _read_requirement() -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find("--requirement")
	if index < 0 or index + 1 >= arguments.size():
		return ""
	return arguments[index + 1]

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
