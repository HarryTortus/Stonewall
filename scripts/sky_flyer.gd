extends Node2D

@onready var visual: Sprite2D = $Visual
@onready var bird: Node2D = $Bird
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var speed: float = 35.0
var direction: float = 1.0
var despawn_x: float = 0.0
var bob_amplitude: float = 8.0
var bob_speed: float = 1.2
var time_alive: float = 0.0
var base_y: float = 0.0

var _cached_texture: Texture2D
var _cached_scale: Vector2 = Vector2.ONE
var _cached_is_balloon: bool = false
var _base_bird_rotation: float = 0.0


func setup(texture: Texture2D, start_pos: Vector2, fly_dir: float, fly_speed: float, target_despawn_x: float, custom_scale: Vector2 = Vector2.ONE, is_balloon: bool = false) -> void:
	position = start_pos
	base_y = start_pos.y
	direction = fly_dir
	speed = fly_speed
	despawn_x = target_despawn_x
	
	_cached_texture = texture
	_cached_scale = custom_scale
	_cached_is_balloon = is_balloon

	if is_inside_tree():
		_apply_visual_setup()


func _ready() -> void:
	if is_instance_valid(bird):
		_base_bird_rotation = bird.rotation
	_apply_visual_setup()


func _apply_visual_setup() -> void:
	if _cached_is_balloon:
		if is_instance_valid(visual):
			visual.visible = true
			visual.texture = _cached_texture
			visual.scale = _cached_scale
			visual.flip_h = (direction < 0.0)
		if is_instance_valid(bird):
			bird.visible = false
		if is_instance_valid(anim_player):
			anim_player.stop()
	else:
		if is_instance_valid(visual):
			visual.visible = false
		if is_instance_valid(bird):
			bird.visible = true
			var dir_flip: float = 1.0 if direction < 0.0 else -1.0
			bird.scale = Vector2(_cached_scale.x * dir_flip, _cached_scale.y)
			# Mirror rotation so pitch matches flight angle in both directions
			bird.rotation = _base_bird_rotation * dir_flip
		if is_instance_valid(anim_player):
			anim_player.play("default")


func _process(delta: float) -> void:
	time_alive += delta
	position.x += direction * speed * delta
	position.y = base_y + sin(time_alive * bob_speed) * bob_amplitude

	if (direction > 0.0 and position.x >= despawn_x) or (direction < 0.0 and position.x <= despawn_x):
		queue_free()