extends Control

@onready var main_menu: VBoxContainer = %MainMenuContainer
@onready var settings_menu: VBoxContainer = %SettingsMenuContainer

func _ready() -> void:
	main_menu.show()
	settings_menu.hide()

func _process(delta: float) -> void:
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
