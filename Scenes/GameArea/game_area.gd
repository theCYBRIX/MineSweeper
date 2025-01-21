extends Control

const TILE_MAP : PackedScene = preload("res://Scenes/GameArea/tile_map.tscn")

signal preparation_finished

@onready var mine_symbol: TextureRect = $HSplitContainer/Panel/MineSymbol
@onready var mine_label = $HSplitContainer/Panel/MineSymbol/MineLabel

@onready var flag_symbol: TextureRect = $HSplitContainer/Panel/FlagSymbol
@onready var flag_label = $HSplitContainer/Panel/FlagSymbol/FlagLabel
@onready var camera: Camera2D = $HSplitContainer/TileMapArea/SubViewport/Camera


@onready var tile_map_viewport = $HSplitContainer/TileMapArea/SubViewport
@onready var tile_map_area: SubViewportContainer = $HSplitContainer/TileMapArea

@onready var timer_label : Label = $HSplitContainer/Panel/TimerLabel
@onready var timer : Timer = $HSplitContainer/Panel/TimerLabel/Timer

@onready var tile_map_camera = $HSplitContainer/TileMapArea/SubViewport/Camera
@onready var buttons = $HSplitContainer/Panel/Buttons
@onready var recenter_button = $HSplitContainer/Panel/Buttons/RecenterButton
@onready var pause_button = $HSplitContainer/Panel/Buttons/PauseButton
@onready var flag_animation: AnimationPlayer = $HSplitContainer/TileMapArea/FlagAnimation

@onready var ready_screen: Control = $Overlays/ReadyScreen
@onready var lose_screen: Control = $Overlays/LoseScreen
@onready var pause_screen = $Overlays/PauseScreen
@onready var win_screen: Control = $Overlays/WinScreen

@onready var camera_shake: AnimationPlayer = $HSplitContainer/TileMapArea/SubViewport/Camera/CameraShake/ShakeAnimation

@export_group("Timer Colors", "timer")
@export_color_no_alpha var timer_active_color : Color = Color(0.812, 0.161, 0.161)
@export_color_no_alpha var timer_halted_color : Color = Color(0.071, 0.875, 0.161)
@export_color_no_alpha var timer_waiting_color : Color = Color(0.8, 0.788, 0.129)

var game_ongoing : bool = false
var paused : bool = false

var timer_color_tween : Tween

var initializing : bool = true
var new_game : bool = false

var loading_cancelled : bool = false

var _tile_map : Node2D
var _worker_task_id : int

func _ready():
	LoadingScreen.cancel_requested.connect(_on_loading_screen_cancel_requested)
	await prepare_asynch()
	LoadingScreen.cancel_requested.disconnect(_on_loading_screen_cancel_requested)
	
	if loading_cancelled: return
	
	camera.tile_map = _tile_map
	#tile_map_viewport.call_deferred("add_child", _tile_map, false, Node.INTERNAL_MODE_FRONT)
	
	set_process_input(true)
	
	refresh_ui()
	SceneLoader.hide_loading_screen()


func prepare_asynch() -> Signal:
	#_worker_task_id = WorkerThreadPool.add_task(prepare)
	await prepare()
	return preparation_finished


func prepare() -> void:
	initializing = true
	var game_state : GameState = GlobalSettings.get_initial_game_state()
	_tile_map = TILE_MAP.instantiate()
	tile_map_viewport.add_child(_tile_map, false, Node.INTERNAL_MODE_FRONT)
	_tile_map.set_game_state(game_state)
	await _tile_map.update_full_map()
	_tile_map.bulk_reveal_ended.connect(_on_tile_map_bulk_reveal_ended)
	_tile_map.bulk_reveal_started.connect(_on_tile_map_bulk_reveal_started)
	_tile_map.flag_count_changed.connect(_on_tile_map_flag_count_changed)
	_tile_map.game_started.connect(_on_tile_map_game_started)
	_tile_map.lose.connect(_on_tile_map_lose)
	_tile_map.safe_tile_count_changed.connect(_on_tile_map_safe_tile_count_changed)
	_tile_map.win.connect(_on_tile_map_win)
	#_tile_map.propagate_call("_notification", [NOTIFICATION_DRAW])
	initializing = false
	call_deferred("emit_signal", "preparation_finished")

func refresh_ui():
	recenter_tile_map()
	timer_label.add_theme_color_override("font_color", timer_halted_color)
	update_timer_text()
	flag_label.set_text(str(_tile_map.get_flag_count()))
	mine_label.set_text(str(_tile_map.game_state.num_mines))
	if _tile_map.game_state.first_tile_revealed:
		ready_screen.show()
	else:
		tile_map_area.grab_focus()

