extends CharacterBody2D

enum State { IDLE, GRAZE, WALK, STAND_STILL }

# --- NODE REFERENCES ---
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var body: Node2D = get_node_or_null("Body")
@onready var wool_top: Sprite2D = get_node_or_null("Body/WoolTop")
@onready var wool_bottom: Sprite2D = get_node_or_null("Body/WoolBottom")
@onready var tail: Sprite2D = get_node_or_null("Body/WoolTop/Tail")
@onready var name_tag: Label = get_node_or_null("NameTag")

# --- WOOL COLOR VARIATION ---
@export_group("Wool Color Variation")
@export_range(0.0, 1.0) var black_sheep_chance: float = 0.05
@export var black_sheep_brightness: float = 0.18
@export_range(0.0, 1.0) var colored_sheep_chance: float = 0.50
@export_range(0.0, 1.0) var min_saturation: float = 0.20
@export_range(0.0, 1.0) var max_saturation: float = 0.55
@export_range(0.0, 1.0) var min_brightness: float = 0.88
@export_range(0.0, 1.0) var max_brightness: float = 1.00

# --- BEHAVIOR WEIGHTS ---
@export_group("Behavior Rarity / Weights")
@export_range(0.0, 1.0) var graze_weight: float = 0.40
@export_range(0.0, 1.0) var walk_weight: float = 0.30
@export_range(0.0, 1.0) var idle_weight: float = 0.20

# --- STATE DURATIONS ---
@export_group("State Durations (Seconds)")
@export var graze_duration_min: float = 4.0
@export var graze_duration_max: float = 7.0
@export var walk_duration_min: float = 2.5
@export var walk_duration_max: float = 5.0
@export var idle_duration_min: float = 2.0
@export var idle_duration_max: float = 4.0
@export var stand_still_duration_min: float = 1.5
@export var stand_still_duration_max: float = 3.5

# --- MOVEMENT ---
@export_group("Movement Speeds (2.5D Pasture)")
@export var walk_speed_x: float = 45.0
@export var walk_speed_y: float = 22.0
@export var separation_radius: float = 160.0
@export var separation_strength: float = 65.0

var min_x: float = 500.0
var max_x: float = 2000.0
var min_y: float = 1600.0
var max_y: float = 2100.0

var current_state: State = State.IDLE
var state_timer: float = 0.0
var walk_direction: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0

# Persistent / Preview Data
var sheep_id: int = 0
var sheep_name: String = ""
var wool_color: Color = Color.WHITE
var has_custom_color_loaded: bool = false
var is_preview_mode: bool = false
var name_tween: Tween = null


func _ready() -> void:
	randomize()
	input_pickable = true

	# Connect tap / click event
	input_event.connect(_on_input_event)

	if not has_custom_color_loaded:
		_apply_random_wool_color()
	else:
		_set_wool_parts_color(wool_color)

	# If locked in popup preview mode, freeze physics and lock to idle
	if is_preview_mode:
		set_physics_process(false)
		current_state = State.IDLE
		_play_anim("idle", "")
		return

	add_to_group("sheep")
	_pick_next_state(randf_range(0.5, 2.0))


func init_sheep(id: int, s_name: String, color_hex: String) -> void:
	sheep_id = id
	sheep_name = s_name
	wool_color = Color.html(color_hex)
	has_custom_color_loaded = true
	_set_wool_parts_color(wool_color)
	
	if is_instance_valid(name_tag):
		name_tag.text = sheep_name


## Click / Tap trigger to reveal sheep's name
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_preview_mode:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_name_bubble()
	elif event is InputEventScreenTouch and event.pressed:
		show_name_bubble()


func show_name_bubble() -> void:
	if not is_instance_valid(name_tag):
		return

	name_tag.text = sheep_name if sheep_name != "" else ("Sheep #" + str(sheep_id + 1))

	if name_tween and name_tween.is_valid():
		name_tween.kill()

	name_tween = create_tween()
	name_tween.tween_property(name_tag, "modulate:a", 1.0, 0.2)
	name_tween.tween_interval(2.2)
	name_tween.tween_property(name_tag, "modulate:a", 0.0, 0.4)


func set_as_preview() -> void:
	is_preview_mode = true
	set_physics_process(false)
	var col_shape = get_node_or_null("CollisionShape2D")
	if is_instance_valid(col_shape):
		col_shape.disabled = true


