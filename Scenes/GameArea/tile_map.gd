extends Node2D

const TILE_MAP : TileSet = preload("res://Resources/tile_map.tres")
const NUMBER_LAYER : PackedScene = preload("res://Scenes/GameArea/number_layer.tscn")
const MINE_LAYER : PackedScene = preload("res://Scenes/GameArea/mine_layer.tscn")

const OBSCURED_TILE := Vector2i(0, 0)
const HIGHLIGHTED_TILE := Vector2i(1, 0)
const REVEALED_TILE := Vector2i(2, 0)
const EXPLODED_TILE := Vector2i(3, 0)
const MINE_TILE := Vector2i(0, 3)
const FLAG_TILE := Vector2i(1, 3)

const MIN_PROCESSING_SPEED := 0.005
const PREPARE_TIME_LIMIT_MICROSEC := 1_000_000 / 120.0

const NUMBER_TILES := [
	Vector2i(2, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(3, 1),
	Vector2i(0, 2),
	Vector2i(1, 2),
	Vector2i(2, 2),
	Vector2i(3, 2),
]

signal win
signal lose

signal bulk_reveal_started
signal bulk_reveal_ended

signal game_started
signal safe_tile_count_changed(num_safe : int)

signal flag_count_changed(num_flags : int)

@export_range(0, 1) var desktop_click_thresh : float = 0.25
@export_range(0, 1) var mobile_click_thresh : float = 0.15

@onready var click_timer: Timer = $ClickTimer

var input_is_click : bool = false

var mouse_pressed : bool = false

var hovered_tile : Vector2i
var hovered_is_valid : bool = false

var pressed_tile : Vector2i
var pressed_tile_is_valid : bool = false
var game_over : bool

var preparing : bool
var preparing_index : int = 0

var tile_layer : TileMapLayer
var number_layer : TileMapLayer
var mine_layer : TileMapLayer
var flag_layer : TileMapLayer

var game_state : GameState : set = set_game_state
var _max_tile_updates_per_frame : int

var _revealing : bool = false

var _tile_update_queue : Array[Vector2i]
var _update_queue_mutex : Mutex = Mutex.new()
var _currently_revealing : Array[Vector2i] = []
var _currently_revealing_index : int = 0
var _reveal_worker_thread_id : int

func _init():
	tile_layer = TileMapLayer.new()
	flag_layer = TileMapLayer.new()
	number_layer = NUMBER_LAYER.instantiate()
	mine_layer = MINE_LAYER.instantiate()
	
	tile_layer.collision_enabled = false
	flag_layer.collision_enabled = false
	tile_layer.collision_visibility_mode = TileMapLayer.DEBUG_VISIBILITY_MODE_FORCE_HIDE
	flag_layer.collision_visibility_mode = TileMapLayer.DEBUG_VISIBILITY_MODE_FORCE_HIDE
	
	tile_layer.navigation_enabled = false
	flag_layer.navigation_enabled = false
	tile_layer.navigation_visibility_mode = TileMapLayer.DEBUG_VISIBILITY_MODE_FORCE_HIDE
	flag_layer.navigation_visibility_mode = TileMapLayer.DEBUG_VISIBILITY_MODE_FORCE_HIDE
	
	tile_layer.name = "TileLayer"
	number_layer.name = "NumberLayer"
	mine_layer.name = "MineLayer"
	flag_layer.name = "FlagLayer"
	
	tile_layer.tile_set = TILE_MAP
	number_layer.tile_set = TILE_MAP
	mine_layer.tile_set = TILE_MAP
	flag_layer.tile_set = TILE_MAP
	
	add_child(tile_layer, false, INTERNAL_MODE_FRONT)
	add_child(number_layer, false, INTERNAL_MODE_FRONT)
	add_child(mine_layer, false, INTERNAL_MODE_FRONT)
	add_child(flag_layer, false, INTERNAL_MODE_FRONT)
	
	if game_state:
		update_full_map()
	
	update_tiles_per_frame()


func _enter_tree() -> void:
	GlobalSettings.settings.changed.connect(update_tiles_per_frame.bind())

func _exit_tree() -> void:
	if _revealing:
		_revealing = false
		if not WorkerThreadPool.is_task_completed(_reveal_worker_thread_id):
			cancel_free()
			WorkerThreadPool.wait_for_task_completion(_reveal_worker_thread_id)
			queue_free()

func remove_batch_size_updates():
	GlobalSettings.settings.changed.disconnect(update_tiles_per_frame().bind())

func update_tiles_per_frame():
	if game_state:
		_max_tile_updates_per_frame = game_state.grid_area.get_area() if GlobalSettings.settings.get_animation_duration() == 0 else maxi(1, roundi(game_state.grid_area.get_area() / (GlobalSettings.settings.get_animation_duration() * 60.0)))

func _ready():
	
	if GlobalSettings.os_is_mobile():
		click_timer.set_wait_time(mobile_click_thresh)
	else:
		click_timer.set_wait_time(desktop_click_thresh)
	
	set_process(false)
	set_physics_process(false)
	#set_process_unhandled_input(false)


func _process(delta: float) -> void:
	var num_revealed : int = 0
	while num_revealed < _max_tile_updates_per_frame:
		if _currently_revealing_index >= _currently_revealing.size():
			if _tile_update_queue.is_empty():
				break
			_update_queue_mutex.lock()
			var slice_end_index := mini(_max_tile_updates_per_frame, _tile_update_queue.size())
			_currently_revealing = _tile_update_queue.slice(0, slice_end_index)
			_tile_update_queue = _tile_update_queue.slice(slice_end_index)
			_update_queue_mutex.unlock()
			_currently_revealing_index = 0
		update_tile(_currently_revealing[_currently_revealing_index])
		_currently_revealing_index += 1
		num_revealed += 1
	
	if _tile_update_queue.is_empty() and WorkerThreadPool.is_task_completed(_reveal_worker_thread_id) and _currently_revealing_index >= _currently_revealing.size():
		set_process(false)
		_revealing = false
		WorkerThreadPool.wait_for_task_completion(_reveal_worker_thread_id)
		bulk_reveal_ended.emit()
		_check_win()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_ENTER | NOTIFICATION_WM_MOUSE_EXIT:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): update_hover_status()

