class_name MatchState
extends RefCounted

const BlockRecord = preload("res://scripts/core/block_record.gd")
const WeaponState = preload("res://scripts/core/weapon_state.gd")
const PlayerState = preload("res://scripts/core/player_state.gd")

const FORTRESS_BLOCK_COUNT := 6
const CATAPULT_BLOCK_COUNT := 3
const TANK_BLOCK_COUNT := 2
const RESERVE_BLOCK_COUNT := 87

var players: Array[PlayerState]
var blocks: Dictionary
var active_player_id: int
var resolving_shot := false
var combat_input_locked := false

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
	return match_state

func can_accept_combat_input() -> bool:
	return not combat_input_locked and not resolving_shot and active_player_id >= 0

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
	return {"accepted": true, "block_id": block_id, "player_id": player_id, "weapon_id": weapon_id, "drag": drag}

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
			claimed[block_id] = true
			if not blocks.has(block_id):
				errors.append("block %d is missing" % block_id)
			elif (blocks[block_id] as BlockRecord).owner_id != player.id:
				errors.append("block %d has the wrong owner" % block_id)
	for block_id in blocks:
		if not claimed.has(block_id):
			errors.append("block %d is unclaimed" % block_id)
	return {"valid": errors.is_empty(), "errors": errors, "block_count": blocks.size()}
