extends Node3D

const SiegeBlock = preload("res://scripts/siege_block.gd")
const MatchState = preload("res://scripts/core/match_state.gd")
const ResolutionState = preload("res://scripts/core/resolution_state.gd")
const FIELD_SIZE := Vector2(60.0, 30.0)
const ZONE_SIZE := Vector2(10.0, 10.0)
const MAX_ROUNDS := 20
const PLAYER_COLORS := [Color("55a8ff"), Color("ff665c")]
const PROJECTILE_COLORS := [Color("b9dcff"), Color("ffd0cc")]

var active_player := 0
var round_number := 1
var selected_weapon := 0
var drag_start := Vector2.ZERO
var dragging := false
var resolving_shot := false
var resolve_elapsed := 0.0
var quiet_elapsed := 0.0
var next_object_id := 1
var reserve := [87, 87]
var fortress_blocks := [[], []]
var weapon_blocks := [[], []]
var weapon_loaded := [[true, true], [true, true]]
var weapon_fired_this_turn := [[false, false], [false, false]]

var camera: Camera3D
var status_label: Label
var hint_label: Label
var debug_label: Label
var trajectory: MeshInstance3D
var match_state: MatchState
var block_bodies: Dictionary = {}
var resolution_state: ResolutionState
var resolution_error: StringName = &""
var resolution_retry_available := false
var interaction_enabled := true

func _ready() -> void:
	create_environment()
	create_field()
	create_match()
	create_ui()
	set_camera_for_player(active_player)
	await get_tree().create_timer(0.8).timeout
	capture_all_baselines()
	_sync_scene_mirrors()
	update_ui("플레이어 1의 턴")

func create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("15202a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dbe7f3")
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 55.0
	add_child(camera)

