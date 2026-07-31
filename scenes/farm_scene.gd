extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var walls_container: Node2D = $WallsContainer

# Drag / Scroll settings
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO

# Spacing & Scaling configuration
@export var base_wall_width: float = 980.0
@export var farm_wall_scale: Vector2 = Vector2(0.35, 0.35) # Scale set to 0.5 as requested!

func _ready() -> void:
	spawn_all_saved_walls()
	update_camera_limits()

## Reads JSON data from SaveSystem and displays wall PNG images
func spawn_all_saved_walls() -> void:
	for child in walls_container.get_children():
		child.queue_free()

	var saved_walls: Array = SaveSystem.save_data.get("walls", [])
	if saved_walls.is_empty():
		return

	# Target baseline on your farm ground
	var farm_ground_y: float = 800.0 # Adjust to match your farm grass
	var scaled_segment_width: float = base_wall_width * farm_wall_scale.x

	for wall_index in range(saved_walls.size()):
		var wall_data: Dictionary = saved_walls[wall_index]
		var image_path: String = wall_data.get("image_path", "")

		if not FileAccess.file_exists(image_path):
			continue

		# Load PNG image directly from user storage
		var img = Image.load_from_file(image_path)
		var texture = ImageTexture.create_from_image(img)

		# Create a single Sprite2D for the entire wall
		var wall_sprite = Sprite2D.new()
		wall_sprite.name = "WallImage_" + str(wall_index)
		wall_sprite.texture = texture

		# Position & Scale
		var x_pos: float = (wall_index * scaled_segment_width) + (scaled_segment_width / 2.0)
		wall_sprite.position = Vector2(x_pos, farm_ground_y)
		
		# Scale set to 0.5
		wall_sprite.scale = farm_wall_scale

		walls_container.add_child(wall_sprite)

	print("Successfully spawned ", saved_walls.size(), " wall images on the farm!")

## Calculates max scroll limit dynamically based on wall count
func update_camera_limits() -> void:
	var saved_walls: Array = SaveSystem.save_data.get("walls", [])
	var active_segments: int = max(1, saved_walls.size())
	var scaled_segment_width: float = base_wall_width * farm_wall_scale.x
	var total_farm_width: float = active_segments * scaled_segment_width
	
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