func resume() -> void: 
	if not game_state.reveal_queue.is_empty():
		_start_reveal_chain_reaction()


func stop() -> void: 
	if _revealing:
		set_process(false)
		if not WorkerThreadPool.is_task_completed(_reveal_worker_thread_id):
			_revealing = false
			WorkerThreadPool.wait_for_task_completion(_reveal_worker_thread_id)

#region Grid Updating


func _populate_reveal_queue():
	_revealing = true
	
	call_deferred("emit_signal", "bulk_reveal_started")
	
	call_deferred("set_process", true)
	
	_set_block_map_signals(true)
	
	game_state.set_block_signals(true)
	
	var reveal_queue : Array[Vector2i] = game_state.reveal_queue.duplicate(true)
	var buffer_index : int = 0
	var num_tiles_updated_total : int = 0
	var num_tiles_updated_frame : int = 0
	
	while _revealing and not is_queued_for_deletion():
		if buffer_index >= reveal_queue.size():
			game_state.reveal_queue.clear()
			break
		
		var to_reveal = reveal_queue[buffer_index]
		buffer_index += 1
		
		if not game_state.is_tile_obscured(to_reveal):
			continue
		
		game_state.set_tile_revealed(to_reveal)
		decrement_safe_tile_count()
		
		var neighbour_mines : int = game_state.num_neighbour_mines(to_reveal)
		
		if neighbour_mines == 0:
			if not _revealing or is_queued_for_deletion():
				break
			reveal_queue = reveal_queue.slice(buffer_index)
			buffer_index = 0
			reveal_queue.append_array(get_neighbours(to_reveal))
		
		_update_queue_mutex.lock()
		_tile_update_queue.append(to_reveal)
		_update_queue_mutex.unlock()
	
	game_state.reveal_queue = reveal_queue
	
	game_state.set_block_signals(false)
	
	#call_deferred("set_physics_process", false)



func _set_block_map_signals(enabled : bool = true):
	tile_layer.set_block_signals(enabled)
	number_layer.set_block_signals(enabled)
	mine_layer.set_block_signals(enabled)
	flag_layer.set_block_signals(enabled)


