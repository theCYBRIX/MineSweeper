class_name StartScreen
extends Control

signal start_game

@onready var settings_menu = $SettingsMenu
@onready var main_buttons = $Main
@onready var prompt_buttons: Control = $Prompt
@onready var start_button: Button = $Main/Start
@onready var quit_button = $Main/Quit
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var main_area: Control = $MainArea
@onready var prompt_area: Control = $PromptArea


func _shortcut_input(event):
	if is_visible(): 
		if event.is_action_pressed("ui_focus_next"):
			start_button.grab_focus()
		elif event.is_action_pressed("ui_focus_prev"):
			quit_button.grab_focus()
		else:
			return
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not settings_menu.is_visible(): close_game()

func _on_new_game_pressed():
	GlobalSettings.use_saved_state = false
	load_game_area()

func _on_options_button_pressed():
	set_child_buttons_disabled(main_buttons)
	get_viewport().gui_release_focus()
	settings_menu.show()


func _on_quit_button_pressed():
	close_game()

func load_game_area():
	start_game.emit()
	SceneLoader.switch_to_scene("game_area", false)

func _on_settings_menu_hidden():
	set_child_buttons_disabled(main_buttons, false)


func _on_settings_menu_end_dialog():
	settings_menu.hide()

func set_child_buttons_block_signals(control : Control, blocking : bool = true):
	for button in control.get_children():
		button.set_block_signals(blocking)

func set_child_buttons_disabled(control : Control, blocking : bool = true):
	var new_focus_mode : FocusMode = FocusMode.FOCUS_NONE if blocking else FocusMode.FOCUS_ALL
	for button : Button in control.get_children().filter(func(c : Control): return c is Button):
		button.set_block_signals(blocking)
		button.focus_mode = new_focus_mode

func set_main_buttons_block_signals(disabled : bool = true):
	set_child_buttons_block_signals(main_buttons, disabled)

func set_prompt_buttons_block_signals(disabled : bool = true):
	set_child_buttons_block_signals(prompt_buttons, disabled)

func close_game():
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


func _on_continue_pressed() -> void:
	GlobalSettings.use_saved_state = true
	load_game_area()


func _on_start_pressed() -> void:
	if GlobalSettings.saved_game_state:
		animation_player.play("enter_prompt")
	else:
		_on_new_game_pressed()


func _on_back_pressed() -> void:
	animation_player.play("exit_prompt")

func tween_into_prompt():
	var tween : Tween = get_tree().create_tween().parallel()
	var duration : float = 0.25
	tween_rect(tween, prompt_buttons, main_area.get_rect(), prompt_area.get_rect(), duration)
	tween_rect(tween, main_buttons, main_area.get_rect(), prompt_area.get_rect(), duration)
	tween.play()

func tween_into_main():
	var tween : Tween = get_tree().create_tween()
	var duration : float = 0.25
	tween_rect(tween, prompt_buttons, prompt_area.get_rect(), main_area.get_rect(), duration)
	tween_rect(tween, main_buttons, prompt_area.get_rect(), main_area.get_rect(), duration)
	tween.play()

func tween_rect(tween : Tween, control : Control, initial : Rect2, final : Rect2, duration : float):
	control.set_position(initial.position)
	tween.parallel().tween_property(control, "position", final.position, duration)
	control.set_size(initial.size)
	tween.parallel().tween_property(control, "size", final.size, duration)
