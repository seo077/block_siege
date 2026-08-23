class_name ResolutionState
extends RefCounted

const MINIMUM_SECONDS := 0.8
const QUIET_SECONDS := 0.6
const TIMEOUT_SECONDS := 8.0
const MAX_LINEAR_SPEED := 0.12
const MAX_ANGULAR_SPEED := 0.2

var shot_block_id: int
var target_block_ids: Array[int] = []
var elapsed := 0.0
var quiet_elapsed := 0.0
var status: StringName = &"resolving"
var error_state: StringName = &""
var retry_available := false

static func begin(p_shot_block_id: int, p_target_block_ids: Array[int]) -> ResolutionState:
	var state := ResolutionState.new()
	state.shot_block_id = p_shot_block_id
	state.target_block_ids.append(p_shot_block_id)
	for block_id in p_target_block_ids:
		if block_id != p_shot_block_id and not state.target_block_ids.has(block_id):
			state.target_block_ids.append(block_id)
	return state

func advance_fixed_tick(delta: float, motions: Dictionary) -> StringName:
	if status != &"resolving":
		return status
	var was_quiet_long_enough := quiet_elapsed + 0.000001 >= QUIET_SECONDS
	elapsed += maxf(delta, 0.0)
	var all_quiet := true
	for block_id in target_block_ids:
		if not motions.has(block_id) or not _motion_is_quiet(motions[block_id]):
			all_quiet = false
			break
	if elapsed <= MINIMUM_SECONDS or not all_quiet:
		quiet_elapsed = 0.0
	elif was_quiet_long_enough:
		status = &"resolved"
		return status
	else:
		quiet_elapsed += maxf(delta, 0.0)
	if elapsed + 0.000001 >= TIMEOUT_SECONDS:
		status = &"timeout"
		error_state = &"resolution_timeout"
		retry_available = true
	return status

func retry() -> void:
	elapsed = 0.0
	quiet_elapsed = 0.0
	status = &"resolving"
	error_state = &""
	retry_available = false

func _motion_is_quiet(motion: Variant) -> bool:
	if not motion is Dictionary:
		return false
	var linear: Variant = motion.get("linear_velocity", motion.get("linear", INF))
	var angular: Variant = motion.get("angular_velocity", motion.get("angular", INF))
	return _speed(linear) <= MAX_LINEAR_SPEED and _speed(angular) <= MAX_ANGULAR_SPEED

func _speed(value: Variant) -> float:
	if value is Vector3:
		return value.length()
	if value is Vector2:
		return value.length()
	if value is float or value is int:
		return absf(float(value))
	return INF
