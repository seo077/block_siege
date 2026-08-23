extends SceneTree

const BlockRecord = preload("res://scripts/core/block_record.gd")
const FixedScenario = preload("res://tests/fixtures/fixed_scenario.gd")

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
	return true

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
