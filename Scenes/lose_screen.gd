extends OverlayScreen

signal retry

@onready var retry_button = $Buttons/ForegroundButtons/RetryButton

func _shortcut_input(event):
	super._shortcut_input(event)
	if(get_viewport().is_input_handled()):
		return
	elif is_visible(): 
		if event.is_action_pressed("ui_focus_next"):
			retry_button.grab_focus()
			get_viewport().set_input_as_handled()

func _on_retry_button_pressed():
	retry.emit()

# Play shock animation when made visible
func _on_visibility_changed():
	if is_node_ready():
		if is_visible():
			animation_player.play("impact")


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