func create_field() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Field"
	add_child(floor_body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(FIELD_SIZE.x, 0.2, FIELD_SIZE.y)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263b35")
	material.roughness = 0.9
	mesh_instance.material_override = material
	floor_body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -0.1

	create_zone(Vector3(-25.0, 0.012, 0.0), PLAYER_COLORS[0])
	create_zone(Vector3(25.0, 0.012, 0.0), PLAYER_COLORS[1])

func create_zone(position: Vector3, color: Color) -> void:
	var zone := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = ZONE_SIZE
	zone.mesh = plane
	var material := StandardMaterial3D.new()
	var zone_color := color
	zone_color.a = 0.22
	material.albedo_color = zone_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone.material_override = material
	zone.position = position
	add_child(zone)

func create_armies() -> void:
	for player in 2:
		var direction := 1.0 if player == 0 else -1.0
		var home_x := -25.0 if player == 0 else 25.0
		create_fortress(player, Vector3(home_x - direction * 2.5, 0.0, 0.0))
		create_weapon(player, 0, Vector3(home_x + direction * 1.5, 0.0, -2.0), direction)
		create_weapon(player, 1, Vector3(home_x + direction * 1.5, 0.0, 2.0), direction)

func create_match(p_player_ids: Array[int] = [1, 2]) -> void:
	match_state = MatchState.create_fixed_scenario(p_player_ids)
	spawn_match_bodies(match_state)

func spawn_match_bodies(state: MatchState) -> void:
	for body in block_bodies.values():
		if is_instance_valid(body):
			body.queue_free()
	block_bodies.clear()
	fortress_blocks.clear()
	weapon_blocks.clear()
	reserve.clear()
	weapon_loaded.clear()
	weapon_fired_this_turn.clear()
	for player_index in state.players.size():
		var player = state.players[player_index]
		var color: Color = PLAYER_COLORS[player_index % PLAYER_COLORS.size()]
		var direction := 1.0 if player_index % 2 == 0 else -1.0
		var home_x: float = -25.0 + 50.0 * player_index / maxi(1, state.players.size() - 1)
		var player_fortress: Array = []
		var player_weapons: Array = []
		reserve.append(player.reserve_block_ids.size())
		weapon_loaded.append([])
		weapon_fired_this_turn.append([])
		for index in player.fortress_block_ids.size():
			var block := _spawn_record(state.blocks[player.fortress_block_ids[index]], color, false)
			var level: int = index / 2
			var column: int = index % 2
			block.position = Vector3(home_x - direction * 2.5, 0.11 + level * 0.21, (column - 0.5) * 0.42)
			if level % 2 == 1:
				block.rotation.y = PI * 0.5
			player_fortress.append(block)
		for weapon_index in player.weapons.size():
			var weapon = player.weapons[weapon_index]
			var weapon_bodies: Array = []
			var origin := Vector3(home_x + direction * 1.5, 0.0, -2.0 if weapon_index == 0 else 2.0)
			for index in weapon.structure_block_ids.size():
				var block := _spawn_record(state.blocks[weapon.structure_block_ids[index]], color, false)
				block.position = origin + Vector3(0, 0.11, -0.22 + index * 0.44)
				if index >= 2:
					block.position = origin + Vector3(0, 0.32, 0)
					block.rotation.z = direction * deg_to_rad(8)
				weapon_bodies.append(block)
			var ammo := _spawn_record(state.blocks[weapon.ammo_block_id], color.lightened(0.35), true)
			ammo.position = origin + Vector3(direction * 0.35, 0.45, 0)
			player_weapons.append(weapon_bodies)
			weapon_loaded[player_index].append(true)
			weapon_fired_this_turn[player_index].append(false)
		fortress_blocks.append(player_fortress)
		weapon_blocks.append(player_weapons)
		for reserve_index in player.reserve_block_ids.size():
			var reserve_body := _spawn_record(state.blocks[player.reserve_block_ids[reserve_index]], color, true)
			reserve_body.visible = false
			reserve_body.position = Vector3(home_x, -10.0, reserve_index * 0.4)

func _spawn_record(record: BlockRecord, color: Color, frozen_block: bool) -> SiegeBlock:
	var block := SiegeBlock.new()
	block.setup(record.id, record.owner_id, record.object_id, color, frozen_block, record.is_ammo)
	block.apply_record(record)
	add_child(block)
	block_bodies[record.id] = block
	return block

func body_for_block(block_id: int) -> SiegeBlock:
	return block_bodies.get(block_id) as SiegeBlock

func sync_body_poses_to_model() -> void:
	for block_id in block_bodies:
		var body := block_bodies[block_id] as SiegeBlock
		if is_instance_valid(body):
			body.apply_record(match_state.blocks[block_id])
			body.capture_baseline()

func create_fortress(player: int, origin: Vector3) -> void:
	var object_id := allocate_object_id()
	for level in 3:
		for column in 2:
			var block := make_block(player, object_id, PLAYER_COLORS[player])
			block.position = origin + Vector3(0.0, 0.11 + level * 0.21, (column - 0.5) * 0.42)
			if level % 2 == 1:
				block.rotation.y = PI * 0.5
			fortress_blocks[player].append(block)

func create_weapon(player: int, weapon_index: int, origin: Vector3, direction: float) -> void:
	var object_id := allocate_object_id()
	var blocks: Array = []
	var base_a := make_block(player, object_id, PLAYER_COLORS[player].darkened(0.08))
	base_a.position = origin + Vector3(0, 0.11, -0.22)
	blocks.append(base_a)
	var base_b := make_block(player, object_id, PLAYER_COLORS[player].darkened(0.08))
	base_b.position = origin + Vector3(0, 0.11, 0.22)
	blocks.append(base_b)
	if weapon_index == 0:
		var lever := make_block(player, object_id, PLAYER_COLORS[player].lightened(0.1))
		lever.position = origin + Vector3(0, 0.32, 0)
		lever.rotation.z = direction * deg_to_rad(8)
		blocks.append(lever)
	weapon_blocks[player].append(blocks)

func make_block(player: int, object_id: int, color: Color) -> SiegeBlock:
	var block := SiegeBlock.new()
	block.setup(-1, player, object_id, color)
	add_child(block)
	return block

func allocate_object_id() -> int:
	var result := next_object_id
	next_object_id += 1
	return result

func create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.03, 0.04, 0.84)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(430, 150)
	layer.add_child(panel)

	status_label = Label.new()
	status_label.position = Vector2(34, 30)
	status_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(status_label)

	hint_label = Label.new()
	hint_label.position = Vector2(34, 70)
	hint_label.text = "[1] 투석기  [2] 전차  |  마우스 드래그: 발사\n전차 선택 중 WASD: 이동  |  [Enter]: 턴 종료"
	layer.add_child(hint_label)

	debug_label = Label.new()
	debug_label.position = Vector2(34, 122)
	layer.add_child(debug_label)

func _unhandled_input(event: InputEvent) -> void:
	if not interaction_enabled or current_adjudication_state() != &"ready":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			selected_weapon = 0
			update_ui("투석기 선택")
		elif event.keycode == KEY_2:
			selected_weapon = 1
			update_ui("전차 선택")
		elif event.keycode == KEY_ENTER:
			end_turn()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_start = event.position
			dragging = true
		else:
			if dragging:
				fire_selected(event.position - drag_start)
			dragging = false

