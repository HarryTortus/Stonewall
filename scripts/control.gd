extends Control

@onready var settings_layer: Control = $SettingsLayer
@onready var confirm_reset_popup: Control = find_child("ConfirmResetPopup", true, false)

# Loose main menu buttons and title
@onready var button_settings: Button = $ButtonSettings
@onready var button_play: Button = $ButtonPlay
@onready var button_farm: Button = $ButtonFarm
@onready var title: Node = get_node_or_null("Title")

# Slider & Haptics node references
@onready var master_slider: HSlider = find_child("MasterVolumeSlider", true, false)
@onready var music_slider: HSlider = find_child("MusicVolumeSlider", true, false)
@onready var sfx_slider: HSlider = find_child("SFXVolumeSlider", true, false)
@onready var ambience_slider: HSlider = find_child("AmbienceVolumeSlider", true, false)
@onready var move_slider: HSlider = find_child("MoveSpeedSlider", true, false)
@onready var rotate_slider: HSlider = find_child("RotateSpeedSlider", true, false)
@onready var button_haptics: Button = find_child("ButtonHaptics", true, false)


func _ready() -> void:
	_set_main_menu_visible(true)
	if is_instance_valid(settings_layer):
		settings_layer.hide()
	if is_instance_valid(confirm_reset_popup):
		confirm_reset_popup.hide()
		
	_sync_ui_with_audio_manager()


func _sync_ui_with_audio_manager() -> void:
	if is_instance_valid(master_slider):
		master_slider.min_value = 0.0
		master_slider.max_value = 1.0
		master_slider.step = 0.01
		master_slider.set_value_no_signal(AudioManager.master_volume)

	if is_instance_valid(music_slider):
		music_slider.min_value = 0.0
		music_slider.max_value = 1.0
		music_slider.step = 0.01
		music_slider.set_value_no_signal(AudioManager.music_volume)

	if is_instance_valid(sfx_slider):
		sfx_slider.min_value = 0.0
		sfx_slider.max_value = 1.0
		sfx_slider.step = 0.01
		sfx_slider.set_value_no_signal(AudioManager.sfx_volume)

	if is_instance_valid(ambience_slider):
		ambience_slider.min_value = 0.0
		ambience_slider.max_value = 1.0
		ambience_slider.step = 0.01
		ambience_slider.set_value_no_signal(AudioManager.ambience_volume)

	if is_instance_valid(move_slider):
		move_slider.min_value = 0.5
		move_slider.max_value = 2.0
		move_slider.step = 0.05
		move_slider.set_value_no_signal(AudioManager.move_sensitivity)

	if is_instance_valid(rotate_slider):
		rotate_slider.min_value = 0.5
		rotate_slider.max_value = 2.0
		rotate_slider.step = 0.05
		rotate_slider.set_value_no_signal(AudioManager.rotate_sensitivity)

	_update_haptics_button_text()


func _update_haptics_button_text() -> void:
	if is_instance_valid(button_haptics):
		button_haptics.text = "HAPTICS: ON" if AudioManager.haptics_enabled else "HAPTICS: OFF"


func _on_button_haptics_pressed() -> void:
	var new_state: bool = AudioManager.toggle_haptics()
	_update_haptics_button_text()
	if new_state:
		AudioManager.trigger_haptic(35)


func _on_button_settings_pressed() -> void:
	_set_main_menu_visible(false)
	if is_instance_valid(settings_layer):
		settings_layer.show()
	if is_instance_valid(confirm_reset_popup):
		confirm_reset_popup.hide()


func _on_button_back_pressed() -> void:
	if is_instance_valid(confirm_reset_popup):
		confirm_reset_popup.hide()
	if is_instance_valid(settings_layer):
		settings_layer.hide()
	_set_main_menu_visible(true)


func _set_main_menu_visible(p_visible: bool) -> void:
	if is_instance_valid(button_settings): button_settings.visible = p_visible
	if is_instance_valid(button_play): button_play.visible = p_visible
	if is_instance_valid(button_farm): button_farm.visible = p_visible
	if is_instance_valid(title): title.visible = p_visible


# --- SLIDER SIGNAL HANDLERS ---
func _on_master_volume_slider_value_changed(value: float) -> void:
	AudioManager.set_master_volume(value)


func _on_music_volume_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)


func _on_ambience_volume_slider_value_changed(value: float) -> void:
	AudioManager.set_ambience_volume(value)


func _on_move_speed_slider_value_changed(value: float) -> void:
	AudioManager.set_move_sensitivity(value)


func _on_rotate_speed_slider_value_changed(value: float) -> void:
	AudioManager.set_rotate_sensitivity(value)


# --- CONFIRMATION MODAL HANDLERS ---
func _on_button_wipe_save_pressed() -> void:
	if is_instance_valid(confirm_reset_popup):
		confirm_reset_popup.show()


func _on_button_confirm_yes_pressed() -> void:
	SaveSystem.wipe_all_save_data()
	if is_instance_valid(confirm_reset_popup):
		confirm_reset_popup.hide()


func _on_button_confirm_no_pressed() -> void:
	if is_instance_valid(confirm_reset_popup):
		confirm_reset_popup.hide()


# --- NAVIGATION HANDLERS ---
func _on_button_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _on_button_farm_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/farm_scene.tscn")