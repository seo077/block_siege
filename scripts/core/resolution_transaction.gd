class_name ResolutionTransaction
extends RefCounted

var shot_block_id := -1
var attacker_id := -1
var defender_id := -1
var shot_key := ""
var transfers: Array[Dictionary] = []
var invalid_reason := ""

static func build(state: MatchState, poses: Dictionary):
	var tx = new()
	tx.shot_block_id = state.active_shot_block_id
	tx.attacker_id = state.active_shot_attacker_id
	if tx.shot_block_id < 0 or tx.attacker_id < 0 or not state.resolving_shot:
		tx.invalid_reason = "no_active_shot"
		return tx
	for player in state.players:
		if player.id != tx.attacker_id:
			tx.defender_id = player.id
			break
	if tx.defender_id < 0:
		tx.invalid_reason = "no_defender"
		return tx
	tx.shot_key = "%d:%d" % [tx.attacker_id, tx.shot_block_id]
	var destroyed_any := false
	for player in state.players:
		if player.id == tx.attacker_id: continue
		for weapon in player.weapons:
			if weapon.is_destroyed(state.blocks, poses):
				destroyed_any = true
				for block_id in weapon.structure_block_ids:
					tx.transfers.append({"block_id": block_id, "weapon": weapon, "ammo": false})
				if weapon.ammo_block_id >= 0:
					tx.transfers.append({"block_id": weapon.ammo_block_id, "weapon": weapon, "ammo": true})
	tx.transfers.append({"block_id": tx.shot_block_id, "weapon": null, "ammo": true, "owner_id": tx.attacker_id if destroyed_any else tx.defender_id})
	return tx

func affected_block_ids() -> Array[int]:
	var ids: Array[int] = []
	for transfer in transfers:
		ids.append(transfer.block_id)
	ids.sort()
	return ids

func apply(state: MatchState) -> Dictionary:
	if invalid_reason != "": return {"accepted": false, "applied": false, "reason": invalid_reason, "affected": []}
	if state.resolved_shot_keys.has(shot_key): return {"accepted": true, "applied": false, "reason": "duplicate", "affected": affected_block_ids()}
	if state.active_shot_block_id != shot_block_id or state.active_shot_attacker_id != attacker_id:
		return {"accepted": false, "applied": false, "reason": "stale_transaction", "affected": []}
	var seen := {}
	for transfer in transfers:
		var block_id: int = transfer.block_id
		if seen.has(block_id) or not state.blocks.has(block_id):
			return {"accepted": false, "applied": false, "reason": "invalid_plan", "affected": []}
		seen[block_id] = true
	var attacker = state.get_player(attacker_id)
	var defender = state.get_player(defender_id)
	if attacker == null or defender == null:
		return {"accepted": false, "applied": false, "reason": "invalid_players", "affected": []}
	for transfer in transfers:
		var planned_block_id: int = transfer.block_id
		var planned_owner: int = transfer.get("owner_id", attacker_id)
		var destination = state.get_player(planned_owner)
		if destination == null:
			return {"accepted": false, "applied": false, "reason": "invalid_destination", "affected": []}
		var planned_weapon = transfer.weapon
		if planned_weapon != null and not planned_weapon.structure_block_ids.has(planned_block_id) and planned_weapon.ammo_block_id != planned_block_id:
			return {"accepted": false, "applied": false, "reason": "invalid_reference", "affected": []}
	var block_before := {}
	for transfer in transfers:
		var saved_block = state.blocks[transfer.block_id]
		block_before[transfer.block_id] = [saved_block.owner_id, saved_block.location, saved_block.object_id]
	var reserve_before := {}
	var weapon_before := {}
	for player in state.players:
		reserve_before[player.id] = player.reserve_block_ids.duplicate()
		for weapon in player.weapons:
			weapon_before[weapon.id] = [weapon.structure_block_ids.duplicate(), weapon.ammo_block_id]
	var active_before := [state.active_shot_block_id, state.active_shot_attacker_id, state.active_shot_weapon_id, state.resolving_shot]
	var resolved_before: Dictionary = state.resolved_shot_keys.duplicate()
	for transfer in transfers:
		var block_id: int = transfer.block_id
		var new_owner: int = transfer.get("owner_id", attacker_id)
		var block = state.blocks[block_id]
		block.owner_id = new_owner
		block.location = &"reserve"
		block.object_id = 0
		var destination = state.get_player(new_owner)
		if not destination.reserve_block_ids.has(block_id): destination.reserve_block_ids.append(block_id)
		var weapon = transfer.weapon
		if weapon != null:
			weapon.structure_block_ids.erase(block_id)
			if transfer.ammo and weapon.ammo_block_id == block_id: weapon.ammo_block_id = -1
	state.resolved_shot_keys[shot_key] = true
	state.active_shot_block_id = -1
	state.active_shot_attacker_id = -1
	state.active_shot_weapon_id = -1
	state.resolving_shot = false
	var ledger := state.validate_ledger()
	if not ledger.valid:
		for block_id in block_before:
			var block = state.blocks[block_id]
			block.owner_id = block_before[block_id][0]
			block.location = block_before[block_id][1]
			block.object_id = block_before[block_id][2]
		for player in state.players:
			player.reserve_block_ids.assign(reserve_before[player.id])
			for weapon in player.weapons:
				weapon.structure_block_ids.assign(weapon_before[weapon.id][0])
				weapon.ammo_block_id = weapon_before[weapon.id][1]
		state.active_shot_block_id = active_before[0]
		state.active_shot_attacker_id = active_before[1]
		state.active_shot_weapon_id = active_before[2]
		state.resolving_shot = active_before[3]
		state.resolved_shot_keys = resolved_before
		return {"accepted": false, "applied": false, "reason": "ledger_rejected", "affected": [], "ledger": ledger}
	return {"accepted": true, "applied": true, "reason": "resolved", "affected": affected_block_ids(), "ledger": ledger}
