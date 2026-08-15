extends AnimatedSprite2D

func _ready() -> void:
	# 1. Randomize the starting frame so sheep aren't synced
	frame = randi() % sprite_frames.get_frame_count("idle")
	
	# 2. Add slight speed variation (e.g., between 0.8 and 1.5 FPS)
	speed_scale = randf_range(0.8, 1.4)
	
	# 3. Randomly flip left or right for variety
	flip_h = randf() > 0.5
	
	# 4. Start playing
	play("idle")