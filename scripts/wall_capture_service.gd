extends Node

## How many extra pixels of transparent margin to add around the cropped wall image
@export var capture_padding: int = 20

# SubViewport used behind the scenes to render only the stones with a transparent background
var capture_viewport: SubViewport
var capture_root: Node2D

func _ready() -> void:
	_ensure_capture_viewport()


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


func capture_wall_image(stones_array: Array[RigidBody2D], floor_node: Node2D) -> Image:
	_ensure_capture_viewport()

	for child in capture_root.get_children():
		child.queue_free()

	# 1. READ TOP SURFACE EDGE OF THE FLOOR SHAPE
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

	# 2. FIND TRUE ROTATED BOUNDARIES OF ALL STONES
	for stone in stones_array:
		if not is_instance_valid(stone):
			continue

		for child in stone.get_children():
			if child is Sprite2D and child.texture != null:
				has_content = true
				
				# Get local sprite rectangle (accounts for centered, frame, and region)
				var local_rect: Rect2 = child.get_rect()
				var xform: Transform2D = child.global_transform

				# Transform all 4 rotated corners into global coordinates
				var corners = [
					xform * local_rect.position,
					xform * Vector2(local_rect.end.x, local_rect.position.y),
					xform * Vector2(local_rect.position.x, local_rect.end.y),
					xform * local_rect.end
				]

				for pt in corners:
					min_x = min(min_x, pt.x)
					max_x = max(max_x, pt.x)
					min_y = min(min_y, pt.y)

	if not has_content:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)

	var padding: int = capture_padding
	var wall_top: float = min_y - padding
	var wall_height: float = (floor_y - min_y) + (padding * 2)

	var wall_bounds: Rect2 = Rect2(
		min_x - padding,
		wall_top,
		(max_x - min_x) + (padding * 2),
		wall_height
	)

	capture_viewport.size = Vector2i(int(ceil(wall_bounds.size.x)), int(ceil(wall_bounds.size.y)))

	# 3. REPLICATE STONES INSIDE THE CAPTURE VIEWPORT
	for stone in stones_array:
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
			
			# Position and rotate relative to the new cropped bounds
			capture_sprite.position = child.global_position - wall_bounds.position
			capture_sprite.rotation = child.global_rotation
			capture_sprite.scale = child.global_scale
			
			capture_root.add_child(capture_sprite)
			capture_sprite.owner = capture_root

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame

	var wall_image: Image = capture_viewport.get_texture().get_image()

	for child in capture_root.get_children():
		child.queue_free()

	return wall_image


func save_wall_to_disk(wall_image: Image) -> void:
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
	else:
		print("Error saving wall PNG: ", err)