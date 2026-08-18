extends RigidBody2D

## Signal emitted when the stone hits the floor or another stone after dropping
signal stone_landed

## Distance from the top edge of the screen (Lower number = Higher spawn)
@export var top_margin: float = 260.0

## Left and Right wall boundaries in screen pixels
@export var wall_left_x: float = 50.0
@export var wall_right_x: float = 1030.0

## Extra clearance in pixels to keep pre-drop hovering stones from touching the side walls
@export var hover_edge_padding: float = 2.0

# --- AUDIO TUNING ---
## Minimum speed required to make a sound on secondary bounces (ignores small jitters)
@export var min_bounce_velocity: float = 180.0
## Speed at which a secondary bounce reaches maximum secondary volume
@export var max_bounce_velocity: float = 650.0

@export var collision_audio_stream: AudioStream = preload("res://audio/stone_collision_audio.tres")

var collision_player: AudioStreamPlayer
var has_started_falling: bool = false
var has_signaled_landing: bool = false
var original_collision_layer: int = 1
var original_collision_mask: int = 1

# Audio tracking
var is_first_impact: bool = true
var can_play_sound: bool = true

func _ready() -> void:
	# 1. Setup Audio Player
	collision_player = AudioStreamPlayer.new()
	collision_player.name = "CollisionAudioPlayer"
	collision_player.stream = collision_audio_stream
	collision_player.bus = &"SFX"
	collision_player.pitch_scale = 1.0
	add_child(collision_player)

	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	# 2. Physics Material Setup for Firm Settling
	var mat = PhysicsMaterial.new()
	mat.friction = 1.0       # High surface grip between stones
	mat.bounce = 0.0         # No rubbery bounce
	mat.absorbent = true     # Absorbs rebound energy on contact
	physics_material_override = mat

	# 3. Disable collisions while hovering
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
	var center_x: float = (wall_left_x + wall_right_x) / 2.0
	position = Vector2(center_x, top_margin)
	rotation_degrees = randf_range(0.0, 360.0)


func _on_body_entered(_body: Node) -> void:
	if not has_started_falling:
		return

	var current_speed: float = linear_velocity.length()

	if can_play_sound and is_instance_valid(collision_player):
		collision_player.stop()

		if is_first_impact:
			# --- HIT 1: Main Drop Impact (Full Volume) ---
			collision_player.volume_db = 0.0
			collision_player.play()
			is_first_impact = false
			_start_sound_cooldown(0.25)

		elif current_speed >= min_bounce_velocity:
			# --- HIT 2+: Secondary Bounces ---
			var linear_vol: float = clamp(
				remap(current_speed, min_bounce_velocity, max_bounce_velocity, 0.10, 0.25),
				0.10,
				0.25
			)
			collision_player.volume_db = linear_to_db(linear_vol)
			collision_player.play()
			_start_sound_cooldown(0.25)

	# Signal wall landing
	if not has_signaled_landing:
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

	var min_x: float = wall_left_x + left_extent + hover_edge_padding
	var max_x: float = wall_right_x - right_extent - hover_edge_padding

	if min_x < max_x:
		global_position.x = clamp(global_position.x, min_x, max_x)
	else:
		global_position.x = (wall_left_x + wall_right_x) / 2.0


func start_falling() -> void:
	has_started_falling = true
	is_first_impact = true
	can_play_sound = true
	
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	freeze = false
	gravity_scale = 1.0
	
	# Clean standard damping so downward fall speed is unaffected
	linear_damp = 0.0
	angular_damp = 1.0 # Light rotational damping stops infinite spin after landing