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
