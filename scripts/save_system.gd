extends Node

const SAVE_PATH: String = "user://farm_save.json"

## Structure of your save data
var save_data: Dictionary = {
	"total_sheep": 0,
	"walls": [] # List of saved walls
}

func _ready() -> void:
	load_game()

## Save the current data dictionary to a JSON file
func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		print("Wall successfully saved to: ", SAVE_PATH)

## Load data from the JSON file
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			save_data = json.data
			print("Save data loaded!")

## Appends a newly created wall dictionary directly to the walls list
func add_wall(wall_data: Dictionary) -> void:
	save_data["walls"].append(wall_data)
	save_game()

## Helper to wipe the save file clean when testing
func clear_save_data() -> void:
	save_data["walls"] = []
	save_game()