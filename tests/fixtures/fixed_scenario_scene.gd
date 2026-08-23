class_name FixedScenarioScene
extends RefCounted

static func assert_scene_binding(main: Node) -> bool:
	if main.match_state == null or main.match_state.total_block_count() != 200:
		return false
	if main.block_bodies.size() != 200:
		return false
	for block_id in main.match_state.blocks:
		var record = main.match_state.blocks[block_id]
		var body = main.body_for_block(block_id)
		if body == null or body.block_id != record.id or body.owner_id != record.owner_id:
			return false
		if body.object_id != record.object_id or body.is_ammo != record.is_ammo:
			return false
	main.sync_body_poses_to_model()
	return true
