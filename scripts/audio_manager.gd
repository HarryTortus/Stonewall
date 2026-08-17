extends Node

# Linear volume values (0.0 to 1.0)
var master_volume: float = 1.0
var music_volume: float = 0.7
var ambience_volume: float = 0.8
var sfx_volume: float = 1.0

# Audio bus indices
@onready var master_bus_idx: int = AudioServer.get_bus_index("Master")
@onready var music_bus_idx: int = AudioServer.get_bus_index("Music")
@onready var ambience_bus_idx: int = AudioServer.get_bus_index("Ambience")
@onready var sfx_bus_idx: int = AudioServer.get_bus_index("SFX")

# Dedicated Audio Players
var bgm_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

# Preload your tracks
@export var music_track: AudioStream = preload("res://audio/guitar1.wav")
@export var ambience_track: AudioStream = preload("res://audio/field1.wav")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Persists across scene changes

	# 1. Background Music Player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.stream = music_track
	bgm_player.bus = &"Music"
	add_child(bgm_player)

	# 2. Ambient Sound Player
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "AmbiencePlayer"
	ambience_player.stream = ambience_track
	ambience_player.bus = &"Ambience"
	add_child(ambience_player)

	# Apply initial volume settings
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_ambience_volume(ambience_volume)
	set_sfx_volume(sfx_volume)

	# Start both tracks
	play_all_audio()


func play_all_audio() -> void:
	if is_instance_valid(bgm_player) and bgm_player.stream != null and not bgm_player.playing:
		bgm_player.play()
	
	if is_instance_valid(ambience_player) and ambience_player.stream != null and not ambience_player.playing:
		ambience_player.play()


# --- VOLUME CONTROLS (0.0 to 1.0) ---
func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume(master_bus_idx, master_volume)


func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume(music_bus_idx, music_volume)


func set_ambience_volume(value: float) -> void:
	ambience_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume(ambience_bus_idx, ambience_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volume(sfx_bus_idx, sfx_volume)


func _apply_bus_volume(bus_index: int, value: float) -> void:
	if bus_index < 0:
		return
	if value <= 0.001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))