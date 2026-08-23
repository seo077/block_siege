class_name SiegeBlock
extends RigidBody3D

const FALL_ANGLE_DEGREES := 30.0
const BLOCK_SIZE := Vector3(1.0, 0.2, 0.33)

var owner_id: int
var block_id: int
var object_id: int
var is_ammo := false
var baseline_transform: Transform3D
var baseline_ready := false

func setup(p_block_id: int, p_owner_id: int, p_object_id: int, color: Color, frozen_block: bool = false, p_is_ammo: bool = false) -> void:
	block_id = p_block_id
	owner_id = p_owner_id
	object_id = p_object_id
	is_ammo = p_is_ammo
	mass = 1.0
	freeze = frozen_block
	contact_monitor = true
	max_contacts_reported = 8

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BLOCK_SIZE
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = BLOCK_SIZE
	collision.shape = shape
	add_child(collision)

func apply_record(record: BlockRecord) -> void:
	block_id = record.id
	owner_id = record.owner_id
	object_id = record.object_id
	is_ammo = record.is_ammo

func capture_baseline() -> void:
	baseline_transform = global_transform if is_inside_tree() else transform
	baseline_ready = true

func is_fallen() -> bool:
	if not baseline_ready:
		return false
	var displacement := global_position.distance_to(baseline_transform.origin)
	var rotation_delta := baseline_transform.basis.inverse() * global_basis
	var angle_degrees := rad_to_deg(rotation_delta.get_rotation_quaternion().get_angle())
	return displacement >= BLOCK_SIZE.y * 0.5 or angle_degrees >= FALL_ANGLE_DEGREES
