class_name PlayerState
extends RefCounted

const WeaponState = preload("res://scripts/core/weapon_state.gd")

var id: int
var reserve_block_ids: Array[int]
var fortress_block_ids: Array[int]
var weapons: Array[WeaponState]
var turn_actions := {
	"shots_fired": 0,
	"turn_ended": false,
}

static func create(p_id: int, p_reserve_block_ids: Array[int], p_fortress_block_ids: Array[int], p_weapons: Array[WeaponState]) -> PlayerState:
	var player = PlayerState.new()
	player.id = p_id
	player.reserve_block_ids = p_reserve_block_ids.duplicate()
	player.fortress_block_ids = p_fortress_block_ids.duplicate()
	player.weapons = p_weapons.duplicate()
	return player

func find_weapon(weapon_id: int) -> WeaponState:
	for weapon in weapons:
		if weapon.id == weapon_id:
			return weapon
	return null

func is_fortress_destroyed(blocks: Dictionary, poses: Dictionary) -> bool:
	if fortress_block_ids.is_empty():
		return false
	for block_id in fortress_block_ids:
		if not blocks.has(block_id) or not poses.has(block_id):
			return false
		var block = blocks[block_id]
		if block == null or not block.is_fallen_at(poses[block_id]):
			return false
	return true
