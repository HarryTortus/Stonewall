extends RigidBody2D

## Signal emitted when the stone hits the floor or another stone after dropping
signal stone_landed

## Distance from the top edge of the screen (Lower number = Higher spawn)
@export var top_margin: float = 260.0

## Left and Right wall boundaries in screen pixels (adjust these to match your container graphics!)
@export var wall_left_x: float = 50.0
@export var wall_right_x: float = 1030.0 # Set this to match your right wall position!

## Extra clearance in pixels to keep pre-drop hovering stones from touching the side walls
@export var hover_edge_padding: float = 2.0

# --- AUDIO TUNING ---
## Minimum speed to make any sound at all (adjust higher if it's still clicking when settling)
@export var min_impact_velocity: float = 250.0
## Speed considered a "maximum hard impact"
@export var max_impact_velocity: float = 900.0

@export var collision_audio_stream: AudioStream = preload("res://audio/stone_collision_audio.tres")

var collision_player: AudioStreamPlayer
var has_started_falling: bool = false
var has_signaled_landing: bool = false
var original_collision_layer: int = 1
var original_collision_mask: int = 1

# Debounce state
var can_play_sound: bool = true

func _ready() -> void:
	# --- AUTOMATIC AUDIO PLAYER SETUP ---
	collision_player = AudioStreamPlayer.new()
	collision_player.name = "CollisionAudioPlayer"
	collision_player.stream = collision_audio_stream
	collision_player.bus = &"Master"
	add_child(collision_player)

	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	# Disable collisions while hovering
	collision_layer = 0
	collision_mask = 0

	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	max_contacts_reported = 3
	contact_monitor = true
	body_entered.connect(_on_body_entered)


func setup_spawn() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	
	# Spawn centered between your two walls
	var center_x: float = (wall_left_x + wall_right_x) / 2.0
	position = Vector2(center_x, top_margin)

	# Add a random rotation between 0 and 360 degrees
	rotation_degrees = randf_range(0.0, 360.0)


func _on_body_entered(_body: Node) -> void:
	var current_speed: float = linear_velocity.length()
	
	# 1. Play sound with velocity-scaled volume
	if has_started_falling and can_play_sound and current_speed >= min_impact_velocity:
		if is_instance_valid(collision_player):
			# Map speed between 0.15 (quiet soft tap) and 1.0 (loud hard strike)
			var normalized_volume: float = clamp(
				remap(current_speed, min_impact_velocity, max_impact_velocity, 0.15, 1.0),
				0.15,
				1.0
			)
			
			# Convert linear volume to decibels for natural attenuation
			collision_player.volume_db = linear_to_db(normalized_volume)
			collision_player.play()
			
			# Cooldown buffer to prevent rattles
			_start_sound_cooldown(0.3)

	# 2. Signal landing
	if has_started_falling and not has_signaled_landing:
		has_signaled_landing = true
		stone_landed.emit()


func _start_sound_cooldown(duration: float) -> void:
	can_play_sound = false
	await get_tree().create_timer(duration).timeout
	can_play_sound = true


func move_hover(amount: float) -> void:
	if freeze:
		global_position.x += amount
		_clamp_to_screen_bounds()


func rotate_hover(amount: float) -> void:
	if freeze:
		global_rotation += amount
		_clamp_to_screen_bounds()


## Clamps using the actual CollisionPolygon2D shape against the Container Walls
func _clamp_to_screen_bounds() -> void:
	var poly: CollisionPolygon2D = get_node_or_null("CollisionPolygon2D")
	
	var left_extent: float = 32.0
	var right_extent: float = 32.0

	if poly and poly.polygon.size() > 0:
		var min_local_x: float = INF
		var max_local_x: float = -INF

		for point in poly.polygon:
			var global_pt: Vector2 = poly.global_transform * point
			var offset_x: float = global_pt.x - global_position.x
			
			if offset_x < min_local_x:
				min_local_x = offset_x
			if offset_x > max_local_x:
				max_local_x = offset_x

		left_extent = abs(min_local_x)
		right_extent = abs(max_local_x)

	# Calculate limits using explicit wall X coordinates PLUS padding
	var min_x: float = wall_left_x + left_extent + hover_edge_padding
	var max_x: float = wall_right_x - right_extent - hover_edge_padding

	if min_x < max_x:
		global_position.x = clamp(global_position.x, min_x, max_x)
	else:
		global_position.x = (wall_left_x + wall_right_x) / 2.0


func start_falling() -> void:
	has_started_falling = true
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	freeze = false
	gravity_scale = 1.0