extends Node

var master_volume: float = 1.0
var music_volume: float = 0.7
var ambience_volume: float = 0.8
var sfx_volume: float = 1.0
var haptics_enabled: bool = true

# Control Sensitivities (Multiplier: 0.5x to 2.0x)
var move_sensitivity: float = 1.0
var rotate_sensitivity: float = 1.0

@onready var master_bus_idx: int = AudioServer.get_bus_index("Master")
@onready var music_bus_idx: int = AudioServer.get_bus_index("Music")
@onready var ambience_bus_idx: int = AudioServer.get_bus_index("Ambience")
@onready var sfx_bus_idx: int = AudioServer.get_bus_index("SFX")

var bgm_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

@export var music_track: AudioStream = preload("res://audio/guitar1.wav")
@export var ambience_track: AudioStream = preload("res://audio/field1.wav")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.stream = music_track
	bgm_player.bus = &"Music"
	add_child(bgm_player)

	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "AmbiencePlayer"
	ambience_player.stream = ambience_track
	ambience_player.bus = &"Ambience"
	add_child(ambience_player)

	_load_saved_settings()
	play_all_audio()


func _load_saved_settings() -> void:
	if typeof(SaveSystem) != TYPE_NIL and SaveSystem.has_method("get_settings"):
		var settings = SaveSystem.get_settings()
		master_volume = settings.get("master_volume", 1.0)
		music_volume = settings.get("music_volume", 0.7)
		ambience_volume = settings.get("ambience_volume", 0.8)
		sfx_volume = settings.get("sfx_volume", 1.0)
		haptics_enabled = settings.get("haptics_enabled", true)
		move_sensitivity = settings.get("move_sensitivity", 1.0)
		rotate_sensitivity = settings.get("rotate_sensitivity", 1.0)

	set_master_volume(master_volume, false)
	set_music_volume(music_volume, false)
	set_ambience_volume(ambience_volume, false)
	set_sfx_volume(sfx_volume, false)
	set_move_sensitivity(move_sensitivity, false)
	set_rotate_sensitivity(rotate_sensitivity, false)


func play_all_audio() -> void:
	if is_instance_valid(bgm_player) and bgm_player.stream != null and not bgm_player.playing:
		bgm_player.play()
	if is_instance_valid(ambience_player) and ambience_player.stream != null and not ambience_player.playing:
		ambience_player.play()


func set_master_volume(value: float, save: bool = true) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume(master_bus_idx, master_volume)
	if save: _persist_settings()


func set_music_volume(value: float, save: bool = true) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume(music_bus_idx, music_volume)
	if save: _persist_settings()


func set_ambience_volume(value: float, save: bool = true) -> void:
	ambience_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume(ambience_bus_idx, ambience_volume)
	if save: _persist_settings()


func set_sfx_volume(value: float, save: bool = true) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume(sfx_bus_idx, sfx_volume)
	if save: _persist_settings()


func set_move_sensitivity(value: float, save: bool = true) -> void:
	move_sensitivity = clamp(value, 0.5, 2.0)
	if save: _persist_settings()


func set_rotate_sensitivity(value: float, save: bool = true) -> void:
	rotate_sensitivity = clamp(value, 0.5, 2.0)
	if save: _persist_settings()


func toggle_haptics(save: bool = true) -> bool:
	haptics_enabled = not haptics_enabled
	if save: _persist_settings()
	return haptics_enabled


func trigger_haptic(duration_ms: int = 35) -> void:
	if duration_ms <= 0:
		return
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func _persist_settings() -> void:
	if typeof(SaveSystem) != TYPE_NIL and SaveSystem.has_method("save_settings"):
		var settings = {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"ambience_volume": ambience_volume,
			"sfx_volume": sfx_volume,
			"haptics_enabled": haptics_enabled,
			"move_sensitivity": move_sensitivity,
			"rotate_sensitivity": rotate_sensitivity
		}
		SaveSystem.save_settings(settings)


func _apply_bus_volume(bus_index: int, value: float) -> void:
	if bus_index < 0:
		return
	if value <= 0.001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))