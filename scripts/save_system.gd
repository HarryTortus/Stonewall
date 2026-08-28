extends Node

const SAVE_PATH: String = "user://farm_save.json"

## Structure of your save data
var save_data: Dictionary = {
	"total_sheep": 0,
	"walls": [],
	"sheep": [],
	"settings": {
		"master_volume": 1.0,
		"music_volume": 0.7,
		"ambience_volume": 0.8,
		"sfx_volume": 1.0,
		"haptics_enabled": true,
		"move_sensitivity": 1.0,
		"rotate_sensitivity": 1.0
	}
}

func _ready() -> void:
	load_game()


## Save current data dictionary to JSON file
func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		print("Save data successfully written to: ", SAVE_PATH)


## Load data from JSON file
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK and typeof(json.data) == TYPE_DICTIONARY:
			save_data = json.data
			if not save_data.has("sheep"):
				save_data["sheep"] = []
			if not save_data.has("walls"):
				save_data["walls"] = []
			if not save_data.has("settings"):
				save_data["settings"] = {
					"master_volume": 1.0,
					"music_volume": 0.7,
					"ambience_volume": 0.8,
					"sfx_volume": 1.0,
					"haptics_enabled": true,
					"move_sensitivity": 1.0,
					"rotate_sensitivity": 1.0
				}
			else:
				# Guarantee missing keys in existing save files get defaults
				if not save_data["settings"].has("haptics_enabled"):
					save_data["settings"]["haptics_enabled"] = true
				if not save_data["settings"].has("move_sensitivity"):
					save_data["settings"]["move_sensitivity"] = 1.0
				if not save_data["settings"].has("rotate_sensitivity"):
					save_data["settings"]["rotate_sensitivity"] = 1.0
			print("Save data loaded!")


## Retrieve settings dictionary
func get_settings() -> Dictionary:
	if not save_data.has("settings"):
		save_data["settings"] = {
			"master_volume": 1.0,
			"music_volume": 0.7,
			"ambience_volume": 0.8,
			"sfx_volume": 1.0,
			"haptics_enabled": true,
			"move_sensitivity": 1.0,
			"rotate_sensitivity": 1.0
		}
	return save_data["settings"]


## Persist all settings adjustments
func save_settings(settings_dict: Dictionary) -> void:
	save_data["settings"] = settings_dict
	save_game()


# Aliases for backwards compatibility
func get_audio_settings() -> Dictionary:
	return get_settings()

func save_audio_settings(settings_dict: Dictionary) -> void:
	save_settings(settings_dict)


## Appends a newly created wall dictionary directly to the walls list
func add_wall(wall_data: Dictionary) -> void:
	if not save_data.has("walls"):
		save_data["walls"] = []
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


## Wipes farm gameplay data while keeping player preferences intact
func wipe_all_save_data() -> void:
	save_data["total_sheep"] = 0
	save_data["walls"] = []
	save_data["sheep"] = []
	
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				dir.remove(file_name)
				print("Deleted farm asset: ", file_name)
			file_name = dir.get_next()
	
	save_game()
	print("--- FARM RESET COMPLETED ---")