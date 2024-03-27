extends TileMap

const LAYERS = {
	"tiles" : 0,
	"contents" : 1,
	"mines" : 2,
	"flags" : 3
}

const TILES = {
	"obscured" : Vector2i(0, 0),
	"highlighted" : Vector2i(1, 0),
	"revealed" : Vector2i(2, 0),
	"exploded" : Vector2i(3, 0),
	0 : Vector2i(2, 0),
	1 : Vector2i(0, 1),
	2 : Vector2i(1, 1),
	3 : Vector2i(2, 1),
	4 : Vector2i(3, 1),
	5 : Vector2i(0, 2),
	6 : Vector2i(1, 2),
	7 : Vector2i(2, 2),
	8 : Vector2i(3, 2),
	"mine" : Vector2i(0, 3),
	"flag" : Vector2i(1, 3),
}

signal win
signal lose

signal bulk_reveal_started
signal bulk_reveal_ended

signal game_started
signal safe_tile_count_changed(num_safe : int)

signal flag_count_changed(num_flags : int)

@export_range(0, 1) var desktop_click_thresh : float = 0.25
@export_range(0, 1) var mobile_click_thresh : float = 0.15

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var click_timer: Timer = $ClickTimer
var input_is_click : bool = false

var mouse_pressed : bool = false

var hovered_tile : Vector2i
var hovered_is_valid : bool = false

var pressed_tile : Vector2i
var pressed_tile_is_valid : bool = false
var game_over : bool

var preparing : bool
var preparing_pointer : Vector2i

@export var max_reveal_batch_size : int = 500
var reveal_batch_size : int
var revealing : bool = false : get = is_revealing

var reveal_queue : Array[NumberedCell] = []
var reveal_queue_mutex : Mutex = Mutex.new()
var reveal_origin : Vector2i

var physics_queue_depleted : Semaphore
var waiting_on_queue_depletion : bool = false
var physics_batch_revealed : Semaphore
var waiting_on_batch_reveal : bool = false

const NO_ACTIVE_TASK : int = -1
var reveal_process_id : int = NO_ACTIVE_TASK

var game_state : GameState

func _init():
	update_batch_size()

func _enter_tree() -> void:
	GlobalSettings.settings.changed.connect(update_batch_size.bind())

func _exit_tree() -> void:
	call_deferred("remove_batch_size_updates")
	if reveal_process_id != NO_ACTIVE_TASK:
		while not WorkerThreadPool.is_task_completed(reveal_process_id):
			if preparing:
				preparing = false
			if revealing:
				revealing = false
			batch_revealed()
			queue_depleted()
			await get_tree().physics_frame

func remove_batch_size_updates():
	GlobalSettings.settings.changed.disconnect(update_batch_size.bind())

func update_batch_size():
	reveal_batch_size = max(1, max_reveal_batch_size * GlobalSettings.settings.get_processing_speed())

func _ready():
	if GlobalSettings.os_is_mobile():
		click_timer.set_wait_time(mobile_click_thresh)
	else:
		click_timer.set_wait_time(desktop_click_thresh)
	
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)

#region Grid Updating

func _process(_delta):
	if preparing:
		SceneLoader.set_loading_progress( float((preparing_pointer.x * game_state.grid_area.size.y) + preparing_pointer.y) / (game_state.grid_area.get_area()))


func _physics_process(_delta):
	if revealing:
		reveal_batch()
	elif preparing:
		prepare_batch()

func reveal_batch():
	var batch_coords : Array[NumberedCell]
	
	reveal_queue_mutex.lock()
	if reveal_queue.size() > 0:
		batch_coords = reveal_queue.slice(0, reveal_batch_size)
		
		reveal_queue = reveal_queue.slice(reveal_batch_size)
	else:
		queue_depleted()
		
	reveal_queue_mutex.unlock()
	
	batch_revealed()
	
	var index : int = 0
	while index < batch_coords.size():
		var to_reveal : NumberedCell = batch_coords[index]
		set_revealed(to_reveal.index, to_reveal.number)
		index += 1

func prepare_batch():
	if preparing_pointer.x >= game_state.grid_area.size.x:
		queue_depleted()
	else:
		var i : int = 0
		while i < reveal_batch_size:
			match game_state.tile_get_state(preparing_pointer):
				GameState.TileState.FLAGGED:
					set_obscured_texture(preparing_pointer)
					set_flag_texture(preparing_pointer)
				GameState.TileState.OBSCURED:
					set_obscured_texture(preparing_pointer)
				GameState.TileState.REVEALED:
					set_revealed_texture(preparing_pointer)
					set_number_texture(preparing_pointer, game_state.num_neighbour_mines(preparing_pointer))
			
			preparing_pointer += Vector2i.DOWN
			if preparing_pointer.y >= game_state.grid_area.size.y:
				preparing_pointer = Vector2i(preparing_pointer.x + 1, 0)
				if preparing_pointer.x >= game_state.grid_area.size.x:
					break
			i += 1