func _shortcut_input(event):
	if (not paused) and (_tile_map and not _tile_map.game_over) and not initializing:
		if event.is_action_pressed("ui_cancel"):
			pause()


func _notification(what: int) -> void:
	match(what):
		NOTIFICATION_WM_CLOSE_REQUEST | NOTIFICATION_WM_GO_BACK_REQUEST: #Back button pressed on Android or Escape pressed on desktop
			if _tile_map.game_over: return
			if not paused: pause()
		NOTIFICATION_APPLICATION_PAUSED: #application minimized on Android
			if game_ongoing and not paused:
				pause()
	


func recenter_tile_map():
	tile_map_camera.center_on_area(Rect2(_tile_map.position, _tile_map.get_size()))

func _on_tile_map_flag_count_changed(num_flags : int):
	flag_label.set_text(str(num_flags))
	if GlobalSettings.settings.flag_feedback:
		flag_animation.stop()
		flag_animation.play("press_indicator")
	SoundManager.flag_toggled()

func _on_timer_timeout():
	_tile_map.game_state.time_elapsed += 1
	update_timer_text()

func update_timer_text():
	var elapsed_time : int = int(_tile_map.game_state.time_elapsed)
	var minutes : int  = elapsed_time / 60
	var hours : int = minutes / 60
	minutes = minutes % 60
	var seconds : int = elapsed_time % 60
	
	var label_text : String = ""
	if hours > 0:
		label_text += "%d:" % [hours]
		label_text += "%0*d:" % [2, minutes]
	else:
		label_text += "%d:" % [minutes]
	label_text += "%0*d" % [2, seconds]
	timer_label.set_text(label_text)

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
	GlobalSettings.delete_save()


func _on_tile_map_lose():
	game_ongoing = false
	timer.stop()
	buttons.hide()
	SoundManager.mine_exploded()
	camera_shake.play("shake_camera")
	lose_screen.show()
	GlobalSettings.delete_save()
	


func _on_lose_screen_screen_obscured():
	_tile_map.show_all_mines()


func _on_lose_screen_retry():
	load_game_area()

func load_game_area():
	SceneLoader.switch_to_scene("game_area", false)


func return_to_main_menu():
	GlobalSettings.game_state = null
	SceneLoader.switch_to_scene("start_screen")


func _on_pause_button_pressed():
	pause()

func _on_pause_screen_resume():
	resume()

func _on_pause_screen_quit():
	if game_ongoing:
		_tile_map.stop()
		_tile_map.game_state.time_elapsed += (timer.wait_time - timer.time_left)
		GlobalSettings.save_game_state(_tile_map.game_state)
	return_to_main_menu()


func _on_tile_map_game_started():
	tween_timer_color(timer_active_color, 0.5)
	if not _tile_map.game_over:
		timer.start()
		game_ongoing = true
		if _tile_map.is_revealing():
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
		if _tile_map.is_revealing():
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

func pause_timer():
	timer.set_paused(true)
	tween_timer_color(timer_halted_color, 1)

func wait_timer():
	timer.set_paused(true)
	tween_timer_color(timer_waiting_color, 1)


func tween_timer_color(to, timespan):
	if timer_color_tween != null: timer_color_tween.kill()
	timer_color_tween = create_tween()
	var current_color = timer_label.get_theme_color("font_color")
	if current_color == null: current_color = Color(0, 0, 0)
	timer_color_tween.tween_method(override_timer_color.bind(), current_color, to, timespan)
	timer_color_tween.play()

func override_timer_color(color : Color):
	timer_label.add_theme_color_override("font_color", color)


func _on_ready_screen_start() -> void:
	await ready_screen.fade_out()
	ready_screen.call_deferred("hide")
	if GlobalSettings.game_state.reveal_queue.is_empty():
		resume_timer()
	else:
		_tile_map.resume()


func set_child_buttons_disabled(control : Control, blocking : bool = true):
	var new_focus_mode : FocusMode = FocusMode.FOCUS_NONE if blocking else FocusMode.FOCUS_ALL
	for button : Button in control.get_children().filter(func(c : Control): return c is Button):
		button.set_block_signals(blocking)
		button.focus_mode = new_focus_mode

func _on_ready_screen_visibility_changed() -> void:
	set_child_buttons_disabled(buttons, ready_screen.is_visible())
	if not ready_screen.is_visible():
		tile_map_area.grab_focus()


func _on_focus_entered() -> void:
	recenter_button.grab_focus()


func _on_tile_map_safe_tile_count_changed(_num_safe: int) -> void:
	if not _tile_map._revealing: SoundManager.tile_revealed()


func _on_loading_screen_cancel_requested():
	if initializing:
		loading_cancelled = true
		_tile_map.queue_free()
		await get_tree().process_frame
	return_to_main_menu()