func _physics_process(delta: float) -> void:
	if not resolving_shot:
		handle_tank_movement(delta)
		return
	advance_resolution(delta)

func collect_resolution_motion() -> Dictionary:
	var motions: Dictionary = {}
	if resolution_state == null:
		return motions
	for block_id in resolution_state.target_block_ids:
		var body := body_for_block(block_id)
		if body != null and is_instance_valid(body):
			motions[block_id] = {"linear_velocity": body.linear_velocity, "angular_velocity": body.angular_velocity}
	return motions

func collect_resolution_poses() -> Dictionary:
	var poses: Dictionary = {}
	if resolution_state == null:
		return poses
	for block_id in resolution_state.target_block_ids:
		var body := body_for_block(block_id)
		if body != null and is_instance_valid(body):
			poses[block_id] = body.global_transform if body.is_inside_tree() else body.transform
	return poses

func freeze_timeout_bodies() -> void:
	if resolution_state == null:
		return
	for block_id in resolution_state.target_block_ids:
		var body := body_for_block(block_id)
		if body != null and is_instance_valid(body):
			body.freeze = true

func advance_resolution(delta: float) -> void:
	if resolution_state == null:
		return
	var result := resolution_state.advance_fixed_tick(delta, collect_resolution_motion())
	resolve_elapsed = resolution_state.elapsed
	quiet_elapsed = resolution_state.quiet_elapsed
	if result == &"resolved":
		finish_shot_resolution()
	elif result == &"timeout":
		match_state.enter_timeout(collect_resolution_poses(), collect_resolution_motion())
		freeze_timeout_bodies()
		resolving_shot = false
		resolution_error = resolution_state.error_state
		resolution_retry_available = resolution_state.retry_available
		set_interaction_enabled(false)
		update_ui("Resolution timed out; retry available")

func retry_resolution() -> bool:
	if resolution_state == null or not resolution_state.retry_available:
		return false
	var restored := match_state.retry_timed_out_shot()
	if restored.is_empty():
		return false
	var poses: Dictionary = restored.poses
	var motions: Dictionary = restored.motions
	for block_id in resolution_state.target_block_ids:
		var body := body_for_block(block_id)
		if body == null or not is_instance_valid(body): continue
		if poses.has(block_id):
			body.global_transform = poses[block_id] if body.is_inside_tree() else poses[block_id]
		body.freeze = false
		if motions.has(block_id):
			body.linear_velocity = motions[block_id].get("linear_velocity", motions[block_id].get("linear", Vector3.ZERO))
			body.angular_velocity = motions[block_id].get("angular_velocity", motions[block_id].get("angular", Vector3.ZERO))
	resolution_state.retry()
	resolution_error = &""
	resolution_retry_available = false
	resolving_shot = true
	set_interaction_enabled(false)
	return true

func handle_tank_movement(delta: float) -> void:
	if not interaction_enabled or match_state == null or not match_state.can_accept_combat_input():
		return
	if selected_weapon != 1:
		return
	var input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	).normalized()
	if input.length_squared() == 0:
		return
	var blocks: Array = weapon_blocks[active_player][1]
	var motion := Vector3(input.y, 0, input.x) * delta * 2.5
	for block in blocks:
		if is_instance_valid(block):
			block.position += motion

func fire_selected(drag: Vector2) -> void:
	var player = match_state.players[active_player]
	fire_weapon(player.id, player.weapons[selected_weapon].id, drag)
	return


