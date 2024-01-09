
extends Control

signal screen_obscured
signal retry
signal return_to_main_menu

var grid_view : bool = false
@onready var retry_button = $Buttons/RetryButton
@onready var main_menu_button: Button = $Buttons/MainMenuButton
@onready var view_grid_button: Button = $Buttons/ViewGridButton
@onready var background: ColorRect = $Background
@onready var animation_player: AnimationPlayer = $Background/AnimationPlayer

func _shortcut_input(event):
	if is_visible(): 
		if event.is_action_pressed("ui_cancel"):
			if grid_view: view_grid_button.set_pressed(false)
		elif event.is_action_pressed("ui_focus_next"):
			retry_button.grab_focus()
		else:
			return
		get_viewport().set_input_as_handled()

func _on_retry_button_pressed():
	retry.emit()


func _on_main_menu_button_pressed():
	return_to_main_menu.emit()

func enter_grid_view():
	grid_view = true
	view_grid_button.set_text("Back")
	animation_player.play_backwards("fade_in")
	background.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)

func exit_grid_view():
	grid_view = false
	view_grid_button.set_text("View Grid")
	animation_player.play("fade_in")
	background.set_mouse_filter(Control.MOUSE_FILTER_STOP)

# Play shock animation when made visible
func _on_visibility_changed():
	if is_node_ready():
		if is_visible():
			animation_player.play("impact")
			await animation_player.animation_finished
			view_grid_button.show()

func _on_view_grid_button_toggled(button_pressed):
	if button_pressed:
		enter_grid_view()
	else:
		exit_grid_view()


func _on_fade_animation_finished(_anim_name):
	if not grid_view:
		retry_button.show()
		main_menu_button.show()


func _on_fade_animation_started(_anim_name):
	retry_button.hide()
	main_menu_button.hide()


func _on_retry():
	load_game_area()

func load_game_area():
	await SceneLoader.show_loading_screen().safe_to_load
	SceneLoader.scene_loaded.connect(on_game_area_loaded, ConnectFlags.CONNECT_ONE_SHOT)
	SceneLoader.load_scene("game_area")

func on_game_area_loaded(game_area : PackedScene):
	var instance = game_area.instantiate()
	instance.ready.connect(SceneLoader.hide_loading_screen.bind(), ConnectFlags.CONNECT_ONE_SHOT)
	SceneLoader.swap_scene(get_parent(), instance)

