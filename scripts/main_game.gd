extends Node2D

# Track input hold states
var move_dir: float = 0.0
var rotate_dir: float = 0.0
var current_stone: RigidBody2D = null

# Speeds for hovering object
@export var move_speed: float = 350.0
@export var rotate_speed: float = 3.0 # radians per second

# Timing configuration
@export var next_spawn_delay: float = 0.8 # Delay before the next hovering stone appears
@export var settle_duration_needed: float = 0.45 # Must be completely still this long before unlocking/checking save

# Settle Thresholds (Higher = ignores tiny micro-vibrations and compression shifts)
@export var movement_velocity_threshold: float = 45.0 # Speed (px/s) required to count as actively falling/sliding
@export var movement_angular_threshold: float = 1.0 # Angular speed (rad/s) required to count as rolling

# Stone spawning configuration
@export var stone_scenes: Array[PackedScene] = []
@export var global_stone_scale: Vector2 = Vector2(0.5, 0.5)
@export var capture_padding: int = 15 # Buffer on all sides for PNG capture

# --- CONTAINER & UI NODE REFERENCES ---
@export var floor_node: Node2D
@export var string_line: Area2D
@export var drop_button: BaseButton # Assign ButtonDrop here in the Inspector!

var wall_stones: Array[RigidBody2D] = []
var capture_viewport: SubViewport
var capture_root: Node2D

var is_saving_wall: bool = false
var is_wall_settled: bool = true
var time_spent_settled: float = 0.0
var is_spawning: bool = false

func _ready() -> void:
	_ensure_capture_viewport()
	spawn_random_stone()


func _ensure_capture_viewport() -> void:
	if is_instance_valid(capture_viewport):
		return

	capture_viewport = SubViewport.new()
	capture_viewport.name = "WallCaptureViewport"
	capture_viewport.transparent_bg = true
	capture_viewport.disable_3d = true
	capture_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.size = Vector2i(get_viewport().size)
	add_child(capture_viewport)

	capture_root = Node2D.new()
	capture_root.name = "WallCaptureRoot"
	capture_viewport.add_child(capture_root)


func spawn_random_stone() -> void:
	if is_saving_wall:
		return

	if stone_scenes.is_empty():
		print("No stone scenes assigned in Inspector!")
		return
		
	var random_stone_scene: PackedScene = stone_scenes.pick_random()
	current_stone = random_stone_scene.instantiate() as RigidBody2D
	
	# 1. Scale child nodes (Sprite2D & Collision)
	for child in current_stone.get_children():
		if child is Sprite2D or child is CollisionPolygon2D or child is CollisionShape2D:
			child.scale = global_stone_scale

	# 2. Add to scene tree
	add_child(current_stone)
	
	# 3. Position cleanly in top-center
	if current_stone.has_method("setup_spawn"):
		current_stone.setup_spawn()


func _process(delta: float) -> void:
	if is_saving_wall:
		return

	# Handle Hover Movement (Smooth per-frame rendering)
	if is_instance_valid(current_stone) and current_stone.freeze:
		if move_dir != 0.0:
			current_stone.move_hover(move_dir * move_speed * delta)
		if rotate_dir != 0.0:
			current_stone.rotate_hover(rotate_dir * rotate_speed * delta)


func _physics_process(delta: float) -> void:
	if is_saving_wall:
		return

	# Check if any stone in the wall is actively moving (filtering out micro-jitters)
	var is_any_stone_moving: bool = false
	for stone in wall_stones:
		if is_instance_valid(stone) and not stone.freeze:
			if stone.linear_velocity.length() > movement_velocity_threshold or abs(stone.angular_velocity) > movement_angular_threshold:
				is_any_stone_moving = true
				break

	if is_any_stone_moving:
		# Reset settle timer if anything is actively tumbling or rolling
		time_spent_settled = 0.0
		is_wall_settled = false
		if is_instance_valid(drop_button):
			drop_button.disabled = true
	else:
		# Accumulate calm time
		time_spent_settled += delta

		# Only declare fully settled once calm long enough
		if time_spent_settled >= settle_duration_needed:
			if not is_wall_settled:
				is_wall_settled = true
				_on_all_stones_settled()

			# Enable button only when settled, not saving, and a stone is ready to drop
			if is_instance_valid(drop_button) and not is_saving_wall:
				var has_hover_stone = is_instance_valid(current_stone) and current_stone.freeze
				drop_button.disabled = not has_hover_stone


## Evaluates the wall state only when everything has completely come to rest
func _on_all_stones_settled() -> void:
	if is_saving_wall or not is_instance_valid(string_line):
		return

	var overlapping_bodies: Array = string_line.get_overlapping_bodies()
	for stone in wall_stones:
		if is_instance_valid(stone) and overlapping_bodies.has(stone):
			is_saving_wall = true
			if is_instance_valid(drop_button):
				drop_button.disabled = true
			print("All stones settled and touching the string line! Saving wall...")
			save_current_wall()
			return


# --- BUTTON INPUTS ---
func _on_button_left_button_down() -> void:
	move_dir = -1.0

func _on_button_left_button_up() -> void:
	if move_dir == -1.0:
		move_dir = 0.0

