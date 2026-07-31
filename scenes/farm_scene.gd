extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var walls_container: Node2D = $WallsContainer

# Drag / Scroll settings
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO

# Spacing & Scaling configuration
@export var farm_wall_scale: Vector2 = Vector2(0.35, 0.35)
@export var farm_ground_y: float = 1200.0 # Grass baseline
@export var wall_start_x: float = 50.0 # Horizontal starting point

func _ready() -> void:
	spawn_all_saved_walls()
	update_camera_limits()

## Quick Dev Shortcut: Press 'C' key anywhere on PC build to wipe save!
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_on_dev_clear_save_pressed()

## Reads JSON data from SaveSystem and displays transparent wall PNG images seamlessly end-to-end
func spawn_all_saved_walls() -> void:
	for child in walls_container.get_children():
		child.queue_free()

	var saved_walls: Array = SaveSystem.save_data.get("walls", [])
	if saved_walls.is_empty():
		print("No saved walls found!")
		return

	# Running total of horizontal placement
	var current_x_pos: float = wall_start_x

	for wall_index in range(saved_walls.size()):
		var wall_data: Dictionary = saved_walls[wall_index]
		var image_path: String = wall_data.get("image_path", "")

		if image_path == "" or not FileAccess.file_exists(image_path):
			print("Missing image file at: ", image_path)
			continue

		# Load PNG image
		var img: Image = Image.load_from_file(image_path)
		var texture: ImageTexture = ImageTexture.create_from_image(img)

		# Find bounding box of actual visible stone pixels
		var used_rect: Rect2i = img.get_used_rect()

		# Create Wall Sprite
		var wall_sprite = Sprite2D.new()
		wall_sprite.name = "WallImage_" + str(wall_index)
		wall_sprite.texture = texture
		wall_sprite.scale = farm_wall_scale

		# Anchor to bottom-left corner
		wall_sprite.centered = false
		wall_sprite.offset = Vector2(0, -texture.get_height())

		# Offset position so left-most painted pixel sits at current_x_pos
		var left_padding_offset: float = used_rect.position.x * farm_wall_scale.x
		wall_sprite.position = Vector2(current_x_pos - left_padding_offset, farm_ground_y)

		walls_container.add_child(wall_sprite)

		# Advance current_x_pos strictly by painted stone width
		var visible_stone_width: float = used_rect.size.x * farm_wall_scale.x
		current_x_pos += visible_stone_width

	print("Successfully spawned ", walls_container.get_child_count(), " wall images seamlessly!")

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
	camera.limit_right = int(max(get_viewport_rect().size.x, total_farm_width + 300.0))

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

# --- UI BUTTON SIGNALS ---

## Connect this to a "Clear Save (Dev)" button in UI or options menu
func _on_dev_clear_save_pressed() -> void:
	SaveSystem.wipe_all_save_data()
	spawn_all_saved_walls() # Refreshes farm view to show empty state immediately
	update_camera_limits()  # Resets camera limits for 0 walls

func _on_button_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/control.tscn")
