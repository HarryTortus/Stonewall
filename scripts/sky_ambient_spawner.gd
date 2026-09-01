extends Node2D

@export var flyer_scene: PackedScene = preload("res://scenes/sky_flyer.tscn")

# Texture Pools
@export_group("Textures")
@export var bird_textures: Array[Texture2D] = []
@export var balloon_textures: Array[Texture2D] = []

# Rarity & Chance
@export_group("Rarity")
## Chance that a spawn event produces a balloon instead of birds (e.g. 0.08 = 8% chance)
@export_range(0.0, 1.0) var balloon_spawn_chance: float = 0.10

# Scale Adjusters
@export_group("Visual Scales")
@export var bird_scale_min: float = 0.10
@export var bird_scale_max: float = 0.15
@export var balloon_scale: Vector2 = Vector2(0.15, 0.15)

# Speeds
@export_group("Flight Speeds")
@export var bird_speed_min: float = 60.0
@export var bird_speed_max: float = 100.0
@export var balloon_speed_min: float = 18.0
@export var balloon_speed_max: float = 30.0

# Sky Altitude Range (Pixels from top)
@export_group("Altitude")
@export var min_sky_y: float = 120.0
@export var max_sky_y: float = 600.0

# Spawn Interval (Seconds)
@export_group("Spawn Timers")
@export var min_spawn_delay: float = 14.0
@export var max_spawn_delay: float = 30.0

var spawn_timer: float = 0.0


func _ready() -> void:
	_reset_timer()


func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_random_sky_element()
		_reset_timer()


func _reset_timer() -> void:
	spawn_timer = randf_range(min_spawn_delay, max_spawn_delay)


func _spawn_random_sky_element() -> void:
	if not flyer_scene:
		return

	var roll: float = randf()
	var is_balloon: bool = (roll < balloon_spawn_chance) and not balloon_textures.is_empty()
	
	var texture_pool: Array[Texture2D] = balloon_textures if is_balloon else bird_textures
	if texture_pool.is_empty():
		return

	var chosen_texture: Texture2D = texture_pool.pick_random()
	var flyer = flyer_scene.instantiate()

	var farm_scene = get_tree().current_scene
	var min_limit_x: float = 0.0
	var max_limit_x: float = 3000.0

	if farm_scene and "camera" in farm_scene and is_instance_valid(farm_scene.camera):
		min_limit_x = float(farm_scene.camera.limit_left)
		max_limit_x = float(farm_scene.camera.limit_right)

	# Dynamic screen half-width calculation for wide displays
	var viewport_width: float = get_viewport_rect().size.x
	var spawn_padding: float = 400.0

	# Mirror the offset evenly across both left and right flanks
	var effective_left: float = min_limit_x - (viewport_width * 0.5) - spawn_padding
	var effective_right: float = max_limit_x + spawn_padding

	var fly_right: bool = randf() > 0.5
	var start_x: float = effective_left if fly_right else effective_right
	var target_despawn_x: float = (effective_right + 50.0) if fly_right else (effective_left - 50.0)
	var fly_dir: float = 1.0 if fly_right else -1.0

	var spawn_y: float = randf_range(min_sky_y, max_sky_y)
	var speed: float = randf_range(balloon_speed_min, balloon_speed_max) if is_balloon else randf_range(bird_speed_min, bird_speed_max)
	
	var random_bird_factor: float = randf_range(bird_scale_min, bird_scale_max)
	var active_scale: Vector2 = balloon_scale if is_balloon else Vector2(random_bird_factor, random_bird_factor)

	flyer.setup(chosen_texture, Vector2(start_x, spawn_y), fly_dir, speed, target_despawn_x, active_scale, is_balloon)
	add_child(flyer)