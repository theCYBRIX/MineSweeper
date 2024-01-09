extends Control

@onready var warning_dialog = $WarningDialog
@onready var reset_button = $SettingsContainer/HBoxContainer/ResetButton


func _on_reset_button_pressed():
	reset_button.set_disabled(true)
	warning_dialog.show()

func _on_warning_dialog_confirmed():
	Global.reset_settings()
	Global.save_settings()
	reset_button.set_disabled(false)

func _on_warning_dialog_canceled():
	reset_button.set_disabled(false)


func _on_visibility_changed():
	if warning_dialog and warning_dialog.is_visible():
		warning_dialog.hide()
		reset_button.set_disabled(false)
