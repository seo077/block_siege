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

func is_destroyed(blocks: Dictionary, poses: Dictionary) -> bool:
	if structure_block_ids.is_empty():
		return false
	for block_id in structure_block_ids:
		if not blocks.has(block_id) or not poses.has(block_id):
			return false
		var block = blocks[block_id]
		if block == null or not block.is_fallen_at(poses[block_id]):
			return false
	return true