func update_full_map():
	var max_x : int = game_state.grid_area.size.x
	var max_y : int = game_state.grid_area.size.y
	var x : int = 0
	var y : int = 0
	preparing_index = 0
	var start_time := Time.get_ticks_usec()
	while y < max_y:
		if (Time.get_ticks_usec() - start_time) >= PREPARE_TIME_LIMIT_MICROSEC:
			if is_queued_for_deletion():
				return
			SceneLoader.set_loading_progress( float(preparing_index) / (max_x * max_y))
			await get_tree().process_frame
			if is_queued_for_deletion():
				return
			start_time = Time.get_ticks_usec()
		
		var index := Vector2i(x, y)
		update_tile(index)
		
		x += 1
		if x == max_x:
			x = 0
			y += 1
		
		preparing_index += 1

func set_game_state(state : GameState):
	state.prepare()
	game_state = state
	game_state.flag_count_changed.connect(on_flag_count_changed.bind())
	game_state.safe_tile_count_changed.connect(on_safe_tile_count_changed.bind())
	update_tiles_per_frame()
	GlobalSettings.game_state = game_state

func update_tile(index : Vector2i):
	match game_state.tile_get_state(index):
		GameState.TileState.FLAGGED:
			set_obscured_texture(index)
			set_flag_texture(index)
		GameState.TileState.OBSCURED:
			set_obscured_texture(index)
		GameState.TileState.REVEALED:
			set_revealed_texture(index)
			set_number_texture(index, game_state.num_neighbour_mines(index))

#endregion


#region Input Handling
func _unhandled_input(event):
	if event is InputEventMouse:
		if event is InputEventMouseButton:
			if event.is_action("reveal_cell"):
				mouse_pressed = event.is_pressed()
				if mouse_pressed:
					on_mouse_pressed()
				else:
					on_mouse_released()
			elif event.is_action_pressed("toggle_flag"):
				if not game_over: toggle_flag(flag_layer.local_to_map(get_local_mouse_position()))
			else:
				return
		elif event is InputEventMouseMotion:
			if not mouse_pressed: update_hover_status()
	elif OS.is_debug_build():
		if event is InputEventKey:
			var e : InputEventKey = event
			if e.keycode == KEY_F1:
				show_all_mines()
			elif e.keycode == KEY_F2:
				on_win()

func on_mouse_pressed():
	pressed_tile = tile_layer.local_to_map(get_local_mouse_position())
	pressed_tile_is_valid = game_state.is_valid_tile(pressed_tile)
	if pressed_tile_is_valid:
		if (not game_over) and (not _revealing):
			set_tile_pressed(pressed_tile)
			queue_click()

func on_mouse_released():
	if input_is_click and tile_layer.local_to_map(get_local_mouse_position()) == pressed_tile:
		cancel_click()
		reveal_tile(pressed_tile)
	else:
		pressed_tile = -Vector2i.ONE

func update_hover_status():
	var under_mouse = tile_layer.local_to_map(get_local_mouse_position())
	if under_mouse == hovered_tile: return
	
	if hovered_is_valid and not game_state.is_tile_revealed(hovered_tile):
		set_obscured_texture(hovered_tile)
		
	hovered_tile = under_mouse
	hovered_is_valid = game_state.is_valid_tile(hovered_tile)
	if hovered_is_valid and not game_state.is_tile_revealed(hovered_tile):
		if mouse_pressed and hovered_tile == pressed_tile:
			set_revealed_texture(hovered_tile)
		else:
			set_highlighted_texture(hovered_tile)

func queue_click():
	input_is_click = true
	click_timer.start()

func cancel_click():
	if not input_is_click: return
	click_timer.stop()
	input_is_click = false
	set_tile_unpressed(pressed_tile)
	
#endregion

