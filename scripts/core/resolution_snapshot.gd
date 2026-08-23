class_name ResolutionSnapshot
extends RefCounted

var _model: Dictionary
var _poses: Dictionary
var _motions: Dictionary

static func capture(state, poses: Dictionary, motions: Dictionary):
	var snapshot = new()
	var player_data: Array = []
	for player in state.players:
		var weapons: Array = []
		for weapon in player.weapons:
			weapons.append({
				"id": weapon.id, "owner_id": weapon.owner_id, "kind": weapon.kind,
				"structure_block_ids": weapon.structure_block_ids.duplicate(),
				"ammo_block_id": weapon.ammo_block_id, "fired_this_turn": weapon.fired_this_turn,
			})
		player_data.append({
			"id": player.id, "reserve_block_ids": player.reserve_block_ids.duplicate(),
			"fortress_block_ids": player.fortress_block_ids.duplicate(),
			"turn_actions": player.turn_actions.duplicate(true), "weapons": weapons,
		})
	snapshot._model = {
		"active_player_id": state.active_player_id, "round_number": state.round_number,
		"match_result": state.match_result.duplicate(true), "resolving_shot": state.resolving_shot,
		"combat_input_locked": state.combat_input_locked,
		"active_shot_block_id": state.active_shot_block_id,
		"active_shot_attacker_id": state.active_shot_attacker_id,
		"active_shot_weapon_id": state.active_shot_weapon_id,
		"resolved_shot_keys": state.resolved_shot_keys.duplicate(true),
		"original_block_ids": state.original_block_ids.duplicate(),
		"ownership": state.ownership_snapshot(), "players": player_data,
	}
	snapshot._poses = poses.duplicate(true)
	snapshot._motions = motions.duplicate(true)
	return snapshot

func restore_into(state: MatchState) -> Dictionary:
	state.active_player_id = _model.active_player_id
	state.round_number = _model.round_number
	state.match_result = _model.match_result.duplicate(true)
	state.resolving_shot = _model.resolving_shot
	state.combat_input_locked = _model.combat_input_locked
	state.active_shot_block_id = _model.active_shot_block_id
	state.active_shot_attacker_id = _model.active_shot_attacker_id
	state.active_shot_weapon_id = _model.active_shot_weapon_id
	state.resolved_shot_keys = _model.resolved_shot_keys.duplicate(true)
	state.original_block_ids.assign(_model.original_block_ids)
	for block_id in _model.ownership:
		var saved: Dictionary = _model.ownership[block_id]
		var block = state.blocks.get(block_id)
		if block != null:
			block.owner_id = saved.owner_id
			block.location = saved.location
			block.object_id = saved.object_id
	for saved_player in _model.players:
		var player = state.get_player(saved_player.id)
		if player == null: continue
		player.reserve_block_ids.assign(saved_player.reserve_block_ids)
		player.fortress_block_ids.assign(saved_player.fortress_block_ids)
		player.turn_actions = saved_player.turn_actions.duplicate(true)
		for saved_weapon in saved_player.weapons:
			var weapon = player.find_weapon(saved_weapon.id)
			if weapon == null: continue
			weapon.owner_id = saved_weapon.owner_id
			weapon.kind = saved_weapon.kind
			weapon.structure_block_ids.assign(saved_weapon.structure_block_ids)
			weapon.ammo_block_id = saved_weapon.ammo_block_id
			weapon.fired_this_turn = saved_weapon.fired_this_turn
	return {"poses": _poses.duplicate(true), "motions": _motions.duplicate(true)}

func equals_runtime(state: MatchState, poses: Dictionary, motions: Dictionary) -> bool:
	if poses != _poses or motions != _motions:
		return false
	if state.active_player_id != _model.active_player_id or state.round_number != _model.round_number:
		return false
	if state.match_result != _model.match_result or state.ownership_snapshot() != _model.ownership:
		return false
	if state.resolving_shot != _model.resolving_shot or state.resolved_shot_keys != _model.resolved_shot_keys:
		return false
	if state.original_block_ids != _model.original_block_ids:
		return false
	if state.active_shot_block_id != _model.active_shot_block_id or state.active_shot_attacker_id != _model.active_shot_attacker_id or state.active_shot_weapon_id != _model.active_shot_weapon_id:
		return false
	for saved_player in _model.players:
		var player = state.get_player(saved_player.id)
		if player == null or player.reserve_block_ids != saved_player.reserve_block_ids or player.fortress_block_ids != saved_player.fortress_block_ids or player.turn_actions != saved_player.turn_actions:
			return false
		for saved_weapon in saved_player.weapons:
			var weapon = player.find_weapon(saved_weapon.id)
			if weapon == null or weapon.owner_id != saved_weapon.owner_id or weapon.kind != saved_weapon.kind or weapon.structure_block_ids != saved_weapon.structure_block_ids or weapon.ammo_block_id != saved_weapon.ammo_block_id or weapon.fired_this_turn != saved_weapon.fired_this_turn:
				return false
	return true
