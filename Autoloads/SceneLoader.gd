extends Node

const GAME_AREA = preload("res://Scenes/GameArea/game_area.tscn")
const START_SCREEN = preload("res://Scenes/start_screen.tscn")

const SCENES = {
	"game_area" = "res://Scenes/GameArea/game_area.tscn",
	"start_screen" = "res://Scenes/start_screen.tscn"
}

signal progress_updated(float)
signal scene_loaded(Resource)

var requested_scene : PackedScene
var requested_successfull : bool = false

func load_scene(scene : String) -> Error:
	requested_successfull = false
	
	var error : Error = OK
	
	if scene == "game_area":
		requested_scene = GAME_AREA
	elif scene == "start_screen":
		requested_scene = START_SCREEN
	else:
		var requested_scene_path = SCENES.get(scene, scene)
		
		error = ResourceLoader.load_threaded_request(requested_scene_path)
		
		if error == OK:
			while not requested_successfull:
				var load_progress = []
				var load_status = ResourceLoader.load_threaded_get_status(requested_scene_path, load_progress)
				
				match load_status:
					ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
						printerr("ERROR: Unable to load, invalid resource.")
						error = ERR_INVALID_DATA
					ResourceLoader.THREAD_LOAD_IN_PROGRESS:
						progress_updated.emit(load_progress[0])
					ResourceLoader.THREAD_LOAD_FAILED:
						printerr("ERROR: Loading Failed!")
						error = FAILED
					ResourceLoader.THREAD_LOAD_LOADED:
						requested_scene = ResourceLoader.load_threaded_get(requested_scene_path)
						scene_loaded.emit(requested_scene)
						requested_successfull = true
						error = OK
	
	if error == OK:
		requested_successfull = true
		scene_loaded.emit(requested_scene)
	else:
		push_error("Unable to load requested scene: %s" % error_string(error))
	
	return error

func get_loaded_scene() -> Resource:
	return requested_scene if requested_successfull else null

func swap_scene(current : Node, future : Node):
	var parent_scene = current.get_parent()
	var current_index = current.get_index()
	current.queue_free()
	parent_scene.call_deferred("add_child", future)
	parent_scene.call_deferred("move_child", future, current_index)

func quick_transition(current_scene, scene_to_load):
	show_loading_screen()
	var loaded = load_scene(scene_to_load)
	swap_scene(current_scene, loaded)


func set_loading_progress(progress : float):
	LoadingScreen.update_progress(progress)

func show_loading_screen() -> Signal:
	LoadingScreen.fade_in()
	return LoadingScreen.safe_to_load

func hide_loading_screen():
	await LoadingScreen.fade_out()

func switch_to_scene(scene : String, fade_out : bool = true) -> Error:
	if not LoadingScreen.is_in_foreground():
		LoadingScreen.fade_in()
		await LoadingScreen.safe_to_load
	
	var 	error = await load_scene(scene)
	
	if error == OK:
		var loaded_scene = get_loaded_scene()
		get_tree().change_scene_to_packed(loaded_scene)
		
	if fade_out:
		await LoadingScreen.fade_out()
		
	return error
