extends Node2D

# Track input hold states
var move_dir: float = 0.0
var rotate_dir: float = 0.0
var current_stone: RigidBody2D = null

# Speeds for hovering object
@export var move_speed: float = 300.0
@export var rotate_speed: float = 3.0 # radians per second

# Stone spawning configuration
@export var stone_scenes: Array[PackedScene] = []
@export var global_stone_scale: Vector2 = Vector2(0.5, 0.5)

func _ready() -> void:
	spawn_random_stone()

func spawn_random_stone() -> void:
	if stone_scenes.is_empty():
		print("No stone scenes assigned in Inspector!")
		return
		
	# Pick a random stone scene from the array
	var random_stone_scene: PackedScene = stone_scenes.pick_random()
	current_stone = random_stone_scene.instantiate() as RigidBody2D
	
	# Safely scale child nodes (Sprite2D & CollisionPolygon2D)
	for child in current_stone.get_children():
		if child is Sprite2D or child is CollisionPolygon2D or child is CollisionShape2D:
			child.scale = global_stone_scale
	
	# Listen for when this stone lands so we can spawn the next one
	if current_stone.has_signal("stone_landed"):
		current_stone.stone_landed.connect(_on_stone_landed)

	# Add it to the main game scene
	add_child(current_stone)

func _on_stone_landed() -> void:
	# Small delay so the player can see the drop settle before spawning the next stone
	await get_tree().create_timer(0.3).timeout
	spawn_random_stone()

func _process(delta: float) -> void:
	# Pass movement/rotation inputs to current stone if it exists and hasn't dropped
	if is_instance_valid(current_stone) and current_stone.freeze:
		if move_dir != 0.0:
			current_stone.move_hover(move_dir * move_speed * delta)
		if rotate_dir != 0.0:
			current_stone.rotate_hover(rotate_dir * rotate_speed * delta)

# --- LEFT BUTTON ---
func _on_button_left_button_down() -> void:
	move_dir = -1.0

func _on_button_left_button_up() -> void:
	if move_dir == -1.0:
		move_dir = 0.0

# --- RIGHT BUTTON ---
func _on_button_right_button_down() -> void:
	move_dir = 1.0

func _on_button_right_button_up() -> void:
	if move_dir == 1.0:
		move_dir = 0.0

# --- ROTATE LEFT BUTTON ---
func _on_button_rotate_left_button_down() -> void:
	rotate_dir = -1.0

func _on_button_rotate_left_button_up() -> void:
	if rotate_dir == -1.0:
		rotate_dir = 0.0

# --- ROTATE RIGHT BUTTON ---
func _on_button_rotate_right_button_down() -> void:
	rotate_dir = 1.0

func _on_button_rotate_right_button_up() -> void:
	if rotate_dir == 1.0:
		rotate_dir = 0.0

# --- DROP BUTTON ---
func _on_button_drop_pressed() -> void:
	if is_instance_valid(current_stone) and current_stone.freeze:
		# Stop holding states on drop
		move_dir = 0.0
		rotate_dir = 0.0
		current_stone.start_falling()