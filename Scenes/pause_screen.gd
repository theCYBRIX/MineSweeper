extends Control

signal resume
signal quit

@onready var animation_player = $AnimationPlayer
@onready var resume_button = $Buttons/ResumeButton
@onready var quit_button = $Buttons/MainMenuButton
@onready var settings_menu = $SettingsMenu
@onready var buttons = $Buttons

func _shortcut_input(event):
	if is_visible():
		if event.is_action_pressed("ui_cancel"):
			resume.emit()
		elif event.is_action_pressed("ui_focus_next"):
			resume_button.grab_focus()
		elif event.is_action_pressed("ui_focus_prev"):
			quit_button.grab_focus()
		else:
			return
		get_viewport().set_input_as_handled()

func _on_resume_button_pressed():
	resume.emit()

func fade_in():
	animation_player.play("RESET")
	animation_player.play("fade_in")
	return animation_player.animation_finished

func fade_out():
	animation_player.play_backwards("fade_in")
	return animation_player.animation_finished

func _on_quit_button_pressed():
	quit.emit()

func _on_options_button_pressed():
	settings_menu.show()
	set_buttons_disabled()
	get_viewport().gui_release_focus()

func _on_settings_menu_end_dialog():
	settings_menu.hide()
	set_buttons_disabled(false)
	get_viewport().gui_release_focus()

func set_buttons_disabled(value : bool = true):
	for button in buttons.get_children():
		button.set_disabled(value)
