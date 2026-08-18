extends Node

## Emitted when all stones in the wall have fully come to rest and are calm
signal wall_settled

## Emitted when all stones have settled AND at least one is touching the string line goal
signal wall_goal_reached

# --- CONFIGURATION EXPORTS ---
## Must remain completely still for this many continuous seconds before declaring settled
@export var settle_duration_needed: float = 0.45

## Speed in pixels/sec below which a stone is considered resting (ignores micro-compression)
@export var movement_velocity_threshold: float = 45.0

## Angular speed in rad/sec below which a stone is considered resting (ignores minor teetering)
@export var movement_angular_threshold: float = 1.0

# --- NODE REFERENCES ---
@export var string_line: Area2D

# Internal tracking
var wall_stones_ref: Array[RigidBody2D] = []
var is_active_monitoring: bool = false
var is_wall_settled: bool = true
var time_spent_settled: float = 0.0


func start_monitoring(stones_array: Array[RigidBody2D]) -> void:
	wall_stones_ref = stones_array
	is_active_monitoring = true
	is_wall_settled = false
	time_spent_settled = 0.0


func stop_monitoring() -> void:
	is_active_monitoring = false


func _physics_process(delta: float) -> void:
	if not is_active_monitoring:
		return

	# 1. Check if any stone in the wall is actively moving above threshold
	var is_any_stone_moving: bool = false
	for stone in wall_stones_ref:
		if is_instance_valid(stone) and not stone.freeze:
			if stone.linear_velocity.length() > movement_velocity_threshold or abs(stone.angular_velocity) > movement_angular_threshold:
				is_any_stone_moving = true
				break

	if is_any_stone_moving:
		# Reset calm counter if any stone shifts or rolls
		time_spent_settled = 0.0
		is_wall_settled = false
	else:
		# Accumulate calm time
		time_spent_settled += delta

		# Once calm long enough, trigger settlement evaluations
		if time_spent_settled >= settle_duration_needed and not is_wall_settled:
			is_wall_settled = true
			wall_settled.emit()
			_check_string_line_goal()


func _check_string_line_goal() -> void:
	if not is_instance_valid(string_line):
		return

	var overlapping_bodies: Array = string_line.get_overlapping_bodies()
	for stone in wall_stones_ref:
		if is_instance_valid(stone) and overlapping_bodies.has(stone):
			print("SettlementMonitor: Stone settled on string line goal!")
			stop_monitoring()
			wall_goal_reached.emit()
			return