func fire_weapon(player_id: int, weapon_id: int, drag: Vector2) -> bool:
	if match_state == null:
		return false
	var player_index := -1
	for index in match_state.players.size():
		if match_state.players[index].id == player_id:
			player_index = index
			break
	if player_index < 0 or player_index >= weapon_blocks.size():
		return false
	var weapon = match_state.players[player_index].find_weapon(weapon_id)
	if weapon == null:
		return false
	var weapon_index := match_state.players[player_index].weapons.find(weapon)
	if weapon_index < 0 or weapon_index >= weapon_blocks[player_index].size():
		return false
	var blocks: Array = weapon_blocks[player_index][weapon_index]
	if blocks.is_empty() or not is_instance_valid(blocks[0]):
		return false
	var loaded_block_id: int = weapon.ammo_block_id
	if loaded_block_id < 0 or body_for_block(loaded_block_id) == null:
		return false
	var result := match_state.request_fire(player_id, weapon_id, drag)
	if not result.accepted:
		return false
	var origin := Vector3.ZERO
	for block in blocks:
		origin += block.global_position if block.is_inside_tree() else block.position
	origin /= blocks.size()
	var forward := 1.0 if player_index == 0 else -1.0
	var lateral := clampf(drag.x / 280.0, -0.7, 0.7)
	var power := clampf(drag.length() / 110.0, 0.8, 3.2)
	var elevation := 0.72 if weapon_index == 0 else 0.16
	var direction := Vector3(forward, elevation - drag.y / 900.0, lateral).normalized()
	var projectile := spawn_projectile(result.block_id, origin + Vector3(forward * 0.8, 0.55, 0), direction * power * (7.2 if weapon_index == 0 else 5.8))
	if projectile == null:
		return false
	weapon_loaded[player_index][weapon_index] = false
	weapon_fired_this_turn[player_index][weapon_index] = true
	resolving_shot = true
	resolve_elapsed = 0.0
	quiet_elapsed = 0.0
	var target_ids: Array[int] = []
	for block_id in match_state.blocks:
		var record = match_state.blocks[block_id]
		if record.location == &"fortress" or (record.location == &"weapon" and not record.is_ammo):
			target_ids.append(block_id)
	resolution_state = ResolutionState.begin(result.block_id, target_ids)
	resolution_error = &""
	resolution_retry_available = false
	set_interaction_enabled(false)
	return true


func spawn_projectile(block_id: int, origin: Vector3, impulse: Vector3) -> SiegeBlock:
	var projectile := body_for_block(block_id)
	if projectile == null:
		return null
	projectile.freeze = false
	projectile.visible = true
	if projectile.is_inside_tree():
		projectile.global_position = origin
	else:
		projectile.position = origin
	projectile.linear_velocity = Vector3.ZERO
	projectile.angular_velocity = Vector3.ZERO
	projectile.add_to_group("projectile")
	projectile.apply_central_impulse(impulse)
	return projectile


func _legacy_fire_selected(drag: Vector2) -> void:
	if drag.length() < 12.0:
		update_ui("드래그가 너무 짧습니다")
		return
	if weapon_fired_this_turn[active_player][selected_weapon]:
		update_ui("이 병기는 이번 턴에 이미 발사했습니다")
		return
	if not weapon_loaded[active_player][selected_weapon]:
		update_ui("이 병기는 장전되지 않았습니다")
		return
	var blocks: Array = weapon_blocks[active_player][selected_weapon]
	if blocks.is_empty() or not is_instance_valid(blocks[0]):
		return
	var origin := Vector3.ZERO
	for block in blocks:
		origin += block.global_position
	origin /= blocks.size()
	var forward := 1.0 if active_player == 0 else -1.0
	var lateral := clampf(drag.x / 280.0, -0.7, 0.7)
	var power := clampf(drag.length() / 110.0, 0.8, 3.2)
	var elevation := 0.72 if selected_weapon == 0 else 0.16
	var direction := Vector3(forward, elevation - drag.y / 900.0, lateral).normalized()

	var projectile := SiegeBlock.new()
	projectile.setup(-1, active_player, -1, PROJECTILE_COLORS[active_player], false, true)
	projectile.add_to_group("projectile")
	add_child(projectile)
	projectile.global_position = origin + Vector3(forward * 0.8, 0.55, 0)
	projectile.apply_central_impulse(direction * power * (7.2 if selected_weapon == 0 else 5.8))
	weapon_loaded[active_player][selected_weapon] = false
	weapon_fired_this_turn[active_player][selected_weapon] = true
	resolving_shot = true
	resolve_elapsed = 0.0
	quiet_elapsed = 0.0
	update_ui("물리 판정 중…")

func finish_shot_resolution() -> void:
	if match_state == null or resolution_state == null or resolution_state.status != &"resolved":
		return
	var poses: Dictionary = collect_resolution_poses()
	var attacker_id: int = match_state.active_player_id
	var model_result := match_state.resolve_shot_once(poses)
	if not model_result.get("applied", false):
		return
	apply_resolution_result(model_result)
	match_state.adjudicate_fortress_victory(attacker_id, poses)
	resolving_shot = false
	resolution_state = null
	_sync_scene_mirrors()
	set_interaction_enabled(not match_state.match_result.final)
	if match_state.match_result.final:
		show_result(_result_message(match_state.match_result))
		return
	update_ui("발사 판정 완료")

func apply_resolution_result(result: Dictionary) -> void:
	if not result.get("applied", false):
		return
	var affected: Array[int] = []
	affected.assign(result.get("affected", []))
	remove_transferred_bodies(affected)

