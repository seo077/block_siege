class_name MatchState
extends RefCounted

const BlockRecord = preload("res://scripts/core/block_record.gd")
const WeaponState = preload("res://scripts/core/weapon_state.gd")
const PlayerState = preload("res://scripts/core/player_state.gd")
const ResolutionSnapshot = preload("res://scripts/core/resolution_snapshot.gd")

const FORTRESS_BLOCK_COUNT := 6
const CATAPULT_BLOCK_COUNT := 3
const TANK_BLOCK_COUNT := 2
const RESERVE_BLOCK_COUNT := 87

var players: Array[PlayerState]
var blocks: Dictionary
var active_player_id: int
var round_number := 1
var match_result: Dictionary = {
	"final": false,
	"outcome": &"pending",
	"winner_ids": [],
	"reason": &"",
	"totals": {},
	"fortress_counts": {},
}
var resolving_shot := false
var combat_input_locked := false
var active_shot_block_id := -1
var active_shot_attacker_id := -1
var active_shot_weapon_id := -1
var resolved_shot_keys: Dictionary = {}
var original_block_ids: Array[int] = []
var timeout_snapshot = null
var resolution_timeout_error := false
var _resolution_apply_count := 0

static func create_fixed_scenario(player_ids: Array[int] = [1, 2]) -> MatchState:
	var scenario_players: Array[PlayerState] = []
	var scenario_blocks: Dictionary = {}
	var next_block_id := 1
	var next_object_id := 1
	for player_id in player_ids:
		var fortress_ids: Array[int] = []
		for index in FORTRESS_BLOCK_COUNT:
			fortress_ids.append(next_block_id)
			scenario_blocks[next_block_id] = BlockRecord.create(next_block_id, player_id, &"fortress", next_object_id)
			next_block_id += 1
		next_object_id += 1

		var weapons: Array[WeaponState] = []
		for definition in [[&"catapult", CATAPULT_BLOCK_COUNT], [&"tank", TANK_BLOCK_COUNT]]:
			var structure_ids: Array[int] = []
			for index in definition[1]:
				structure_ids.append(next_block_id)
				scenario_blocks[next_block_id] = BlockRecord.create(next_block_id, player_id, &"weapon", next_object_id)
				next_block_id += 1
			var ammo_id := next_block_id
			scenario_blocks[ammo_id] = BlockRecord.create(ammo_id, player_id, &"weapon", next_object_id, true)
			next_block_id += 1
			weapons.append(WeaponState.create(next_object_id, player_id, definition[0], structure_ids, ammo_id))
			next_object_id += 1

		var reserve_ids: Array[int] = []
		for index in RESERVE_BLOCK_COUNT:
			reserve_ids.append(next_block_id)
			scenario_blocks[next_block_id] = BlockRecord.create(next_block_id, player_id, &"reserve", 0)
			next_block_id += 1
		scenario_players.append(PlayerState.create(player_id, reserve_ids, fortress_ids, weapons))
	return create_from_players(scenario_players, scenario_blocks)

static func create_from_players(p_players: Array[PlayerState], p_blocks: Dictionary) -> MatchState:
	var match_state = MatchState.new()
	match_state.players = p_players.duplicate()
	match_state.blocks = p_blocks.duplicate()
	match_state.active_player_id = p_players[0].id if not p_players.is_empty() else -1
	match_state.original_block_ids.assign(p_blocks.keys())
	match_state.original_block_ids.sort()
	return match_state

func can_accept_combat_input() -> bool:
	return not combat_input_locked and not resolving_shot and active_player_id >= 0 and not match_result.final

