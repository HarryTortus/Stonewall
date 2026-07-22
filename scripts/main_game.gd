extends Node2D

@onready var falling_object: RigidBody2D = $FallingObject

# Track input hold states
var move_dir: float = 0.0
var rotate_dir: float = 0.0

# Speeds for hovering object
@export var move_speed: float = 300.0
@export var rotate_speed: float = 3.0 # radians per second

func _process(delta: float) -> void:
	# Only pass movement/rotation if the falling object exists and hasn't dropped yet
	if is_instance_valid(falling_object) and falling_object.freeze:
		if move_dir != 0.0:
			falling_object.move_hover(move_dir * move_speed * delta)
		if rotate_dir != 0.0:
			falling_object.rotate_hover(rotate_dir * rotate_speed * delta)

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
	if is_instance_valid(falling_object) and falling_object.freeze:
		# Stop holding states on drop
		move_dir = 0.0
		rotate_dir = 0.0
		falling_object.start_falling()
