class_name WeaponState
extends RefCounted

var id: int
var owner_id: int
var kind: StringName
var structure_block_ids: Array[int]
var ammo_block_id: int
var fired_this_turn := false

static func create(p_id: int, p_owner_id: int, p_kind: StringName, p_structure_block_ids: Array[int], p_ammo_block_id: int) -> WeaponState:
	var weapon = WeaponState.new()
	weapon.id = p_id
	weapon.owner_id = p_owner_id
	weapon.kind = p_kind
	weapon.structure_block_ids = p_structure_block_ids.duplicate()
	weapon.ammo_block_id = p_ammo_block_id
	return weapon

func can_fire() -> bool:
	return ammo_block_id >= 0 and not fired_this_turn
