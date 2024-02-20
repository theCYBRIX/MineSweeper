extends Control

signal setting_changed

@onready var window_mode_button : OptionButton = $SettingsContainer/VBoxContainer/WindowSettings/WindowMode
@onready var speed_slider: HSlider = $SettingsContainer/SpeedSetting/SpeedSlider
@onready var speed_percent_label: Label = $SettingsContainer/SpeedSetting/SpeedPercentLabel
@onready var window_settings: VBoxContainer = $SettingsContainer/VBoxContainer

var speed_slider_dragging : bool = false

var window_mode = {
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN : 0,
	DisplayServer.WINDOW_MODE_FULLSCREEN : 1,
	DisplayServer.WINDOW_MODE_WINDOWED : 2
}

func _ready():
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(0), DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(1), DisplayServer.WINDOW_MODE_FULLSCREEN)
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(2), DisplayServer.WINDOW_MODE_WINDOWED)
	
	if GlobalSettings.os_is_mobile():
		window_settings.hide()

func apply_settings():
	var speed_percentage : float = speed_slider.get_value()
	var selected_window_mode = window_mode_button.get_selected_metadata()
	
	GlobalSettings.settings.set_window_mode(selected_window_mode)
	GlobalSettings.settings.set_processing_speed(speed_percentage / 100.0)


func get_as_dictionary() -> Dictionary:
	return {
		"window_mode" = window_mode_button.get_selected_metadata(),
		"speed_percentage" = speed_slider.get_value()
	}

func refresh():
	select_current_window_mode()
	speed_slider.set_value(GlobalSettings.settings.get_processing_speed() * 100.0)

func select_current_window_mode():
	window_mode_button.select(window_mode_button.get_item_index(window_mode[GlobalSettings.generalize_window_mode(GlobalSettings.settings.get_window_mode())]))


func _on_window_mode_item_selected(_index: int) -> void:
	setting_changed.emit()

func _on_speed_slider_value_changed(value):
	speed_percent_label.set_text("%2.1f%%"%value)
	if not speed_slider_dragging: setting_changed.emit()


func _on_speed_slider_drag_started() -> void:
	speed_slider_dragging = true
	setting_changed.emit()

func _on_speed_slider_drag_ended(value_changed: bool) -> void:
	speed_slider_dragging = false
	if value_changed: setting_changed.emit()
