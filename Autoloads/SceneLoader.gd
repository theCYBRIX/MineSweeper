extends Node

const SCENES = {
	"game_area" = "res://Scenes/GameArea/game_area.tscn",
	"start_screen" = "res://Scenes/start_screen.tscn"
}

signal progress_updated(float)
signal scene_loaded(Resource)

var requested_scene_path : String
var requested_successfull : bool = false

func load_scene(scene : String) -> Error:
	requested_successfull = false
	requested_scene_path = SCENES.get(scene, scene)
	
	var error = ResourceLoader.load_threaded_request(requested_scene_path)
	
	if error == OK:
		while true:
			var load_progress = []
			var load_status = ResourceLoader.load_threaded_get_status(requested_scene_path, load_progress)
			
			match load_status:
				0: # THREAD_LOAD_INVALID_RESOURCE
					printerr("ERROR: Unable to load, invalid resource.")
					error = ERR_INVALID_DATA
				1: # THREAD_LOAD_IN_PROGRESS
					progress_updated.emit(load_progress[0])
				2: # THREAD_LOAD_FAILED
					printerr("ERROR: Loading Failed!")
					error = FAILED
				3: # THREAD_LOAD_LOADED
					var loaded = ResourceLoader.load_threaded_get(requested_scene_path)
					scene_loaded.emit(loaded)
					requested_successfull = true
					return OK
					
	
	printerr("Error: Unable to load requested scene. (Code: %d)" % error)
	return error

func get_loaded_scene() -> Resource:
	return ResourceLoader.get(requested_scene_path) if requested_successfull else null

func swap_scene(current : Node, future : Node):
	var parent_scene = current.get_parent()
	var current_index = get_index()
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