func fit_to_rect(area : Rect2):
	var adjusted_area = Rect2(area)
	
	if GlobalSettings.centered:
		var offset = area.size / 2
		adjusted_area.position -= offset
		
	var center = adjusted_area.position + (adjusted_area.size / 2.0)
	
	#Ensures cells are square
	var ideal_tile_sizes = adjusted_area.size / Vector2(game_state.grid_area.size)
	if ideal_tile_sizes.x <= ideal_tile_sizes.y:
		ideal_tile_sizes.y = ideal_tile_sizes.x
	else:
		ideal_tile_sizes.x = ideal_tile_sizes.y
	var equal_sides = Vector2(game_state.grid_area.size) * ideal_tile_sizes
	adjusted_area.size = equal_sides
	
	match GlobalSettings.h_alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			pass
		HORIZONTAL_ALIGNMENT_CENTER:
			adjusted_area.position.x = center.x - (adjusted_area.size.x / 2)
		HORIZONTAL_ALIGNMENT_RIGHT:
			adjusted_area.position.x = (area.position.x + area.size.x) - (adjusted_area.size.x / 2)
	
	match GlobalSettings.v_alignment:
		VERTICAL_ALIGNMENT_TOP:
			pass
		VERTICAL_ALIGNMENT_CENTER:
			adjusted_area.position.y = center.y - (adjusted_area.size.y / 2)
		VERTICAL_ALIGNMENT_BOTTOM:
			adjusted_area.position.y = (area.position.y + area.size.y) - (adjusted_area.size.y / 2)

	var relative_scale = adjusted_area.size / get_size()
	self.position = adjusted_area.position
	self.scale *= relative_scale

func get_size() -> Vector2:
	return Vector2(tile_layer.get_used_rect().size * tile_layer.get_tile_set().get_tile_size()) * scale

func set_tile_pressed(index : Vector2i):
	if game_state.is_valid_tile(index):
		if game_state.is_tile_obscured(index):
			set_revealed_texture(index)

func set_tile_unpressed(index : Vector2i):
	if game_state.is_valid_tile(index):
		if game_state.is_tile_obscured(index):
			if index == hovered_tile:
				set_highlighted_texture(index)
			else:
				set_obscured_texture(index)

func two_dimensional_to_linear_index(index : Vector2i) -> int:
	return index.x * GlobalSettings.settings.get_columns() + index.y


func on_mine_exploded(index : Vector2i):
	game_over = true
	set_mine_texture(index)
	set_exploded_texture(index)
	lose.emit()

func set_obscured_texture(tile_index : Vector2i):
	tile_layer.set_cell(tile_index, 0, OBSCURED_TILE)

func set_highlighted_texture(tile_index : Vector2i):
	tile_layer.set_cell(tile_index, 0, HIGHLIGHTED_TILE)

func set_revealed_texture(tile_index : Vector2i):
	tile_layer.set_cell(tile_index, 0, REVEALED_TILE)

func set_exploded_texture(tile_index : Vector2i):
	tile_layer.set_cell(tile_index, 0, EXPLODED_TILE)

func set_mine_texture(tile_index : Vector2i):
	mine_layer.set_cell(tile_index, 0, MINE_TILE)

func set_number_texture(tile_index : Vector2i, number : int):
	number_layer.set_cell(tile_index, 0, NUMBER_TILES[number])

func set_flag_texture(tile_index : Vector2i):
	flag_layer.set_cell(tile_index, 0, FLAG_TILE)

func remove_flag_texture(tile_index : Vector2i):
	flag_layer.erase_cell(tile_index)

func toggle_flag(index : Vector2i):
	if not game_state.is_valid_tile(index): return
	if game_state.is_tile_flagged(index):
		game_state.set_tile_obscured(index)
		remove_flag_texture(index)
		decrement_flag_count()
	elif game_state.is_tile_obscured(index):
		game_state.set_tile_flagged(index)
		set_flag_texture(index)
		increment_flag_count()

# Returns true if the tile was revealed safely. Otherwise false.
func reveal_tile(index : Vector2i) -> bool:
	if not game_state.is_valid_tile(index): return false
	
	var revealed : bool = false
	
	var tile_state = game_state.tile_get_state(index)
	
	if tile_state == GameState.TileState.FLAGGED:
		set_highlighted_texture(index)
		
	elif tile_state == GameState.TileState.OBSCURED:
		game_state.set_tile_revealed(index)
		if game_state.is_tile_mined(index):
			if (not game_state.first_tile_revealed) and GlobalSettings.settings.get_first_tile_safe():
				game_state.change_mine_position(index, game_state.alternative_mine)
			else:
				on_mine_exploded(index)
				return false
				
		on_tile_revealed_safely(index)
		revealed = true
		
	return revealed

