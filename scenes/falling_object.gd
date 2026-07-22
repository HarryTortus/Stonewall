extends RigidBody2D

## Distance from the top edge of the screen
@export var top_margin: float = 60.0

## Distance (in pixels) from the screen edges to block movement
@export var side_margin: float = 80.0 

var has_started_falling: bool = false
var min_x: float = 0.0
var max_x: float = 0.0

func _ready() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	var sprite_size: Vector2 = Vector2(128, 128)

	if sprite and sprite.texture != null:
		sprite_size = sprite.texture.get_size() * sprite.scale

	# Center horizontally and offset from top margin
	var centered_position: Vector2 = Vector2(
		viewport_size.x / 2.0,
		top_margin + (sprite_size.y / 2.0)
	)

	position = centered_position

	# --- CLAMP BOUNDARIES WITH MARGIN ---
	min_x = side_margin + (sprite_size.x / 2.0)
	max_x = viewport_size.x - side_margin - (sprite_size.x / 2.0)

	# Stay in place until the drop button is pressed
	freeze = true
	gravity_scale = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


## Move horizontally while frozen (clamped to viewport + side_margin)
func move_hover(amount: float) -> void:
	if freeze:
		position.x = clamp(position.x + amount, min_x, max_x)


## Rotate while frozen
func rotate_hover(amount: float) -> void:
	if freeze:
		rotation += amount


## Release gravity
func start_falling() -> void:
	has_started_falling = true
	freeze = false
	gravity_scale = 1.0