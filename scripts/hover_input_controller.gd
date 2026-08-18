extends Node

# Speeds for hovering object
@export var move_speed: float = 350.0
@export var rotate_speed: float = 3.0 # radians per second

# Input hold directions (-1.0 to 1.0)
var move_dir: float = 0.0
var rotate_dir: float = 0.0

# Reference to the current active stone being aimed
var active_stone: RigidBody2D = null
var is_active: bool = true


func set_active_stone(stone: RigidBody2D) -> void:
	active_stone = stone
	# Reset input states when a new stone arrives
	move_dir = 0.0
	rotate_dir = 0.0


func clear_active_stone() -> void:
	active_stone = null
	move_dir = 0.0
	rotate_dir = 0.0


func _process(delta: float) -> void:
	if not is_active or not is_instance_valid(active_stone):
		return

	# Only move/rotate while the stone is frozen in hover mode
	if active_stone.freeze:
		if move_dir != 0.0:
			active_stone.move_hover(move_dir * move_speed * delta)
		if rotate_dir != 0.0:
			active_stone.rotate_hover(rotate_dir * rotate_speed * delta)


# --- BUTTON EVENT HANDLERS ---

func on_left_down() -> void:
	move_dir = -1.0

func on_left_up() -> void:
	if move_dir == -1.0:
		move_dir = 0.0

func on_right_down() -> void:
	move_dir = 1.0

func on_right_up() -> void:
	if move_dir == 1.0:
		move_dir = 0.0

func on_rotate_left_down() -> void:
	rotate_dir = -1.0

func on_rotate_left_up() -> void:
	if rotate_dir == -1.0:
		rotate_dir = 0.0

func on_rotate_right_down() -> void:
	rotate_dir = 1.0

func on_rotate_right_up() -> void:
	if rotate_dir == 1.0:
		rotate_dir = 0.0