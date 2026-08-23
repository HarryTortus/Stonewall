extends CharacterBody2D

enum State { IDLE, GRAZE, WALK, STAND_STILL }

@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var body: Node2D = get_node_or_null("Body")

# --- BEHAVIOR WEIGHTS (0.0 to 1.0) ---
@export_group("Behavior Rarity / Weights")
@export_range(0.0, 1.0) var graze_weight: float = 0.40
@export_range(0.0, 1.0) var walk_weight: float = 0.30
@export_range(0.0, 1.0) var idle_weight: float = 0.20
# Remainder becomes STAND_STILL pause

# --- STATE DURATION RANGES (SECONDS) ---
@export_group("State Durations (Seconds)")
@export var graze_duration_min: float = 4.0
@export var graze_duration_max: float = 7.0
@export var walk_duration_min: float = 2.5
@export var walk_duration_max: float = 5.0
@export var idle_duration_min: float = 2.0
@export var idle_duration_max: float = 4.0
@export var stand_still_duration_min: float = 1.5
@export var stand_still_duration_max: float = 3.5

# --- 2.5D SPEED & AVOIDANCE ---
@export_group("Movement Speeds (2.5D Pasture)")
@export var walk_speed_x: float = 45.0  ## Faster horizontal pacing
@export var walk_speed_y: float = 22.0  ## Slower vertical wander depth
@export var separation_radius: float = 160.0
@export var separation_strength: float = 65.0

# Dynamic pasture limits passed from spawner
var min_x: float = 500.0
var max_x: float = 2000.0
var min_y: float = 1600.0
var max_y: float = 2100.0

var current_state: State = State.IDLE
var state_timer: float = 0.0
var walk_direction: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
var sheep_name: String = ""


func _ready() -> void:
	randomize()
	add_to_group("sheep")
	_pick_next_state(randf_range(0.5, 2.0))


func set_bounds(p_min_x: float, p_max_x: float, p_min_y: float, p_max_y: float) -> void:
	min_x = p_min_x
	max_x = p_max_x
	min_y = p_min_y
	max_y = p_max_y


func _physics_process(delta: float) -> void:
	state_timer -= delta

	var avoidance: Vector2 = _get_avoidance_vector()

	if current_state == State.WALK:
		# Blend wander intent with avoidance vector
		var combined_dir: Vector2 = (walk_direction + avoidance * 1.5).normalized()
		
		# Separate X and Y velocities for cozy 2.5D perspective
		var target_vel = Vector2(
			combined_dir.x * walk_speed_x,
			combined_dir.y * walk_speed_y
		)

		velocity = velocity.move_toward(target_vel, 250.0 * delta)
		move_and_slide()

		# Check physical collisions and deflect sideways
		if get_slide_collision_count() > 0:
			var col = get_slide_collision(0)
			var normal = col.get_normal()
			
			# Slide along the collision normal rather than walking in place
			walk_direction = (walk_direction.slide(normal) + normal * 0.5).normalized()
			stuck_timer += delta
			
			# If stuck against an obstacle for too long, pick a new state
			if stuck_timer > 0.6:
				stuck_timer = 0.0
				_pick_next_state()
		else:
			stuck_timer = max(0.0, stuck_timer - delta)

		# Face the active horizontal moving direction
		if is_instance_valid(body) and abs(velocity.x) > 4.0:
			body.scale.x = sign(velocity.x)

		# Soft turn-around at field borders
		if position.x <= min_x and walk_direction.x < 0:
			walk_direction.x = abs(walk_direction.x)
			if is_instance_valid(body): body.scale.x = 1.0
		elif position.x >= max_x and walk_direction.x > 0:
			walk_direction.x = -abs(walk_direction.x)
			if is_instance_valid(body): body.scale.x = -1.0

		if position.y <= min_y and walk_direction.y < 0:
			walk_direction.y = abs(walk_direction.y)
		elif position.y >= max_y and walk_direction.y > 0:
			walk_direction.y = -abs(walk_direction.y)

	else:
		# Passive yield if another sheep brushes past while grazing/idle
		if avoidance.length_squared() > 0.01:
			var passive_vel = Vector2(
				avoidance.x * separation_strength * 0.5,
				avoidance.y * (separation_strength * 0.25)
			)
			velocity = velocity.move_toward(passive_vel, 180.0 * delta)
			move_and_slide()
		else:
			velocity = Vector2.ZERO

	# Depth sorting by Y-coordinate
	z_index = int(position.y)

	if state_timer <= 0.0:
		_pick_next_state()


## Calculates repulsive push and dynamic steering around neighboring sheep
func _get_avoidance_vector() -> Vector2:
	var total_steer = Vector2.ZERO
	var neighbors = get_tree().get_nodes_in_group("sheep")

	for neighbor in neighbors:
		if neighbor == self or not is_instance_valid(neighbor):
			continue

		var offset: Vector2 = global_position - neighbor.global_position
		var dist: float = offset.length()

		if dist < separation_radius and dist > 0.01:
			var factor: float = 1.0 - (dist / separation_radius)
			var push_dir: Vector2 = offset / dist

			# 1. Repulsive Push
			var repel: Vector2 = push_dir * (factor * factor)

			# 2. Tangential Swerve (peels up/down to glide cleanly around)
			var swerve_dir: Vector2 = Vector2(-push_dir.y * 0.8, push_dir.x * 1.5)
			
			if position.y > (min_y + max_y) / 2.0:
				swerve_dir.y = -abs(swerve_dir.y)
			else:
				swerve_dir.y = abs(swerve_dir.y)

			var swerve: Vector2 = swerve_dir * factor * 2.0
			total_steer += repel + swerve

	return total_steer.normalized() if total_steer != Vector2.ZERO else Vector2.ZERO


## State transition logic
func _pick_next_state(forced_duration: float = -1.0) -> void:
	var roll: float = randf()
	stuck_timer = 0.0

	# 1. Graze
	if roll < graze_weight:
		current_state = State.GRAZE
		_play_anim("graze", "idle")
		state_timer = forced_duration if forced_duration > 0.0 else randf_range(graze_duration_min, graze_duration_max)

	# 2. Walk
	elif roll < (graze_weight + walk_weight):
		current_state = State.WALK
		_play_anim("walk", "idle")

		# Pick a natural 2D wander angle with full vertical roaming freedom
		var dir_x: float = randf_range(-1.0, 1.0)
		var dir_y: float = randf_range(-0.8, 0.8)
		
		# Ensure they don't roll a zero vector
		if abs(dir_x) < 0.2: dir_x = 1.0 if randf() > 0.5 else -1.0
		
		walk_direction = Vector2(dir_x, dir_y).normalized()

		if is_instance_valid(body):
			body.scale.x = sign(dir_x)

		state_timer = forced_duration if forced_duration > 0.0 else randf_range(walk_duration_min, walk_duration_max)

	# 3. Idle (Active breathing)
	elif roll < (graze_weight + walk_weight + idle_weight):
		current_state = State.IDLE
		_play_anim("idle", "")
		state_timer = forced_duration if forced_duration > 0.0 else randf_range(idle_duration_min, idle_duration_max)

	# 4. Stand Still (Resting pause)
	else:
		current_state = State.STAND_STILL
		if is_instance_valid(animation_player):
			animation_player.stop()
		state_timer = forced_duration if forced_duration > 0.0 else randf_range(stand_still_duration_min, stand_still_duration_max)


## Safe animation player call
func _play_anim(anim_name: String, fallback: String) -> void:
	if not is_instance_valid(animation_player):
		return

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	elif fallback != "" and animation_player.has_animation(fallback):
		animation_player.play(fallback)