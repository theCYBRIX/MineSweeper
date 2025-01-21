extends Control

signal setting_changed

@onready var animation_toggle: CheckButton = $SettingsContainer/AnimationSetting/AnimationToggle
@onready var animation_spin_box: SpinBox = $SettingsContainer/AnimationSetting/DurationSetting/SpinBox
@onready var window_mode_button : OptionButton = $SettingsContainer/WindowSettings/WindowMode
@onready var window_settings: HBoxContainer = $SettingsContainer/WindowSettings
@onready var duration_setting: HBoxContainer = $SettingsContainer/AnimationSetting/DurationSetting
@onready var h_separator: HSeparator = $SettingsContainer/HSeparator
@onready var flag_feedback_toggle: CheckButton = $SettingsContainer/FlagFeedbackToggle

var window_mode = {
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN : 0,
	DisplayServer.WINDOW_MODE_FULLSCREEN : 1,
	DisplayServer.WINDOW_MODE_WINDOWED : 2
}

func _ready():
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(0), DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(1), DisplayServer.WINDOW_MODE_FULLSCREEN)
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(2), DisplayServer.WINDOW_MODE_WINDOWED)
	
	if not GlobalSettings.os_is_desktop():
		window_settings.hide()
		h_separator.hide()

func apply_settings():
	var animation_duration : float = animation_spin_box.value if animation_toggle.button_pressed else 0
	var selected_window_mode = window_mode_button.get_selected_metadata()
	var flag_feedback := flag_feedback_toggle.button_pressed
	
	GlobalSettings.settings.set_window_mode(selected_window_mode)
	GlobalSettings.settings.set_animation_duration(animation_duration)
	GlobalSettings.settings.set_flag_feedback(flag_feedback)


func get_as_dictionary() -> Dictionary:
	return {
		"window_mode" : window_mode_button.get_selected_metadata(),
		"animation_duration" : animation_spin_box.value if animation_toggle.button_pressed else 0,
		"flag_feedback" : flag_feedback_toggle.button_pressed
	}

func refresh():
	if GlobalSettings.os_is_desktop():
		select_current_window_mode()
	animation_spin_box.set_value(GlobalSettings.settings.get_animation_duration())
	animation_toggle.button_pressed = GlobalSettings.settings.animation_duration > 0
	flag_feedback_toggle.button_pressed = GlobalSettings.settings.flag_feedback

func select_current_window_mode():
	window_mode_button.select(window_mode_button.get_item_index(window_mode[GlobalSettings.generalize_window_mode(GlobalSettings.settings.get_window_mode())]))


func _on_window_mode_item_selected(_index: int) -> void:
	setting_changed.emit()


func _on_duration_spin_box_value_changed(value: float) -> void:
	setting_changed.emit()


func _on_animation_toggle_toggled(toggled_on: bool) -> void:
	if is_node_ready():
		duration_setting.visible = toggled_on
	setting_changed.emit()


func _on_flag_feedback_toggle_toggled(toggled_on: bool) -> void:
	setting_changed.emit()
