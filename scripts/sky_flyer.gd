extends Node2D

@onready var visual: Sprite2D = $Visual

var speed: float = 35.0
var direction: float = 1.0 # 1.0 = flying Right, -1.0 = flying Left
var despawn_x: float = 0.0
var bob_amplitude: float = 8.0
var bob_speed: float = 1.2
var time_alive: float = 0.0
var base_y: float = 0.0


func setup(texture: Texture2D, start_pos: Vector2, fly_dir: float, fly_speed: float, target_despawn_x: float, custom_scale: Vector2 = Vector2.ONE) -> void:
	position = start_pos
	base_y = start_pos.y
	direction = fly_dir
	speed = fly_speed
	despawn_x = target_despawn_x
	
	if is_instance_valid(visual):
		visual.texture = texture
		visual.scale = custom_scale
		# Flip sprite visually if traveling left
		visual.flip_h = (fly_dir < 0.0)


func _process(delta: float) -> void:
	time_alive += delta
	
	# Horizontal flight
	position.x += direction * speed * delta
	
	# Gentle floating bob (subtle sine-wave oscillation)
	position.y = base_y + sin(time_alive * bob_speed) * bob_amplitude

	# Despawn when reaching destination edge
	if (direction > 0.0 and position.x >= despawn_x) or (direction < 0.0 and position.x <= despawn_x):
		queue_free()