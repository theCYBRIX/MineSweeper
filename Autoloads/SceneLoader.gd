extends Node

const SCENES = {
	"game_area" = "res://Scenes/GameArea/game_area.tscn",
	"start_screen" = "res://Scenes/start_screen.tscn"
}

signal progress_updated(float)
signal scene_loaded(Resource)

var loading_screen : PackedScene = preload("res://Scenes/loading_screen.tscn")
var loading_screen_instance : LoadingScreen

func _ready() -> void:
	get_tree().node_added.connect(func(_node): move_loading_screen_to_front())

func load_scene(scene : String):
	
	var load_path : String = SCENES.get(scene, scene)
	
	var loader
	if ResourceLoader.exists(load_path):
		loader = ResourceLoader.load_threaded_request(load_path)
	
	if loader == null:
		printerr("Error: Unable to locate requested scene. \"%s\"" % [load_path])
		return null
	
	while true:
		var load_progress = []
		var load_status = ResourceLoader.load_threaded_get_status(load_path, load_progress)
		
		match load_status:
			0: # THREAD_LOAD_INVALID_RESOURCE
				printerr("ERROR: Unable to load, invalid resource.")
				return null
			1: # THREAD_LOAD_IN_PROGRESS
				progress_updated.emit(load_progress[0])
			2: # THREAD_LOAD_FAILED
				printerr("ERROR: Loading Failed!")
				return null
			3: # THREAD_LOAD_LOADED
				var loaded = ResourceLoader.load_threaded_get(load_path)
				scene_loaded.emit(loaded)
				return loaded

func swap_scene(current : Node, future : Node):
	var parent_scene = current.get_parent()
	var current_index = get_index()
	current.queue_free()
	parent_scene.call_deferred("add_child", future)
	parent_scene.call_deferred("move_child", future, current_index)

func quick_transition(current_scene, scene_to_load):
	wait_show_loading_screen()
	var loaded = load_scene(scene_to_load)
	swap_scene(current_scene, loaded)
	wait_hide_loading_screen()


func set_loading_screen_progress(progress : float):
	if loading_screen_instance != null:
		loading_screen_instance.update_progress(progress)


func wait_show_loading_screen():
	await show_loading_screen().safe_to_load

func wait_hide_loading_screen():
	if loading_screen_instance != null:
		loading_screen_instance.call_deferred("fade_out_loading_screen")
		await loading_screen_instance.tree_exited

func show_loading_screen():
	if loading_screen_instance != null:
		loading_screen_instance.call_deferred("emit_signal", "safe_to_load")
	else:
		create_new_loading_screen()
		get_tree().get_root().call_deferred("add_child", loading_screen_instance)
	return loading_screen_instance

func hide_loading_screen():
	if loading_screen_instance != null :
		loading_screen_instance.call_deferred("fade_out_loading_screen")

func get_loading_screen_instance() -> Node:
	return loading_screen_instance

func on_loading_screen_removed():
	loading_screen_instance = null

func move_loading_screen_to_front():
	if loading_screen_instance and not loading_screen_instance.is_queued_for_deletion():
		get_tree().root.move_child(loading_screen_instance, -1)

func create_new_loading_screen():
	loading_screen_instance = loading_screen.instantiate()
	loading_screen_instance.tree_exited.connect(on_loading_screen_removed, CONNECT_ONE_SHOT)
