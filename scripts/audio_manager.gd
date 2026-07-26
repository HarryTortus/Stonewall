extends Node

# Stores the 0.0 to 1.0 value from your slider
var master_volume: float = 1.0

# Finds the internal ID of Godot's built-in "Master" audio track
@onready var master_bus_index: int = AudioServer.get_bus_index("Master")

func set_master_volume(value: float) -> void:
	master_volume = value
	
	# Convert a linear 0.0-1.0 slider value into Decibels (dB) for realistic audio fading
	var db_value = linear_to_db(value)
	
	# Tell Godot's audio server to change the Master track
	AudioServer.set_bus_volume_db(master_bus_index, db_value)
	
	# Mute completely if slider is moved all the way to 0
	AudioServer.set_bus_mute(master_bus_index, value == 0.0)

	# Debug print to verify tracking
	print("Slider Value: ", value, " | Decibels (dB): ", db_value)