extends Control

@onready var mine_symbol: TextureRect = $HSplitContainer/Panel/MineSymbol
@onready var mine_label = $HSplitContainer/Panel/MineSymbol/MineLabel

@onready var flag_symbol: TextureRect = $HSplitContainer/Panel/FlagSymbol
@onready var flag_label = $HSplitContainer/Panel/FlagSymbol/FlagLabel

@onready var tile_map_viewport = $HSplitContainer/TileMapArea/SubViewport
@onready var tile_map = $HSplitContainer/TileMapArea/SubViewport/TileMap
@onready var timer_label = $HSplitContainer/Panel/TimerLabel
@onready var timer = $HSplitContainer/Panel/TimerLabel/Timer
@onready var tile_map_camera = $HSplitContainer/TileMapArea/SubViewport/Camera
@onready var pause_screen = $PauseScreen
@onready var buttons = $HSplitContainer/Panel/Buttons
@onready var recenter_button = $HSplitContainer/Panel/Buttons/RecenterButton
@onready var pause_button = $HSplitContainer/Panel/Buttons/PauseButton
@onready var win_screen: Control = $WinScreen

@export_group("Timer Colors", "timer")
@export_color_no_alpha var timer_active_color : Color = Color(0.812, 0.161, 0.161)
@export_color_no_alpha var timer_halted_color : Color = Color(0.071, 0.875, 0.161)
@export_color_no_alpha var timer_waiting_color : Color = Color(0.8, 0.788, 0.129)

var sound_fx_enabled : bool = false

var elapsed_time = 0
var game_ongoing : bool = false
var paused : bool = false

var timer_color_tween : Tween

var tile_map_placeholder : Node

var loading_thread : Thread

func _ready():
	hide()
	tile_map.hide()
	
	#tile_map_placeholder = Node.new()
	#tile_map.call_deferred("replace_by", tile_map_placeholder)
	#await tile_map.tree_exited
	
	#WorkerThreadPool.add_task(prepare.bind())
	loading_thread = Thread.new()
	loading_thread.start(prepare.bind())
	
	
	timer_label.add_theme_color_override("font_color", timer_halted_color)
	flag_label.set_text(str(tile_map.get_flag_count()))
	mine_label.set_text(str(Global.get_mines()))

func release_loading_thread():
	if loading_thread and loading_thread.is_started():
		loading_thread.wait_to_finish()

func prepare():
	#var tree = SceneTree.new()
	#tree.root.add_child(tile_map)
	
	tile_map.prepare_grid()
	
	#tree.root.remove_child(tile_map)
	#tile_map_placeholder.call_deferred("replace_by", tile_map)
	call_deferred("show")
	tile_map.call_deferred("show")
	call_deferred("recenter_tile_map")
	SceneLoader.hide_loading_screen()
	call_deferred("release_loading_thread")

func _shortcut_input(event):
	if (not paused) and game_ongoing:
		if event.is_action_pressed("ui_cancel"):
			pause()
		elif event.is_action_pressed("ui_focus_next"):
			recenter_button.grab_focus()
		elif event.is_action_pressed("ui_focus_prev"):
			pause_button.grab_focus()
		else:
			return
		get_viewport().set_input_as_handled()

func recenter_tile_map():
	tile_map_camera.reset()
	tile_map.fit_to_rect(tile_map.get_viewport_rect())

func _on_tile_map_flag_count_changed(num_flags : int):
	flag_label.set_text(str(num_flags))
	$HSplitContainer/TileMapArea.material.set_shader_parameter("origin", $HSplitContainer/TileMapArea.get_local_mouse_position() / $HSplitContainer/TileMapArea.size)
	$HSplitContainer/TileMapArea/AnimationPlayer.stop()
	$HSplitContainer/TileMapArea/AnimationPlayer.play("press_indicator")
	Global.flag_toggled()

func _on_timer_timeout():
	elapsed_time += 1
	var minutes = int(elapsed_time / 60)
	var seconds = elapsed_time % 60
	timer_label.set_text(("%d:%d" if seconds >= 10 else "%d:0%d") % [minutes, seconds])