func generate_random_color() -> Color:
	if randf() < black_sheep_chance:
		return Color(black_sheep_brightness, black_sheep_brightness, black_sheep_brightness, 1.0)
	elif randf() < colored_sheep_chance:
		var h = randf()
		var s = randf_range(min_saturation, max_saturation)
		var v = randf_range(min_brightness, max_brightness)
		return Color.from_hsv(h, s, v, 1.0)
	return Color.WHITE


func _apply_random_wool_color() -> void:
	wool_color = generate_random_color()
	_set_wool_parts_color(wool_color)


func _set_wool_parts_color(c: Color) -> void:
	if is_instance_valid(wool_top): wool_top.self_modulate = c
	if is_instance_valid(wool_bottom): wool_bottom.self_modulate = c
	if is_instance_valid(tail): tail.self_modulate = c


func set_bounds(p_min_x: float, p_max_x: float, p_min_y: float, p_max_y: float) -> void:
	min_x = p_min_x
	max_x = p_max_x
	min_y = p_min_y
	max_y = p_max_y


func _physics_process(delta: float) -> void:
	if is_preview_mode:
		return

	state_timer -= delta
	var avoidance: Vector2 = _get_avoidance_vector()

	if current_state == State.WALK:
		var combined_dir: Vector2 = (walk_direction + avoidance * 1.5).normalized()
		var target_vel = Vector2(combined_dir.x * walk_speed_x, combined_dir.y * walk_speed_y)

		velocity = velocity.move_toward(target_vel, 250.0 * delta)
		move_and_slide()

		if get_slide_collision_count() > 0:
			var col = get_slide_collision(0)
			var normal = col.get_normal()
			walk_direction = (walk_direction.slide(normal) + normal * 0.5).normalized()
			stuck_timer += delta
			if stuck_timer > 0.6:
				stuck_timer = 0.0
				_pick_next_state()
		else:
			stuck_timer = max(0.0, stuck_timer - delta)

		if is_instance_valid(body) and abs(velocity.x) > 4.0:
			body.scale.x = sign(velocity.x)

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
		if avoidance.length_squared() > 0.01:
			var passive_vel = Vector2(avoidance.x * separation_strength * 0.5, avoidance.y * (separation_strength * 0.25))
			velocity = velocity.move_toward(passive_vel, 180.0 * delta)
			move_and_slide()
		else:
			velocity = Vector2.ZERO

	z_index = int(position.y)

	if state_timer <= 0.0:
		_pick_next_state()


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
			var repel: Vector2 = push_dir * (factor * factor)
			var swerve_dir: Vector2 = Vector2(-push_dir.y * 0.8, push_dir.x * 1.5)
			
			if position.y > (min_y + max_y) / 2.0:
				swerve_dir.y = -abs(swerve_dir.y)
			else:
				swerve_dir.y = abs(swerve_dir.y)

			total_steer += repel + (swerve_dir * factor * 2.0)

	return total_steer.normalized() if total_steer != Vector2.ZERO else Vector2.ZERO


func _pick_next_state(forced_duration: float = -1.0) -> void:
	if is_preview_mode:
		return

	var roll: float = randf()
	stuck_timer = 0.0

	if roll < graze_weight:
		current_state = State.GRAZE
		_play_anim("graze", "idle")
		state_timer = forced_duration if forced_duration > 0.0 else randf_range(graze_duration_min, graze_duration_max)

	elif roll < (graze_weight + walk_weight):
		current_state = State.WALK
		_play_anim("walk", "idle")

		var dir_x: float = randf_range(-1.0, 1.0)
		var dir_y: float = randf_range(-0.8, 0.8)
		if abs(dir_x) < 0.2: dir_x = 1.0 if randf() > 0.5 else -1.0
		
		walk_direction = Vector2(dir_x, dir_y).normalized()
		if is_instance_valid(body): body.scale.x = sign(dir_x)

		state_timer = forced_duration if forced_duration > 0.0 else randf_range(walk_duration_min, walk_duration_max)

	elif roll < (graze_weight + walk_weight + idle_weight):
		current_state = State.IDLE
		_play_anim("idle", "")
		state_timer = forced_duration if forced_duration > 0.0 else randf_range(idle_duration_min, idle_duration_max)

	else:
		current_state = State.STAND_STILL
		if is_instance_valid(animation_player):
			animation_player.stop()
		state_timer = forced_duration if forced_duration > 0.0 else randf_range(stand_still_duration_min, stand_still_duration_max)


func _play_anim(anim_name: String, fallback: String) -> void:
	if not is_instance_valid(animation_player): return
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	elif fallback != "" and animation_player.has_animation(fallback):
		animation_player.play(fallback)