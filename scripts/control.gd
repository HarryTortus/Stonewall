extends Control

@onready var main_menu: VBoxContainer = %MainMenuContainer
@onready var settings_menu: VBoxContainer = %SettingsMenuContainer

func _ready() -> void:
	main_menu.show()
	settings_menu.hide()

func _process(_delta: float) -> void:
	pass

func _on_button_settings_pressed() -> void:
	main_menu.hide()
	settings_menu.show()

func _on_button_back_pressed() -> void:
	settings_menu.hide()
	main_menu.show()


func _on_h_slider_value_changed(value: float) -> void:
	# Call our global persistent script!
	AudioManager.set_master_volume(value)


func _on_button_play_pressed() -> void:
	# Tell Godot to swap out the current scene for your new gameplay scene.
	# Make sure this string matches the exact file path where you saved it!
	print("Button was clicked!") # Add this line
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _on_button_wipe_save_pressed() -> void:
	SaveSystem.wipe_all_save_data()
