class_name BlockRecord
extends RefCounted

var id: int
var owner_id: int
var location: StringName
var object_id: int
var is_ammo: bool
var baseline_transform: Transform3D
var baseline_ready := false

const FALL_ANGLE_RADIANS := deg_to_rad(30.0)
const BOUNDARY_EPSILON := 0.000001

static func create(p_id: int, p_owner_id: int, p_location: StringName, p_object_id: int, p_is_ammo: bool = false) -> BlockRecord:
	var block = BlockRecord.new()
	block.id = p_id
	block.owner_id = p_owner_id
	block.location = p_location
	block.object_id = p_object_id
	block.is_ammo = p_is_ammo
	return block

func capture_baseline(p_transform: Transform3D) -> void:
	if baseline_ready:
		return
	baseline_transform = p_transform
	baseline_ready = true

func is_fallen_at(p_transform: Transform3D, short_edge: float = 0.2) -> bool:
	if not baseline_ready or short_edge <= 0.0:
		return false
	var displacement := baseline_transform.origin.distance_to(p_transform.origin)
	var baseline_rotation := baseline_transform.basis.get_rotation_quaternion().normalized()
	var current_rotation := p_transform.basis.get_rotation_quaternion().normalized()
	var quaternion_dot := clampf(absf(baseline_rotation.dot(current_rotation)), 0.0, 1.0)
	var rotation_delta := 2.0 * acos(quaternion_dot)
	return displacement + BOUNDARY_EPSILON >= short_edge * 0.5 \
		or rotation_delta + BOUNDARY_EPSILON >= FALL_ANGLE_RADIANS
