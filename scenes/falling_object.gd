extends RigidBody2D

## Distance from the top edge of the screen to the top of the object
@export var top_margin: float = 60.0

func _ready() -> void:
	# Calculate the initial position dynamically based on viewport size
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

	# Set position relative to its parent scene
	position = centered_position

func _process(_delta: float) -> void:
	pass