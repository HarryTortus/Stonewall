extends Node2D

# Track input hold states
var move_dir: float = 0.0
var rotate_dir: float = 0.0
var current_stone: RigidBody2D = null

# Speeds for hovering object
@export var move_speed: float = 350.0
@export var rotate_speed: float = 3 # radians per second

# Stone spawning configuration
@export var stone_scenes: Array[PackedScene] = []
@export var global_stone_scale: Vector2 = Vector2(0.5, 0.5)
@export var capture_padding: int = 80

var wall_stones: Array[RigidBody2D] = []
var capture_viewport: SubViewport
var capture_root: Node2D

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
	if stone_scenes.is_empty():
		print("No stone scenes assigned in Inspector!")
		return
		
	# Pick a random stone scene from the array
	var random_stone_scene: PackedScene = stone_scenes.pick_random()
	current_stone = random_stone_scene.instantiate() as RigidBody2D
	
	# 1. Scale child nodes (Sprite2D & Collision)
	for child in current_stone.get_children():
		if child is Sprite2D or child is CollisionPolygon2D or child is CollisionShape2D:
			child.scale = global_stone_scale

	# 2. Add to scene tree FIRST
	add_child(current_stone)
	
	# 3. Position cleanly in top-center AFTER adding to tree
	if current_stone.has_method("setup_spawn"):
		current_stone.setup_spawn()

	# Listen for landing signal
	if current_stone.has_signal("stone_landed"):
		current_stone.stone_landed.connect(_on_stone_landed)

func _on_stone_landed() -> void:
	await get_tree().create_timer(0.3).timeout
	spawn_random_stone()

func _process(delta: float) -> void:
	if is_instance_valid(current_stone) and current_stone.freeze:
		if move_dir != 0.0:
			current_stone.move_hover(move_dir * move_speed * delta)
		if rotate_dir != 0.0:
			current_stone.rotate_hover(rotate_dir * rotate_speed * delta)

# --- LEFT BUTTON ---
func _on_button_left_button_down() -> void:
	move_dir = -1.0

func _on_button_left_button_up() -> void:
	if move_dir == -1.0:
		move_dir = 0.0

# --- RIGHT BUTTON ---
func _on_button_right_button_down() -> void:
	move_dir = 1.0

func _on_button_right_button_up() -> void:
	if move_dir == 1.0:
		move_dir = 0.0

# --- ROTATE LEFT BUTTON ---
func _on_button_rotate_left_button_down() -> void:
	rotate_dir = -1.0

func _on_button_rotate_left_button_up() -> void:
	if rotate_dir == -1.0:
		rotate_dir = 0.0

# --- ROTATE RIGHT BUTTON ---
func _on_button_rotate_right_button_down() -> void:
	rotate_dir = 1.0

func _on_button_rotate_right_button_up() -> void:
	if rotate_dir == 1.0:
		rotate_dir = 0.0

# --- DROP BUTTON ---
func _on_button_drop_pressed() -> void:
	if is_instance_valid(current_stone) and current_stone.freeze:
		move_dir = 0.0
		rotate_dir = 0.0
		if not wall_stones.has(current_stone):
			wall_stones.append(current_stone)
		current_stone.start_falling()

func _on_button_menu_pressed() -> void:
	print("Button was clicked!")
	get_tree().change_scene_to_file("res://scenes/control.tscn")

func _capture_wall_image() -> Image:
	_ensure_capture_viewport()

	for child in capture_root.get_children():
		child.queue_free()

	var wall_bounds: Rect2 = Rect2()
	var has_content: bool = false

	for stone in wall_stones:
		if not is_instance_valid(stone):
			continue

		for child in stone.get_children():
			if child is Sprite2D:
				var sprite_size: Vector2 = Vector2.ZERO
				if child.texture != null:
					sprite_size = Vector2(child.texture.get_width(), child.texture.get_height()) * child.scale
				else:
					continue

				var sprite_bounds: Rect2 = Rect2(child.global_position - (sprite_size * 0.5), sprite_size)
				if not has_content:
					wall_bounds = sprite_bounds
					has_content = true
				else:
					wall_bounds = wall_bounds.merge(sprite_bounds)

	if not has_content:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)

	var padding: int = capture_padding
	var image_size: Vector2i = Vector2i(
		int(ceil(wall_bounds.size.x)) + padding * 2,
		int(ceil(wall_bounds.size.y)) + padding * 2
	)

	capture_viewport.size = image_size

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
			capture_sprite.position = child.global_position - wall_bounds.position + Vector2(padding, padding)
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

# --- PNG SAVE FUNCTION ---
func save_current_wall() -> void:
	var wall_image: Image = await _capture_wall_image()

	# 4. Generate a unique filename based on saved wall count
	var wall_count: int = SaveSystem.save_data.get("walls", []).size()
	var image_filename: String = "user://wall_" + str(wall_count) + ".png"

	# 5. Save the transparent PNG to disk
	var err = wall_image.save_png(image_filename)
	if err == OK:
		print("Saved wall image to: ", image_filename)
		
		# 6. Store file path in JSON save data
		var wall_data = {
			"wall_id": wall_count,
			"image_path": image_filename
		}
		SaveSystem.add_wall(wall_data)

	# Transition to farm scene
	get_tree().change_scene_to_file("res://scenes/farm_scene.tscn")

# --- THE TRIGGER: Button Signal ---
func _on_button_save_wall_pressed() -> void:
	save_current_wall()