func on_tile_revealed_safely(tile_index : Vector2i):
	var neighbour_mines : int = game_state.num_neighbour_mines(tile_index)
	
	set_revealed(tile_index, neighbour_mines)
	decrement_safe_tile_count()
	
	if(neighbour_mines == 0):
		GlobalSettings.game_state.reveal_queue = get_neighbours(tile_index)
		_start_reveal_chain_reaction()
	else:
		_check_win()

func _start_reveal_chain_reaction() -> void:
	_reveal_worker_thread_id = WorkerThreadPool.add_task(_populate_reveal_queue, true, "Chain reveal thread")

func set_revealed(index, neighbour_mine_count):
	set_revealed_texture(index)
	set_number_texture(index, neighbour_mine_count)

func show_all_mines():
	mine_layer.set_enabled(false)
	for coordinate in game_state.mine_coordinate_list:
		set_mine_texture(coordinate)
	mine_layer.set_enabled(true)

func hide_all_mines():
	mine_layer.set_enabled(false)
	for coordinate in game_state.mine_coordinate_list:
		set_obscured_texture(coordinate)
	mine_layer.set_enabled(true)

func get_neighbours(coordinate : Vector2i) -> Array[Vector2i]:
	var neighbours : Array[Vector2i] = []
	
	var grid_position := game_state.grid_area.position
	var grid_size := game_state.grid_area.size
	var x_coords := range(maxi(coordinate.x - 1, grid_position.x), mini(coordinate.x + 2, grid_position.x + grid_size.x))
	var y_coords := range(maxi(coordinate.y - 1, grid_position.y), mini(coordinate.y + 2, grid_position.y + grid_size.y))
	
	neighbours.resize((x_coords.size() * y_coords.size()) - 1)
	
	var center_x : bool
	var index : int = 0
	for x : int in x_coords:
		center_x = (coordinate.x == x)
		for y : int in y_coords:
			if center_x and (coordinate.y == y): continue
			neighbours[index] = Vector2i(x, y)
			index += 1
	
	return neighbours

func is_revealing() -> bool:
	return _revealing

func on_flag_placed():
	increment_flag_count()

func on_flag_removed():
	decrement_flag_count()

func is_valid_tile(index : Vector2i) -> bool:
	return game_state.is_valid_tile(index)

func get_num_columns() -> int:
	return game_state.grid_area.size.x

func get_num_rows() -> int:
	return game_state.grid_area.size.y


func increment_flag_count():
	game_state.set_num_flags(game_state.num_flags + 1)

func decrement_flag_count():
	game_state.set_num_flags(game_state.num_flags - 1)

func on_flag_count_changed(num_flags : int):
	flag_count_changed.emit(num_flags)

func on_safe_tile_count_changed(num_safe : int):
	call_deferred_thread_group("emit_signal", "safe_tile_count_changed", num_safe)

func decrement_safe_tile_count():
	game_state.num_safe_tiles -= 1

func _on_click_timer_timeout() -> void:
	input_is_click = false
	set_tile_unpressed(pressed_tile)


func _check_win():
	if game_state.get_num_safe_tiles() == 0:
			on_win()


func on_win():
	game_over = true
	win.emit()
	
	mine_layer.fade_in_mines()
	show_all_mines()


func _on_bulk_reveal_started() -> void:
	number_layer.fade_out_numbers()

func _on_bulk_reveal_ended() -> void:
	if number_layer.animation_player.is_playing() and is_equal_approx(number_layer.animation_player.current_animation_position, 0):
		number_layer.stop_animation()
	else:
		number_layer.fade_in_numbers()

class NumberedCell:
	var index : Vector2i
	var value : int
	
	func _init(idx : Vector2i, number : int) -> void:
		self.index = idx
		self.value = number


func _on_safe_tile_count_changed(_num_safe: int) -> void:
	game_state.first_tile_revealed = true
	game_started.emit()

func get_flag_count() -> int:
	return game_state.get_num_flags()
