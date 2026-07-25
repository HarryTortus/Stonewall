extends RigidBody2D

## Signal emitted when the stone hits the floor or another stone after dropping
signal stone_landed

## Distance from the top edge of the screen
@export var top_margin: float = 100.0

## Distance (in pixels) from the screen edges to block movement
@export var side_margin: float = 30.0 

var has_started_falling: bool = false
var has_signaled_landing: bool = false
var original_collision_layer: int = 1
var original_collision_mask: int = 1

func _ready() -> void:
	# Save original collision settings
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	# DISABLE collisions while hovering so it never overlaps walls or launches
	collision_layer = 0
	collision_mask = 0

	# Freeze physics entirely while hovering
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	# Enable contact monitoring for when it eventually drops
	max_contacts_reported = 3
	contact_monitor = true
	body_entered.connect(_on_body_entered)


## Called by main_game AFTER adding to tree
func setup_spawn() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	var half_height: float = 32.0

	if sprite and sprite.texture != null:
		half_height = (sprite.texture.get_size().y * sprite.scale.y) / 2.0

	# Position centered horizontally and top_margin down from top
	position = Vector2(
		viewport_size.x / 2.0,
		top_margin + half_height
	)


## Detects collision with floor or other stones AFTER dropping
func _on_body_entered(_body: Node) -> void:
	if has_started_falling and not has_signaled_landing:
		has_signaled_landing = true
		stone_landed.emit()


## Move horizontally while frozen
func move_hover(amount: float) -> void:
	if freeze:
		position.x += amount
		_clamp_to_screen_bounds()


## Rotate smoothly using transform rotation (no physics solver conflict)
func rotate_hover(amount: float) -> void:
	if freeze:
		global_rotation += amount


## Clamps stone position cleanly within viewport edges
func _clamp_to_screen_bounds() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	var half_width: float = 32.0

	if sprite and sprite.texture != null:
		half_width = (sprite.texture.get_size().x * sprite.scale.x) / 2.0

	var viewport_width: float = get_viewport_rect().size.x
	var min_x: float = side_margin + half_width
	var max_x: float = viewport_width - side_margin - half_width

	if min_x < max_x:
		position.x = clamp(position.x, min_x, max_x)
	else:
		position.x = viewport_width / 2.0


## Release gravity and re-enable physics collisions
func start_falling() -> void:
	has_started_falling = true
	
	# RESTORE collision settings right before falling
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	
	freeze = false
	gravity_scale = 1.0