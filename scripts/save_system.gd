extends Node

const SAVE_PATH: String = "user://farm_save.json"

## Structure of your save data
var save_data: Dictionary = {
	"total_sheep": 0,
	"walls": [],
	"sheep": [] # Array of { "id": 0, "name": "Barnaby", "color": "fce4ec" }
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
		print("Save data successfully written to: ", SAVE_PATH)

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
			if not save_data.has("sheep"):
				save_data["sheep"] = []
			print("Save data loaded!")

## Appends a newly created wall dictionary directly to the walls list
func add_wall(wall_data: Dictionary) -> void:
	save_data["walls"].append(wall_data)
	save_game()

## Appends a newly created sheep dictionary directly to the sheep list
func add_sheep(sheep_data: Dictionary) -> void:
	if not save_data.has("sheep"):
		save_data["sheep"] = []
	save_data["sheep"].append(sheep_data)
	save_data["total_sheep"] = save_data["sheep"].size()
	save_game()

## Updates the name of a specific sheep by its ID
func update_sheep_name(sheep_id: int, new_name: String) -> void:
	var list: Array = save_data.get("sheep", [])
	for s in list:
		if s.get("id") == sheep_id:
			s["name"] = new_name
			save_game()
			return

## DEV HELPER: Deletes all saved PNG files and wipes farm_save.json clean
func wipe_all_save_data() -> void:
	# 1. Reset memory dictionary
	save_data["total_sheep"] = 0
	save_data["walls"] = []
	save_data["sheep"] = []
	
	# 2. Delete all saved wall PNG files from disk
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				dir.remove(file_name)
				print("Deleted dev asset: ", file_name)
			file_name = dir.get_next()
	
	# 3. Overwrite JSON file with empty state
	save_game()
	print("--- DEV: ALL SAVE DATA AND PNGs WIPED ---")