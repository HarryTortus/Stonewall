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
@export var bird_scale: Vector2 = Vector2(0.35, 0.35)
@export var balloon_scale: Vector2 = Vector2(0.5, 0.5)

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

	# Roll rarity: Check if balloon spawns, otherwise spawn bird
	var roll: float = randf()
	var is_balloon: bool = (roll < balloon_spawn_chance) and not balloon_textures.is_empty()
	
	var texture_pool: Array[Texture2D] = balloon_textures if is_balloon else bird_textures
	if texture_pool.is_empty():
		return

	var chosen_texture: Texture2D = texture_pool.pick_random()
	var flyer = flyer_scene.instantiate()

	# Read dynamic horizontal limits from FarmScene camera
	var farm_scene = get_tree().current_scene
	var min_limit_x: float = 0.0
	var max_limit_x: float = 3000.0

	if farm_scene and "camera" in farm_scene and is_instance_valid(farm_scene.camera):
		min_limit_x = float(farm_scene.camera.limit_left)
		max_limit_x = float(farm_scene.camera.limit_right)

	# Decide travel direction (50/50 Left or Right)
	var fly_right: bool = randf() > 0.5
	var start_x: float = (min_limit_x - 200.0) if fly_right else (max_limit_x + 200.0)
	var target_despawn_x: float = (max_limit_x + 250.0) if fly_right else (min_limit_x - 250.0)
	var fly_dir: float = 1.0 if fly_right else -1.0

	# Apply speed, scale, and altitude
	var spawn_y: float = randf_range(min_sky_y, max_sky_y)
	var speed: float = randf_range(balloon_speed_min, balloon_speed_max) if is_balloon else randf_range(bird_speed_min, bird_speed_max)
	var active_scale: Vector2 = balloon_scale if is_balloon else bird_scale

	add_child(flyer)
	flyer.setup(chosen_texture, Vector2(start_x, spawn_y), fly_dir, speed, target_despawn_x, active_scale)