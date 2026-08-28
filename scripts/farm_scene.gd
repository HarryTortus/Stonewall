extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var walls_container: Node2D = $WallsContainer
@onready var sheep_container: Node2D = $SheepContainer
@onready var sheep_spawner: Node2D = $SheepSpawner
@onready var name_popup: CanvasLayer = get_node_or_null("NameSheepPopup")

# Drag / Scroll settings
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO

# Spacing & Scaling configuration
@export var farm_wall_scale: Vector2 = Vector2(0.35, 0.35)
@export var farm_ground_y: float = 1200.0 # Grass baseline
@export var wall_start_x: float = 50.0   # Horizontal starting point
@export var farm_end_padding: float = 300.0 # Extra right-side pasture room


func _ready() -> void:
	# 1. Listen for when SheepSpawner detects a newly unlocked sheep
	if is_instance_valid(sheep_spawner):
		sheep_spawner.request_name_popup.connect(_on_sheep_spawner_request_name_popup)

	# 2. Spawn farm walls, update bounds, and spawn sheep
	spawn_all_saved_walls()
	update_camera_limits()
	spawn_farm_sheep()


## Called automatically when SheepSpawner signals that a new sheep needs a name
func _on_sheep_spawner_request_name_popup(new_sheep_ids: Array) -> void:
	if is_instance_valid(name_popup):
		if name_popup.has_method("open_for_sheep_queue"):
			name_popup.open_for_sheep_queue(new_sheep_ids)
		elif name_popup.has_method("open_for_sheep") and not new_sheep_ids.is_empty():
			name_popup.open_for_sheep(new_sheep_ids[0])


## Reads JSON data from SaveSystem and displays transparent wall PNG images seamlessly end-to-end
func spawn_all_saved_walls() -> void:
	for child in walls_container.get_children():
		child.queue_free()

	var saved_walls: Array = SaveSystem.save_data.get("walls", [])
	if saved_walls.is_empty():
		print("No saved walls found!")
		return

	var current_x_pos: float = wall_start_x

	for wall_index in range(saved_walls.size()):
		var wall_data: Dictionary = saved_walls[wall_index]
		var image_path: String = wall_data.get("image_path", "")

		if image_path == "" or not FileAccess.file_exists(image_path):
			print("Missing image file at: ", image_path)
			continue

		var img: Image = Image.load_from_file(image_path)
		var texture: ImageTexture = ImageTexture.create_from_image(img)
		var used_rect: Rect2i = img.get_used_rect()

		var wall_sprite = Sprite2D.new()
		wall_sprite.name = "WallImage_" + str(wall_index)
		wall_sprite.texture = texture
		wall_sprite.scale = farm_wall_scale
		wall_sprite.centered = false
		wall_sprite.offset = Vector2(0, -texture.get_height())

		var left_padding_offset: float = used_rect.position.x * farm_wall_scale.x
		wall_sprite.position = Vector2(current_x_pos - left_padding_offset, farm_ground_y)

		walls_container.add_child(wall_sprite)

		var visible_stone_width: float = used_rect.size.x * farm_wall_scale.x
		current_x_pos += visible_stone_width

	print("Successfully spawned ", walls_container.get_child_count(), " wall images seamlessly!")


## Spawns the appropriate amount of sheep into the pasture
func spawn_farm_sheep() -> void:
	if not is_instance_valid(sheep_container) or not is_instance_valid(sheep_spawner):
		return

	for child in sheep_container.get_children():
		child.queue_free()

	var saved_walls: Array = SaveSystem.save_data.get("walls", [])
	sheep_spawner.populate_sheep(sheep_container, saved_walls.size(), float(camera.limit_right))


## Calculates max scroll limit dynamically based on total width of all visible walls
func update_camera_limits() -> void:
	var total_farm_width: float = wall_start_x
	
	for child in walls_container.get_children():
		if child is Sprite2D and child.texture != null:
			var img: Image = child.texture.get_image()
			if img != null:
				var used_rect: Rect2i = img.get_used_rect()
				total_farm_width += used_rect.size.x * child.scale.x
			else:
				total_farm_width += child.texture.get_width() * child.scale.x
	
	camera.limit_left = 0
	# Add pasture end padding so sheep and camera aren't cut off at the final wall
	var min_screen_width: float = get_viewport_rect().size.x
	camera.limit_right = int(max(min_screen_width, total_farm_width + farm_end_padding))


## Smooth Touch / Mouse Drag Scrolling
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			drag_start_pos = event.position
				
	elif event is InputEventScreenTouch:
		is_dragging = event.pressed
		drag_start_pos = event.position

	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and is_dragging:
		var drag_delta: Vector2 = event.position - drag_start_pos
		drag_start_pos = event.position
		
		camera.position.x -= drag_delta.x
		camera.position.x = clamp(
			camera.position.x, 
			camera.limit_left, 
			max(camera.limit_left, camera.limit_right - get_viewport_rect().size.x)
		)


func _on_dev_clear_save_pressed() -> void:
	SaveSystem.wipe_all_save_data()
	spawn_all_saved_walls()
	update_camera_limits()
	spawn_farm_sheep()


func _on_button_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/control.tscn")
