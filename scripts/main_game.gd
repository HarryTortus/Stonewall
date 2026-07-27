extends Node2D

# Track input hold states
var move_dir: float = 0.0
var rotate_dir: float = 0.0
var current_stone: RigidBody2D = null

# Speeds for hovering object
@export var move_speed: float = 350.0
@export var rotate_speed: float = 3 # radians per second

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
	
	# 1. Scale child nodes (Sprite2D & Collision)
	for child in current_stone.get_children():
		if child is Sprite2D or child is CollisionPolygon2D or child is CollisionShape2D:
			child.scale = global_stone_scale

	# 2. Add to scene tree FIRST (so viewport size is valid!)
	add_child(current_stone)
	
	# 3. Position cleanly in top-center AFTER adding to tree
	if current_stone.has_method("setup_spawn"):
		current_stone.setup_spawn()

	# Listen for landing signal
	if current_stone.has_signal("stone_landed"):
		current_stone.stone_landed.connect(_on_stone_landed)

func _on_stone_landed() -> void:
	await get_tree().create_timer(0.3).timeout
	spawn_random_stone()

func _process(delta: float) -> void:
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
		move_dir = 0.0
		rotate_dir = 0.0
		current_stone.start_falling()


func _on_button_menu_pressed() -> void:
	print("Button was clicked!") # Add this line
	get_tree().change_scene_to_file("res://scenes/control.tscn")