func request_end_turn(player_id: int) -> Dictionary:
	var rejected := {"accepted": false, "round": round_number, "active_player_id": active_player_id, "result": result_snapshot()}
	if match_result.final or combat_input_locked or resolving_shot or player_id != active_player_id:
		return rejected
	var player_index := -1
	for index in players.size():
		if players[index].id == player_id:
			player_index = index
			break
	if player_index < 0:
		return rejected
	players[player_index].turn_actions.turn_ended = true
	if player_index + 1 < players.size():
		active_player_id = players[player_index + 1].id
	else:
		if round_number >= 20:
			adjudicate_round_limit()
		else:
			round_number += 1
			active_player_id = players[0].id if not players.is_empty() else -1
	for player in players:
		player.turn_actions.turn_ended = false
	return {"accepted": true, "round": round_number, "active_player_id": active_player_id, "result": result_snapshot()}

func adjudicate_fortress_victory(attacker_id: int, poses: Dictionary) -> Dictionary:
	if match_result.final:
		return result_snapshot()
	if get_player(attacker_id) == null:
		return result_snapshot()
	for player in players:
		if player.id != attacker_id and player.is_fortress_destroyed(blocks, poses):
			_finalize_result(&"victory", [attacker_id], &"fortress", {}, {})
			break
	return result_snapshot()

func adjudicate_round_limit() -> Dictionary:
	if match_result.final:
		return result_snapshot()
	var totals := {}
	var fortress_counts := {}
	for player in players:
		totals[player.id] = 0
		fortress_counts[player.id] = 0
	for value in blocks.values():
		var block := value as BlockRecord
		if totals.has(block.owner_id):
			totals[block.owner_id] += 1
			if block.location == &"fortress":
				fortress_counts[block.owner_id] += 1
	var leaders := _leaders_for(totals, players.map(func(player): return player.id))
	if leaders.size() > 1:
		leaders = _leaders_for(fortress_counts, leaders)
	if leaders.size() == 1:
		_finalize_result(&"victory", leaders, &"round_limit", totals, fortress_counts)
	else:
		_finalize_result(&"draw", [], &"round_limit", totals, fortress_counts)
	return result_snapshot()

func result_snapshot() -> Dictionary:
	return match_result.duplicate(true)

func _leaders_for(scores: Dictionary, candidates: Array) -> Array:
	var leaders: Array = []
	var best := -1
	for player_id in candidates:
		var score: int = scores.get(player_id, 0)
		if score > best:
			best = score
			leaders = [player_id]
		elif score == best:
			leaders.append(player_id)
	return leaders

func _finalize_result(outcome: StringName, winner_ids: Array, reason: StringName, totals: Dictionary, fortress_counts: Dictionary) -> void:
	if match_result.final:
		return
	match_result = {
		"final": true,
		"outcome": outcome,
		"winner_ids": winner_ids.duplicate(),
		"reason": reason,
		"totals": totals.duplicate(),
		"fortress_counts": fortress_counts.duplicate(),
	}
	combat_input_locked = true

func request_fire(player_id: int, weapon_id: int, drag: Vector2) -> Dictionary:
	var rejected := {"accepted": false}
	if not can_accept_combat_input() or player_id != active_player_id or drag.length_squared() <= 0.0:
		return rejected
	var player := get_player(player_id)
	if player == null:
		return rejected
	var weapon := player.find_weapon(weapon_id)
	if weapon == null or not weapon.can_fire():
		return rejected
	var block_id := weapon.ammo_block_id
	weapon.ammo_block_id = -1
	weapon.fired_this_turn = true
	player.turn_actions.shots_fired += 1
	resolving_shot = true
	active_shot_block_id = block_id
	active_shot_attacker_id = player_id
	active_shot_weapon_id = weapon_id
	(blocks[block_id] as BlockRecord).location = &"projectile"
	return {"accepted": true, "block_id": block_id, "player_id": player_id, "weapon_id": weapon_id, "drag": drag}

func resolve_shot_once(poses: Dictionary) -> Dictionary:
	if resolution_timeout_error:
		return {"accepted": false, "applied": false, "reason": "resolution_timeout", "affected": []}
	var transaction = load("res://scripts/core/resolution_transaction.gd").build(self, poses)
	var result: Dictionary = transaction.apply(self)
	if result.get("applied", false):
		_resolution_apply_count += 1
	return result