func remove_transferred_bodies(block_ids: Array[int]) -> void:
	for block_id in block_ids:
		var body := body_for_block(block_id)
		block_bodies.erase(block_id)
		if body == null or not is_instance_valid(body):
			continue
		body.remove_from_group("projectile")
		for player_index in fortress_blocks.size():
			fortress_blocks[player_index].erase(body)
			for weapon_index in weapon_blocks[player_index].size():
				weapon_blocks[player_index][weapon_index].erase(body)
		body.visible = false
		body.queue_free()

func check_victory() -> void:
	for player in 2:
		var blocks: Array = fortress_blocks[player]
		if not blocks.is_empty() and blocks.all(func(block): return not is_instance_valid(block) or block.is_fallen()):
			show_result("플레이어 %d 승리 — 요새 완파" % (2 if player == 0 else 1))

func end_turn() -> void:
	if match_state == null or current_adjudication_state() != &"ready":
		return
	var turn_result := match_state.request_end_turn(match_state.active_player_id)
	if not turn_result.get("accepted", false):
		return
	_sync_scene_mirrors()
	if match_state.match_result.final:
		set_interaction_enabled(false)
		show_result(_result_message(match_state.match_result))
		return
	set_camera_for_player(active_player)
	update_ui("턴 전환")

func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		dragging = false

func current_adjudication_state() -> StringName:
	if match_state != null and match_state.match_result.get("final", false):
		return &"final"
	if resolution_state != null and resolution_state.status == &"timeout":
		return &"timeout"
	if match_state != null and (match_state.resolving_shot or resolving_shot):
		return &"resolving"
	return &"ready"

func _sync_scene_mirrors() -> void:
	if match_state == null:
		return
	round_number = match_state.round_number
	active_player = 0
	for index in match_state.players.size():
		if match_state.players[index].id == match_state.active_player_id:
			active_player = index
	reserve.clear()
	weapon_loaded.clear()
	weapon_fired_this_turn.clear()
	for player in match_state.players:
		reserve.append(player.reserve_block_ids.size())
		var loaded: Array = []
		var fired: Array = []
		for weapon in player.weapons:
			loaded.append(weapon.ammo_block_id >= 0)
			fired.append(weapon.fired_this_turn)
		weapon_loaded.append(loaded)
		weapon_fired_this_turn.append(fired)

func _result_message(result: Dictionary) -> String:
	if result.get("outcome", &"") == &"draw":
		return "Draw"
	var winners: Array = result.get("winner_ids", [])
	return "Player %s wins" % (str(winners[0]) if not winners.is_empty() else "?")

func resolve_round_limit() -> void:
	var totals := [owned_block_total(0), owned_block_total(1)]
	if totals[0] != totals[1]:
		show_result("플레이어 %d 판정승" % (1 if totals[0] > totals[1] else 2))
		return
	var fortress_count := [count_valid(fortress_blocks[0]), count_valid(fortress_blocks[1])]
	if fortress_count[0] != fortress_count[1]:
		show_result("플레이어 %d 판정승" % (1 if fortress_count[0] > fortress_count[1] else 2))
	else:
		show_result("무승부")

func count_valid(blocks: Array) -> int:
	var count := 0
	for block in blocks:
		if is_instance_valid(block):
			count += 1
	return count

func owned_block_total(player: int) -> int:
	var total: int = reserve[player] + count_valid(fortress_blocks[player])
	for weapon_index in 2:
		total += count_valid(weapon_blocks[player][weapon_index])
		if weapon_loaded[player][weapon_index]:
			total += 1
	return total

func capture_all_baselines() -> void:
	for block_id in block_bodies:
		var body := body_for_block(block_id)
		var record = match_state.blocks.get(block_id) if match_state != null else null
		if body != null and record != null and record.location != &"reserve":
			body.capture_baseline()

func set_camera_for_player(player: int) -> void:
	var x := -9.0 if player == 0 else 9.0
	camera.position = Vector3(x, 25.0, 25.0)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)

func update_ui(message: String) -> void:
	if status_label == null:
		return
	status_label.text = "라운드 %d/%d  |  플레이어 %d  |  %s" % [round_number, MAX_ROUNDS, active_player + 1, "투석기" if selected_weapon == 0 else "전차"]
	debug_label.text = "예비 블럭 P1: %d  P2: %d  |  %s" % [reserve[0], reserve[1], message]

func show_result(message: String) -> void:
	set_process_unhandled_input(false)
	set_physics_process(false)
	status_label.text = message
	debug_label.text = "프로토타입 종료"