func wait_for_queue_depletion():
	physics_queue_depleted = Semaphore.new()
	waiting_on_queue_depletion = true
	physics_queue_depleted.wait()
	waiting_on_queue_depletion = false

func queue_depleted():
	if waiting_on_queue_depletion: physics_queue_depleted.post()

func wait_for_batch_completion():
	physics_batch_revealed = Semaphore.new()
	waiting_on_batch_reveal = true
	physics_batch_revealed.wait()
	waiting_on_batch_reveal = false

func batch_revealed():
	if waiting_on_batch_reveal: physics_batch_revealed.post()

func prepare_grid(initial_state : GameState):
	set_game_state(initial_state)
	
	preparing = true
	
	preparing_pointer = Vector2i.ZERO
	
	call_deferred("set_physics_process", true)
	call_deferred("set_process", true)
	
	if preparing:
		wait_for_queue_depletion()
		preparing = false
	
	call_deferred("set_physics_process", false)
	call_deferred("set_process", false)
	call_deferred("set_process_unhandled_input", true)

func set_game_state(state : GameState):
	state.prepare()
	game_state = state
	game_state.flag_count_changed.connect(on_flag_count_changed.bind())
	game_state.safe_tile_count_changed.connect(on_safe_tile_count_changed.bind())
	
	GlobalSettings.game_state = game_state

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
				if not game_over: toggle_flag(local_to_map(get_local_mouse_position()))
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
	pressed_tile = local_to_map(get_local_mouse_position())
	pressed_tile_is_valid = game_state.is_valid_tile(pressed_tile)
	if pressed_tile_is_valid:
		if (not game_over) and (not revealing):
			set_tile_pressed(pressed_tile)
			queue_click()

func on_mouse_released():
	if input_is_click and local_to_map(get_local_mouse_position()) == pressed_tile:
		cancel_click()
		reveal_tile(pressed_tile)
	else:
		pressed_tile = -Vector2i.ONE

func update_hover_status():
	var under_mouse = local_to_map(get_local_mouse_position())
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
	return Vector2(get_used_rect().size * self.get_tileset().get_tile_size()) * scale

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
	set_cell(LAYERS["tiles"], tile_index, 0, TILES.get("obscured"))

func set_highlighted_texture(tile_index : Vector2i):
	set_cell(LAYERS["tiles"], tile_index, 0, TILES.get("highlighted"))

func set_revealed_texture(tile_index : Vector2i):
	set_cell(LAYERS["tiles"], tile_index, 0, TILES.get("revealed"))

func set_exploded_texture(tile_index : Vector2i):
	set_cell(LAYERS["tiles"], tile_index, 0, TILES.get("exploded"))

func set_mine_texture(tile_index : Vector2i):
	set_cell(LAYERS["mines"], tile_index, 0, TILES.get("mine"))

func set_number_texture(tile_index : Vector2i, number : int):
	set_cell(LAYERS["contents"], tile_index, 0, TILES.get(number))

func set_flag_texture(tile_index : Vector2i):
	set_cell(LAYERS["flags"], tile_index, 0, TILES.get("flag"))

func remove_flag_texture(tile_index : Vector2i):
	erase_cell(LAYERS["flags"], tile_index)

func toggle_flag(index : Vector2i):
	if not game_state.is_valid_tile(index): return
	game_state.lock()
	if game_state.is_tile_flagged(index):
		game_state.set_tile_obscured(index)
		remove_flag_texture(index)
		decrement_flag_count()
	elif game_state.is_tile_obscured(index):
		game_state.set_tile_flagged(index)
		set_flag_texture(index)
		increment_flag_count()
	game_state.unlock()

# Returns true if the tile was revealed safely. Otherwise false.
func reveal_tile(index : Vector2i) -> bool:
	if not game_state.is_valid_tile(index): return false
	
	var revealed : bool = false
	
	game_state.lock()
	var tile_state = game_state.tile_get_state(index)
	
	if tile_state == GameState.TileState.FLAGGED:
		set_highlighted_texture(index)
		
	elif tile_state == GameState.TileState.OBSCURED:
		game_state.set_tile_revealed(index)
		if game_state.is_tile_mined(index):
			on_mine_exploded(index)
			game_state.unlock()
			return false
				
		on_tile_revealed_safely(index)
		revealed = true
		
	game_state.unlock()
	return revealed

