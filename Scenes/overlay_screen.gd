class_name OverlayScreen
extends Control

signal screen_obscured
signal return_to_main_menu
signal grid_view_toggled(state : bool)

var grid_view : bool = false
@onready var view_grid_button: Button = $Buttons/ViewGridButton
@onready var background: ColorRect = $Background
@onready var animation_player: AnimationPlayer = $Background/AnimationPlayer
@onready var foreground_buttons: Control = $Buttons/ForegroundButtons
@onready var button_animator: AnimationPlayer = $Buttons/ForegroundButtons/ButtonAnimator

func _shortcut_input(event):
	if is_visible(): 
		if event.is_action_pressed("ui_cancel"):
			if grid_view: view_grid_button.set_pressed(false)
		else:
			return
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if grid_view: view_grid_button.set_pressed(false)

func enter_grid_view():
	grid_view = true
	view_grid_button.set_text("Back")
	animation_player.play_backwards("fade_in")
	background.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	grid_view_toggled.emit(grid_view)

func exit_grid_view():
	grid_view = false
	view_grid_button.set_text("View Grid")
	animation_player.play("fade_in")
	background.set_mouse_filter(Control.MOUSE_FILTER_STOP)
	grid_view_toggled.emit(grid_view)

func _on_view_grid_button_toggled(button_pressed):
	if button_pressed:
		enter_grid_view()
	else:
		exit_grid_view()


func _on_fade_animation_finished(_anim_name):
	if not grid_view:
		button_animator.play("fade_in")


func _on_fade_animation_started(_anim_name):
	if grid_view:
		button_animator.play("fade_out")

func show_buttons():
	view_grid_button.show()

func hide_buttons():
	view_grid_button.hide()

func _on_main_menu_button_pressed() -> void:
	return_to_main_menu.emit()