func _on_tile_map_win():
	timer.stop()
	tween_timer_color(timer_halted_color, 1)
	game_ongoing = false
	
	mine_symbol.hide()
	flag_symbol.hide()
	timer_label.hide()
	buttons.hide()
	
	win_screen.set_mine_texture_initial_rect(mine_symbol.get_rect())
	win_screen.set_timer_label_initial_rect(timer_label.get_rect())
	win_screen.set_timer_label(timer_label.get_text())
	win_screen.set_mine_label(mine_label.get_text())
	win_screen.set_timer_label_initial_font_size(timer_label.get_theme_font_size("font_size"))
	win_screen.set_mine_label_initial_font_size(mine_label.get_theme_font_size("font_size"))
	win_screen.prepare_animation()
	
	win_screen.show()


func _on_tile_map_lose():
	Global.mine_exploded()
	game_ongoing = false
	timer.stop()
	buttons.hide()
	$LoseScreen.show()


func switch_scene(next : String):
	await SceneLoader.show_loading_screen().safe_to_load
	SceneLoader.scene_loaded.connect(on_scene_loaded, ConnectFlags.CONNECT_ONE_SHOT)
	SceneLoader.load_scene(next)

func on_scene_loaded(new_scene : PackedScene):
	get_tree().change_scene_to_packed(new_scene)
	SceneLoader.hide_loading_screen()


func _on_lose_screen_screen_obscured():
	tile_map.show_all_mines()


func _on_lose_screen_retry():
	load_game_area()

func load_game_area():
	await SceneLoader.show_loading_screen().safe_to_load
	SceneLoader.scene_loaded.connect(on_game_area_loaded, ConnectFlags.CONNECT_ONE_SHOT)
	SceneLoader.load_scene("game_area")

func on_game_area_loaded(game_area : PackedScene):
	get_tree().change_scene_to_packed(game_area)


func return_to_main_menu():
	switch_scene("start_screen")


func _on_pause_button_pressed():
	pause()

func _on_pause_screen_resume():
	resume()

func _on_pause_screen_quit():
	switch_scene("start_screen")


func _on_tile_map_game_started():
	tween_timer_color(timer_active_color, 0.5)
	#timer_label.add_theme_color_override("font_color", timer_active_color)
	if not tile_map.game_over:
		timer.start()
		game_ongoing = true
		if tile_map.is_revealing():
			wait_timer()

func pause():
	paused = true
	if game_ongoing:
		pause_timer()
	get_viewport().gui_release_focus()
	pause_screen.show()
	await pause_screen.fade_in()

func resume():
	paused = false
	await pause_screen.fade_out()
	pause_screen.hide()
	if game_ongoing:
		if tile_map.is_revealing():
			wait_timer()
		else:
			resume_timer()

func _on_tile_map_bulk_reveal_started():
	wait_timer()


func _on_tile_map_bulk_reveal_ended():
	if not paused:
		resume_timer()

func resume_timer():
	timer.set_paused(false)
	tween_timer_color(timer_active_color, 1)
	#timer_label.add_theme_color_override("font_color", timer_active_color)

func pause_timer():
	timer.set_paused(true)
	tween_timer_color(timer_halted_color, 1)
	#timer_label.add_theme_color_override("font_color", )

func wait_timer():
	timer.set_paused(true)
	tween_timer_color(timer_waiting_color, 1)
	#timer_label.add_theme_color_override("font_color", timer_waiting_color)


func tween_timer_color(to, timespan):
	if timer_color_tween != null: timer_color_tween.kill()
	timer_color_tween = create_tween()
	var current_color = timer_label.get_theme_color("font_color")
	if current_color == null: current_color = Color(0, 0, 0)
	timer_color_tween.tween_method(override_timer_color.bind(), current_color, to, timespan)
	timer_color_tween.play()

func override_timer_color(color : Color):
	timer_label.add_theme_color_override("font_color", color)


func _on_tile_map_tile_revealed():
	Global.tile_revealed()