func _on_button_right_button_down() -> void:
	move_dir = 1.0

func _on_button_right_button_up() -> void:
	if move_dir == 1.0:
		move_dir = 0.0

func _on_button_rotate_left_button_down() -> void:
	rotate_dir = -1.0

func _on_button_rotate_left_button_up() -> void:
	if rotate_dir == -1.0:
		rotate_dir = 0.0

func _on_button_rotate_right_button_down() -> void:
	rotate_dir = 1.0

func _on_button_rotate_right_button_up() -> void:
	if rotate_dir == 1.0:
		rotate_dir = 0.0

func _on_button_drop_pressed() -> void:
	if is_saving_wall or not is_wall_settled or is_spawning:
		return

	if is_instance_valid(current_stone) and current_stone.freeze:
		move_dir = 0.0
		rotate_dir = 0.0
		
		var dropped_stone: RigidBody2D = current_stone
		current_stone = null # Clear hover reference immediately
		
		if not wall_stones.has(dropped_stone):
			wall_stones.append(dropped_stone)
		
		# Release current stone
		dropped_stone.start_falling()
		
		# Reset settle state & disable drop button
		time_spent_settled = 0.0
		is_wall_settled = false
		if is_instance_valid(drop_button):
			drop_button.disabled = true

		# Spawn next hovering stone after the falling delay
		_spawn_next_stone_with_delay(next_spawn_delay)


func _spawn_next_stone_with_delay(delay: float) -> void:
	is_spawning = true
	await get_tree().create_timer(delay).timeout
	is_spawning = false
	
	if not is_saving_wall:
		spawn_random_stone()


func _on_button_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/control.tscn")


# --- VIEWPORT CAPTURE & SAVE ---
func _capture_wall_image() -> Image:
	_ensure_capture_viewport()

	for child in capture_root.get_children():
		child.queue_free()

	# 1. Read top surface edge of the floor shape
	var floor_y: float = 1000.0
	if is_instance_valid(floor_node):
		if floor_node is CollisionShape2D and floor_node.shape is RectangleShape2D:
			var rect_height: float = floor_node.shape.size.y * floor_node.global_scale.y
			floor_y = floor_node.global_position.y - (rect_height * 0.5)
		else:
			floor_y = floor_node.global_position.y

	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = floor_y
	var has_content: bool = false

	# 2. Find top and side bounds
	for stone in wall_stones:
		if not is_instance_valid(stone):
			continue

		for child in stone.get_children():
			if child is Sprite2D and child.texture != null:
				var sprite_size: Vector2 = Vector2(child.texture.get_width(), child.texture.get_height()) * child.scale
				var sprite_top: float = child.global_position.y - (sprite_size.y * 0.5)
				var sprite_left: float = child.global_position.x - (sprite_size.x * 0.5)
				var sprite_right: float = child.global_position.x + (sprite_size.x * 0.5)

				has_content = true
				if sprite_top < min_y:
					min_y = sprite_top
				if sprite_left < min_x:
					min_x = sprite_left
				if sprite_right > max_x:
					max_x = sprite_right

	if not has_content:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)

	# 3. Apply padding
	var padding: int = capture_padding
	var wall_top: float = min_y - padding
	var wall_height: float = (floor_y - min_y) + (padding * 2)

	var wall_bounds: Rect2 = Rect2(
		min_x - padding,
		wall_top,
		(max_x - min_x) + (padding * 2),
		wall_height
	)

	# 4. Render to SubViewport
	capture_viewport.size = Vector2i(int(ceil(wall_bounds.size.x)), int(ceil(wall_bounds.size.y)))

	for stone in wall_stones:
		if not is_instance_valid(stone):
			continue

		for child in stone.get_children():
			if not child is Sprite2D:
				continue

			var capture_sprite: Sprite2D = Sprite2D.new()
			capture_sprite.texture = child.texture
			capture_sprite.offset = child.offset
			capture_sprite.centered = child.centered
			capture_sprite.hframes = child.hframes
			capture_sprite.vframes = child.vframes
			capture_sprite.frame = child.frame
			capture_sprite.region_enabled = child.region_enabled
			capture_sprite.region_rect = child.region_rect
			capture_sprite.position = child.global_position - wall_bounds.position
			capture_sprite.rotation = child.global_rotation
			capture_sprite.scale = child.scale
			capture_root.add_child(capture_sprite)
			capture_sprite.owner = capture_root

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame

	var wall_image: Image = capture_viewport.get_texture().get_image()

	for child in capture_root.get_children():
		child.queue_free()

	return wall_image


func save_current_wall() -> void:
	var wall_image: Image = await _capture_wall_image()

	var wall_count: int = SaveSystem.save_data.get("walls", []).size()
	var image_filename: String = "user://wall_" + str(wall_count) + ".png"

	var err = wall_image.save_png(image_filename)
	if err == OK:
		print("Saved wall image to: ", image_filename)
		
		var wall_data = {
			"wall_id": wall_count,
			"image_path": image_filename
		}
		SaveSystem.add_wall(wall_data)

	get_tree().change_scene_to_file("res://scenes/farm_scene.tscn")