class_name BlockRecord
extends RefCounted

var id: int
var owner_id: int
var location: StringName
var object_id: int
var is_ammo: bool

static func create(p_id: int, p_owner_id: int, p_location: StringName, p_object_id: int, p_is_ammo: bool = false) -> BlockRecord:
	var block = BlockRecord.new()
	block.id = p_id
	block.owner_id = p_owner_id
	block.location = p_location
	block.object_id = p_object_id
	block.is_ammo = p_is_ammo
	return block
