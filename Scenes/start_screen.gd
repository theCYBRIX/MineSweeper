class_name StartScreen
extends Control

signal start_game

@onready var settings_menu = $SettingsMenu
@onready var buttons = $Buttons
@onready var new_game_button = $Buttons/NewGameButton
@onready var quit_button = $Buttons/QuitButton

func _ready():
	pass

func _shortcut_input(event):
	if is_visible(): 
		if event.is_action_pressed("ui_focus_next"):
			new_game_button.grab_focus()
		elif event.is_action_pressed("ui_focus_prev"):
			quit_button.grab_focus()
		else:
			return
		get_viewport().set_input_as_handled()

func _on_new_game_pressed():
	start_game.emit()


func _on_options_button_pressed():
	set_buttons_disabled()
	get_viewport().gui_release_focus()
	settings_menu.show()


func _on_quit_button_pressed():
	get_tree().quit()
	

func _on_start_game():
	load_game_area()

func load_game_area():
	await SceneLoader.show_loading_screen().safe_to_load
	SceneLoader.scene_loaded.connect(on_game_area_loaded, ConnectFlags.CONNECT_ONE_SHOT)
	get_tree().node_added.connect(func(_node): SceneLoader.move_loading_screen_to_front(), CONNECT_ONE_SHOT)
	SceneLoader.load_scene("game_area")

func on_game_area_loaded(game_area : PackedScene):
	get_tree().change_scene_to_packed(game_area)
	#WorkerThreadPool.add_task(prepare_game_area.bind())

func prepare_game_area(game_area):
	#var instance = game_area.instantiate()
	game_area.prepare_grid()
	#game_area.initialize_tiles()
	#SceneLoader.call_deferred("swap_scene", self, game_area)
	

func _on_settings_menu_hidden():
	set_buttons_disabled(false)


func _on_settings_menu_end_dialog():
	settings_menu.hide()

func set_buttons_disabled(value : bool = true):
	for button in buttons.get_children():
		button.set_disabled(value)
