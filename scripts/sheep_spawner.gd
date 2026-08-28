extends Node2D

signal request_name_popup(sheep_ids: Array)

@export var sheep_scene: PackedScene
@export var walls_per_sheep: int = 1

@export var min_spawn_x: float = 500.0
@export var min_spawn_y: float = 1600.0
@export var max_spawn_y: float = 2250.0
@export var min_sheep_spacing: float = 140.0
@export var edge_padding_x: float = 140.0
@export var edge_padding_y: float = 60.0


func populate_sheep(container: Node2D, total_walls: int, dynamic_max_x: float) -> void:
	if not sheep_scene or not is_instance_valid(container):
		return

	var target_count: int = total_walls / max(1, walls_per_sheep)
	if target_count <= 0:
		return

	var saved_sheep_list: Array = SaveSystem.save_data.get("sheep", [])
	var newly_added_sheep_ids: Array = []

	# 1. Register new sheep if player earned more walls
	while saved_sheep_list.size() < target_count:
		var new_id = saved_sheep_list.size()
		var temp_sheep = sheep_scene.instantiate() as CharacterBody2D
		
		var random_col: Color = Color.WHITE
		if temp_sheep and temp_sheep.has_method("generate_random_color"):
			random_col = temp_sheep.generate_random_color()
		if temp_sheep:
			temp_sheep.queue_free()

		var new_sheep_entry = {
			"id": new_id,
			"name": "Sheep #" + str(new_id + 1),
			"color": random_col.to_html(false)
		}
		
		SaveSystem.add_sheep(new_sheep_entry)
		saved_sheep_list = SaveSystem.save_data.get("sheep", [])
		newly_added_sheep_ids.append(new_id)

	# 2. Spawn instances
	var effective_max_x: float = max(min_spawn_x + 300.0, dynamic_max_x - 150.0)
	var spawned_positions: Array = []

	for sheep_data in saved_sheep_list:
		var sheep = sheep_scene.instantiate() as CharacterBody2D
		if not sheep:
			continue

		if sheep.has_method("set_bounds"):
			sheep.set_bounds(min_spawn_x, effective_max_x, min_spawn_y, max_spawn_y)

		container.add_child(sheep)

		var spawn_pos = _get_spaced_spawn_position(spawned_positions, effective_max_x)
		spawned_positions.append(spawn_pos)
		
		sheep.position = spawn_pos
		sheep.z_index = int(spawn_pos.y)

		if sheep.has_method("init_sheep"):
			sheep.init_sheep(
				int(sheep_data.get("id", 0)),
				sheep_data.get("name", ""),
				sheep_data.get("color", "ffffff")
			)

		var body_node = sheep.get_node_or_null("Body")
		if body_node:
			body_node.scale.x = 1.0 if randf() > 0.5 else -1.0

	# 3. Request naming popup for newly created sheep
	if not newly_added_sheep_ids.is_empty():
		request_name_popup.emit(newly_added_sheep_ids)


func _get_spaced_spawn_position(existing_positions: Array, current_max_x: float) -> Vector2:
	var best_pos = Vector2.ZERO
	var max_attempts = 25

	var safe_min_x: float = min_spawn_x + edge_padding_x + 20.0
	var safe_max_x: float = max(safe_min_x + 50.0, current_max_x - edge_padding_x - 20.0)
	var safe_min_y: float = min_spawn_y + edge_padding_y + 20.0
	var safe_max_y: float = max(safe_min_y + 50.0, max_spawn_y - edge_padding_y - 20.0)

	for attempt in range(max_attempts):
		var test_x = randf_range(safe_min_x, safe_max_x)
		var test_y = randf_range(safe_min_y, safe_max_y)
		var candidate = Vector2(test_x, test_y)

		var too_close = false
		for pos in existing_positions:
			if candidate.distance_to(pos) < min_sheep_spacing:
				too_close = true
				break

		if not too_close or attempt == max_attempts - 1:
			return candidate

	return best_pos