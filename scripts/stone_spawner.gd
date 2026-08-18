extends Node2D

## Emitted whenever a newly spawned stone is created and ready for the player to aim
signal stone_spawned(new_stone: RigidBody2D)

# --- CONFIGURATION EXPORTS ---
## The list of stone PackedScenes to pick from randomly
@export var stone_scenes: Array[PackedScene] = []

## Visual and collision scale applied to child nodes of each spawned stone
@export var global_stone_scale: Vector2 = Vector2(0.5, 0.5)

## Delay in seconds before a new hovering stone is created after dropping the previous one
@export var spawn_delay: float = 0.8

var is_spawning: bool = false


## Instantiates a random stone, scales its children, and adds it to the scene
func spawn_random_stone() -> RigidBody2D:
	if stone_scenes.is_empty():
		print("StoneSpawner: No stone scenes assigned in Inspector!")
		return null

	# 1. Pick a random stone scene
	var random_scene: PackedScene = stone_scenes.pick_random()
	var stone: RigidBody2D = random_scene.instantiate() as RigidBody2D

	# 2. Scale child nodes BEFORE adding to scene tree (keeps RigidBody2D scale at 1, 1)
	for child in stone.get_children():
		if child is Sprite2D or child is CollisionPolygon2D or child is CollisionShape2D:
			child.scale = global_stone_scale

	# 3. Add directly to MainGame scene root
	var parent_node = get_parent()
	if parent_node != null:
		parent_node.add_child(stone)
	else:
		add_child(stone)

	# 4. Position and setup initial rotation
	if stone.has_method("setup_spawn"):
		stone.setup_spawn()

	stone_spawned.emit(stone)
	return stone
	

## Spawns the next stone after a brief falling delay
func spawn_next_stone_with_delay() -> void:
	if is_spawning:
		return

	is_spawning = true
	await get_tree().create_timer(spawn_delay).timeout
	is_spawning = false

	spawn_random_stone()