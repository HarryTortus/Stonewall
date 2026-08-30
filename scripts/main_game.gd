extends Node2D

# --- CONTAINER, UI & SERVICE REFERENCES ---
@export var floor_node: Node2D
@export var drop_button: BaseButton
@export var stone_spawner: Node2D
@export var wall_capture_service: Node2D
@export var settlement_monitor: Node2D
@export var hover_input_controller: Node2D

# Button references for touch opacity feedback
@onready var btn_left: Button = $Buttons/MarginContainer/HBoxContainer/Control/ButtonLeft
@onready var btn_right: Button = $Buttons/MarginContainer/HBoxContainer/Control/ButtonRight
@onready var btn_rot_left: Button = $Buttons/MarginContainer/HBoxContainer/Control/ButtonRotateLeft
@onready var btn_rot_right: Button = $Buttons/MarginContainer/HBoxContainer/Control/ButtonRotateRight
@onready var btn_drop: Button = $Buttons/MarginContainer/HBoxContainer/Control/ButtonDrop

var wall_stones: Array[RigidBody2D] = []
var current_stone: RigidBody2D = null
var is_saving_wall: bool = false
var is_wall_settled: bool = true

func _ready() -> void:
	if is_instance_valid(stone_spawner):
		stone_spawner.stone_spawned.connect(_on_stone_spawned)
		stone_spawner.spawn_random_stone()

	if is_instance_valid(settlement_monitor):
		settlement_monitor.wall_settled.connect(_on_wall_settled)
		settlement_monitor.wall_goal_reached.connect(_on_wall_goal_reached)


func _on_stone_spawned(new_stone: RigidBody2D) -> void:
	if is_saving_wall:
		return
	current_stone = new_stone
	
	if is_instance_valid(hover_input_controller):
		hover_input_controller.set_active_stone(current_stone)
	
	if is_wall_settled and is_instance_valid(drop_button):
		drop_button.disabled = false


func _on_wall_settled() -> void:
	if is_saving_wall:
		return
		
	is_wall_settled = true
	
	if is_instance_valid(drop_button):
		var has_hover_stone = is_instance_valid(current_stone) and current_stone.freeze
		drop_button.disabled = not has_hover_stone


func _on_wall_goal_reached() -> void:
	if is_saving_wall:
		return
		
	is_saving_wall = true
	if is_instance_valid(drop_button):
		drop_button.disabled = true
		
	save_current_wall()


# --- UI BUTTON SIGNALS (TOUCH FEEDBACK) ---

func _on_button_left_button_down() -> void:
	if is_instance_valid(btn_left): btn_left.modulate.a = 0.5
	if is_instance_valid(hover_input_controller): hover_input_controller.on_left_down()

func _on_button_left_button_up() -> void:
	if is_instance_valid(btn_left): btn_left.modulate.a = 1.0
	if is_instance_valid(hover_input_controller): hover_input_controller.on_left_up()

func _on_button_right_button_down() -> void:
	if is_instance_valid(btn_right): btn_right.modulate.a = 0.5
	if is_instance_valid(hover_input_controller): hover_input_controller.on_right_down()

func _on_button_right_button_up() -> void:
	if is_instance_valid(btn_right): btn_right.modulate.a = 1.0
	if is_instance_valid(hover_input_controller): hover_input_controller.on_right_up()

func _on_button_rotate_left_button_down() -> void:
	if is_instance_valid(btn_rot_left): btn_rot_left.modulate.a = 0.5
	if is_instance_valid(hover_input_controller): hover_input_controller.on_rotate_left_down()

func _on_button_rotate_left_button_up() -> void:
	if is_instance_valid(btn_rot_left): btn_rot_left.modulate.a = 1.0
	if is_instance_valid(hover_input_controller): hover_input_controller.on_rotate_left_up()

func _on_button_rotate_right_button_down() -> void:
	if is_instance_valid(btn_rot_right): btn_rot_right.modulate.a = 0.5
	if is_instance_valid(hover_input_controller): hover_input_controller.on_rotate_right_down()

func _on_button_rotate_right_button_up() -> void:
	if is_instance_valid(btn_rot_right): btn_rot_right.modulate.a = 1.0
	if is_instance_valid(hover_input_controller): hover_input_controller.on_rotate_right_up()

func _on_button_drop_button_down() -> void:
	if is_instance_valid(btn_drop):
		btn_drop.modulate.a = 0.5

func _on_button_drop_button_up() -> void:
	if is_instance_valid(btn_drop):
		btn_drop.modulate.a = 1.0

func _on_button_drop_pressed() -> void:
	if is_saving_wall or not is_wall_settled:
		return

	if is_instance_valid(current_stone) and current_stone.freeze:
		var dropped_stone: RigidBody2D = current_stone
		current_stone = null
		
		if is_instance_valid(hover_input_controller):
			hover_input_controller.clear_active_stone()
		
		if not wall_stones.has(dropped_stone):
			wall_stones.append(dropped_stone)
		
		dropped_stone.start_falling()
		
		is_wall_settled = false
		if is_instance_valid(drop_button):
			drop_button.disabled = true

		if is_instance_valid(settlement_monitor):
			settlement_monitor.start_monitoring(wall_stones)

		if is_instance_valid(stone_spawner):
			stone_spawner.spawn_next_stone_with_delay()


func _on_button_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/control.tscn")


func save_current_wall() -> void:
	if is_instance_valid(hover_input_controller):
		hover_input_controller.is_active = false

	if is_instance_valid(wall_capture_service):
		var wall_image: Image = await wall_capture_service.capture_wall_image(wall_stones, floor_node)
		wall_capture_service.save_wall_to_disk(wall_image)

	get_tree().change_scene_to_file("res://scenes/farm_scene.tscn")