func on_tile_revealed_safely(tile_index : Vector2i):
	var neighbour_mines : int = game_state.num_neighbour_mines(tile_index)
	
	set_revealed(tile_index, neighbour_mines)
	
	if(neighbour_mines == 0):
		reveal_origin = tile_index
		reveal_process_id = WorkerThreadPool.add_task(reveal_neighbour_cells.bind(tile_index), false, "Reveal neighbouring safe cells.")
		
	decrement_safe_tile_count()
	if game_state.get_num_safe_tiles() == 0:
		on_win()

func set_revealed(index, neighbour_mine_count):
	set_revealed_texture(index)
	set_number_texture(index, neighbour_mine_count)

func show_all_mines():
	set_layer_enabled(LAYERS["mines"], false)
	for coordinate in game_state.mine_coordinate_list:
		set_mine_texture(coordinate)
	set_layer_enabled(LAYERS["mines"], true)

func hide_all_mines():
	set_layer_enabled(LAYERS["mines"], false)
	for coordinate in game_state.mine_coordinate_list:
		set_obscured_texture(coordinate)
	set_layer_enabled(LAYERS["mines"], true)

func reveal_neighbour_cells(tile : Vector2i):
	revealing = true
	
	call_deferred("emit_signal", "bulk_reveal_started")
	
	var batch_queue : Array[Array] = [get_neighbours(tile)]
	call_deferred("set_physics_process", true)
	while (batch_queue.size() > 0) and revealing:
		var neighbours = batch_queue.pop_front()
		var to_reveal = []
		to_reveal.resize(8)
		var reveal_index = 0

		for index in neighbours:
			if game_state.is_tile_obscured(index):
				game_state.set_tile_revealed(index)
				decrement_safe_tile_count()
				to_reveal[reveal_index] = index
				reveal_index += 1

		to_reveal = to_reveal.slice(0, reveal_index)

		for index : Vector2i in to_reveal:
			if reveal_queue.size() >= reveal_batch_size:
				wait_for_batch_completion()
			
			var neighbour_mines : int = game_state.num_neighbour_mines(index)
			
			if neighbour_mines == 0:
				batch_queue.append(get_neighbours(index))
			
			reveal_queue_mutex.lock()
			reveal_queue.append(NumberedCell.new(index, neighbour_mines))
			reveal_queue_mutex.unlock()
			
	if revealing: 
		wait_for_queue_depletion()
		revealing = false
	
	call_deferred("set_physics_process", false)
	call_deferred("emit_signal", "bulk_reveal_ended")
	
	if game_state.get_num_safe_tiles() == 0:
		call_deferred("on_win")
	
	reveal_process_id = NO_ACTIVE_TASK

func get_neighbours(index : Vector2i) -> Array[Vector2i]:
	return get_neighbour_coordinates(index).filter(game_state.is_valid_tile.bind())

func get_neighbour_coordinates(coordinate : Vector2i):
	var neighbours : Array[Vector2i] = []
	var top_left = coordinate - Vector2i.ONE
	var bottom_right = coordinate + Vector2i(2, 2)
	
	var coord_x : bool
	
	neighbours.resize(8)
	var index : int = 0
	for x : int in range(top_left.x, bottom_right.x):
		coord_x = (coordinate.x == x)
		for y : int in range(top_left.y, bottom_right.y):
			if coord_x and (coordinate.y == y): continue
			neighbours[index] = Vector2i(x, y)
			index += 1
	
	return neighbours

func is_revealing() -> bool:
	return revealing

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
	game_state.set_num_safe_tiles(game_state.get_num_safe_tiles() - 1)

func _on_click_timer_timeout() -> void:
	input_is_click = false
	set_tile_unpressed(pressed_tile)

func on_win():
	game_over = true
	call_deferred("emit_signal", "win")
	
	show_all_mines()
	animation_player.play("fade_in_mines")


func _on_bulk_reveal_started() -> void:
	animation_player.play("fade_out_contents")

func _on_bulk_reveal_ended() -> void:
	if animation_player.is_playing() and animation_player.current_animation_position == 0:
		animation_player.stop()
	else:
		animation_player.play_backwards("fade_out_contents")

class NumberedCell:
	var index : Vector2i
	var number : int
	
	func _init(index : Vector2i, number : int) -> void:
		self.index = index
		self.number = number

func sort_numbered_cell(first : NumberedCell, second : NumberedCell, from : Vector2i) -> bool:
	return sort_by_dist(first.index, second.index, from)

func sort_by_dist(first : Vector2i, second : Vector2i, from : Vector2i) -> bool:
	return distance(from, first) < distance(from, second)

func distance(first : Vector2i, second : Vector2i) -> float:
	return (second - first).length()



func _on_safe_tile_count_changed(num_safe: int) -> void:
	game_state.first_tile_revealed = true
	game_started.emit()

func get_flag_count() -> int:
	return game_state.get_num_flags()