func enter_timeout(poses: Dictionary, motions: Dictionary) -> void:
	if timeout_snapshot == null:
		timeout_snapshot = ResolutionSnapshot.capture(self, poses, motions)
	resolution_timeout_error = true
	combat_input_locked = true
	resolving_shot = true

func retry_timed_out_shot() -> Dictionary:
	if not resolution_timeout_error or timeout_snapshot == null:
		return {}
	var restored: Dictionary = timeout_snapshot.restore_into(self)
	timeout_snapshot = null
	resolution_timeout_error = false
	combat_input_locked = false
	resolving_shot = true
	return restored

func resolution_apply_count() -> int:
	return _resolution_apply_count

func ownership_snapshot() -> Dictionary:
	var snapshot := {}
	var ids: Array = blocks.keys()
	ids.sort()
	for block_id in ids:
		var block := blocks[block_id] as BlockRecord
		snapshot[block_id] = {"owner_id": block.owner_id, "location": block.location, "object_id": block.object_id}
	return snapshot

func get_player(player_id: int) -> PlayerState:
	for player in players:
		if player.id == player_id:
			return player
	return null

func total_block_count() -> int:
	return blocks.size()

func validate_ledger() -> Dictionary:
	var errors: Array[String] = []
	var claimed: Dictionary = {}
	var duplicate_count := 0
	var player_ids: Dictionary = {}
	for player in players:
		if player_ids.has(player.id):
			errors.append("duplicate player id %d" % player.id)
		player_ids[player.id] = true
		var references: Array[int] = []
		references.append_array(player.reserve_block_ids)
		references.append_array(player.fortress_block_ids)
		for weapon in player.weapons:
			if weapon.owner_id != player.id:
				errors.append("weapon %d has the wrong owner" % weapon.id)
			references.append_array(weapon.structure_block_ids)
			if weapon.ammo_block_id >= 0:
				references.append(weapon.ammo_block_id)
		for block_id in references:
			if claimed.has(block_id):
				errors.append("block %d is referenced more than once" % block_id)
				duplicate_count += 1
			claimed[block_id] = true
			if not blocks.has(block_id):
				errors.append("block %d is missing" % block_id)
			elif (blocks[block_id] as BlockRecord).owner_id != player.id:
				errors.append("block %d has the wrong owner" % block_id)
	if active_shot_block_id >= 0:
		if claimed.has(active_shot_block_id):
			errors.append("projectile %d is referenced more than once" % active_shot_block_id)
			duplicate_count += 1
		claimed[active_shot_block_id] = true
		if not blocks.has(active_shot_block_id):
			errors.append("projectile %d is missing" % active_shot_block_id)
		else:
			var projectile := blocks[active_shot_block_id] as BlockRecord
			if projectile.owner_id != active_shot_attacker_id or projectile.location != &"projectile":
				errors.append("projectile %d has invalid metadata" % active_shot_block_id)
	for block_id in blocks:
		if not claimed.has(block_id):
			errors.append("block %d is unclaimed" % block_id)
	var current_ids: Array[int] = []
	current_ids.assign(blocks.keys())
	current_ids.sort()
	var missing: Array[int] = []
	var unknown: Array[int] = []
	for block_id in original_block_ids:
		if not blocks.has(block_id): missing.append(block_id)
	for block_id in current_ids:
		if not original_block_ids.has(block_id): unknown.append(block_id)
	if not missing.is_empty(): errors.append("missing original block ids")
	if not unknown.is_empty(): errors.append("unknown block ids")
	if blocks.size() != original_block_ids.size(): errors.append("block count changed")
	return {"valid": errors.is_empty(), "errors": errors, "block_count": blocks.size(), "expected_count": original_block_ids.size(), "unique_count": claimed.size(), "missing": missing, "unknown": unknown, "duplicate_count": duplicate_count}
