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

enum TileState{
	OBSCURED,
	FLAGGED,
	REVEALED
}

signal win
signal lose

signal bulk_reveal_started
signal bulk_reveal_ended

signal game_started
signal tile_revealed

signal flag_count_changed(num_flags : int)

@onready var click_timer: Timer = $ClickTimer
var is_click : bool = false

var mouse_pressed : bool = false

var hovered_tile : Vector2i
var hovered_is_valid : bool = false

var pressed_tile : Vector2i
var pressed_tile_is_valid : bool = false

var num_safe_cells : int
var flags_placed : int

var grid_area : Rect2i
var num_mines : int

var state_map
var mine_map
var mine_coordinate_list

var game_over : bool

var preparing : bool
var preparing_pointer : Vector2i

@export var reveal_batch_size : int = 24
var revealing : bool = false : get = is_revealing

var count_mutex : Mutex = Mutex.new()
var state_map_mutex : Mutex = Mutex.new()

var reveal_queue : Array[Vector2i] = []
var reveal_queue_number_label : Array[int] = []
var reveal_queue_mutex : Mutex = Mutex.new()

var reveal_queue_depleted : Semaphore
var reveal_thread_active : bool = false
var batch_revealed : Semaphore
var waiting_on_batch_reveal : bool = false

const NO_ACTIVE_TASK : int = -1
var reveal_process_id : int = NO_ACTIVE_TASK

func _init():
	grid_area = Global.get_grid_rect()
	num_mines = Global.get_mines()

func _ready():
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)

#region Grid Updating

func _process(_delta):
	if preparing:
		SceneLoader.set_loading_screen_progress( float((preparing_pointer.x * grid_area.size.y) + preparing_pointer.y) / (grid_area.size.x * grid_area.size.y))


func _physics_process(_delta):
	
	if revealing:
		var batch_coords : Array[Vector2i]
		var batch_labels : Array[int]
		
		reveal_queue_mutex.lock()
		if reveal_queue.size() > 0:
			batch_coords = reveal_queue.slice(0, reveal_batch_size)
			batch_labels = reveal_queue_number_label.slice(0, reveal_batch_size)
			
			reveal_queue = reveal_queue.slice(reveal_batch_size)
			reveal_queue_number_label = reveal_queue_number_label.slice(reveal_batch_size)
		elif not reveal_thread_active:
			reveal_queue_depleted.post()
			
		reveal_queue_mutex.unlock()
		
		if waiting_on_batch_reveal: batch_revealed.post()
		
		var index : int = 0
		while index < batch_coords.size():
			var to_reveal : Vector2i = batch_coords[index]
			var number_label : int = batch_labels[index]
			set_revealed(to_reveal, number_label)
			index += 1
		
	elif preparing:
		if preparing_pointer.x >= grid_area.size.x:
			reveal_queue_depleted.post()
		else:
			for i in range(reveal_batch_size):
				set_obscured_texture(preparing_pointer)
				preparing_pointer += Vector2i(0, 1)
				if preparing_pointer.y >= grid_area.size.y:
					preparing_pointer = Vector2i(preparing_pointer.x + 1, 0)
					if preparing_pointer.x >= grid_area.size.x:
						break

func prepare_grid():
	var num_columns = grid_area.size.x
	var num_rows = grid_area.size.y
	var num_cells = grid_area.size.x * grid_area.size.y
	if num_mines >= num_cells:
		push_error("Cannot place %i mines in %i cells.\nPlacing %i mines instead." % [num_mines, num_cells, num_cells - 1])
		num_mines = num_cells - 1
	
	num_safe_cells = num_cells - num_mines
	
	#var initial_state : TileMapPattern = TileMapPattern.new()
	#initial_state.set_size(grid_area.size)
	#var obscured_texture = TILES.get("obscured")
	
	var mine_locations = generate_mine_locations(num_cells)
	mine_locations.sort()
	
	mine_coordinate_list = []
	mine_coordinate_list.resize(num_mines)
	
	var linear_index : int = -1
	var mine_index = 0
	var next_mine : int = mine_locations[mine_index]
	state_map = []
	state_map.resize(num_columns)
	mine_map = []
	mine_map.resize(num_columns)
	for column in range(num_columns):
		state_map[column] = []
		state_map[column].resize(num_rows)
		mine_map[column] = []
		mine_map[column].resize(num_rows)
		for row in range(num_rows):
			#var index_2d = Vector2i(column, row)
			
			linear_index += 1
			var is_mine : bool = (linear_index == next_mine)
			mine_map[column][row] = is_mine
			state_map[column][row] = TileState.OBSCURED
			#set_obscured_texture(index_2d)
			#initial_state.set_cell(index_2d, 0, obscured_texture, 0)
			
			if is_mine:
				mine_coordinate_list[mine_index] = Vector2i(column, row)#index_2d
				mine_index += 1
				if mine_index < mine_locations.size():
					next_mine = mine_locations[mine_index]
	
	preparing_pointer = Vector2i.ZERO
	preparing = true
	reveal_thread_active = true
	reveal_queue_depleted = Semaphore.new()
	call_deferred("set_physics_process", true)
	call_deferred("set_process", true)
	reveal_thread_active = false
	reveal_queue_depleted.wait()
	preparing = false
	call_deferred("set_physics_process", false)
	call_deferred("set_process", false)
	call_deferred("set_process_unhandled_input", true)
	#call_deferred("set_pattern", LAYERS.get("tiles"), Vector2i.ZERO, initial_state)
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
	#elif event is InputEventKey:
		#var e : InputEventKey = event
		#if e.keycode == KEY_F1:
			#show_all_mines()
		#elif e.keycode == KEY_F2:
			#on_win()


func on_mouse_pressed():
	pressed_tile = local_to_map(get_local_mouse_position())
	pressed_tile_is_valid = is_valid_tile_index(pressed_tile)
	if pressed_tile_is_valid:
		if (not game_over) and (not revealing):
			set_tile_pressed(pressed_tile)
			queue_click()

func on_mouse_released():
	if is_click and local_to_map(get_local_mouse_position()) == pressed_tile:
		cancel_click()
		if reveal_tile(pressed_tile):
			tile_revealed.emit()
	else:
		pressed_tile = -Vector2i.ONE

func update_hover_status():
	var under_mouse = local_to_map(get_local_mouse_position())
	if under_mouse == hovered_tile: return
	if hovered_is_valid:
		state_map_mutex.lock()
		if state_map[hovered_tile.x][hovered_tile.y] != TileState.REVEALED: set_obscured_texture(hovered_tile)
		state_map_mutex.unlock()
		
	hovered_tile = under_mouse
	hovered_is_valid = is_valid_tile_index(hovered_tile)
	state_map_mutex.lock()
	if hovered_is_valid and (state_map[hovered_tile.x][hovered_tile.y] != TileState.REVEALED):
		if mouse_pressed and hovered_tile == pressed_tile:
			set_revealed_texture(hovered_tile)
		else:
			set_highlighted_texture(hovered_tile)
	state_map_mutex.unlock()

func queue_click():
	is_click = true
	click_timer.start()

func cancel_click():
	if not is_click: return
	click_timer.stop()
	is_click = false
	set_tile_unpressed(pressed_tile)
	
#endregion

func fit_to_rect(area : Rect2):
	var adjusted_area = Rect2(area)
	
	if Global.centered:
		var offset = area.size / 2
		adjusted_area.position -= offset
		
	var center = adjusted_area.position + (adjusted_area.size / 2.0)
	
	#Ensures cells are square
	var ideal_tile_sizes = adjusted_area.size / Vector2(grid_area.size)
	if ideal_tile_sizes.x <= ideal_tile_sizes.y:
		ideal_tile_sizes.y = ideal_tile_sizes.x
	else:
		ideal_tile_sizes.x = ideal_tile_sizes.y
	var equal_sides = Vector2(grid_area.size) * ideal_tile_sizes
	adjusted_area.size = equal_sides
	
	match Global.h_alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			pass
		HORIZONTAL_ALIGNMENT_CENTER:
			adjusted_area.position.x = center.x - (adjusted_area.size.x / 2)
		HORIZONTAL_ALIGNMENT_RIGHT:
			adjusted_area.position.x = (area.position.x + area.size.x) - (adjusted_area.size.x / 2)
	
	match Global.v_alignment:
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

func _exit_tree():
	if reveal_process_id != NO_ACTIVE_TASK:
		if preparing:
			preparing = false
		if revealing:
			revealing = false
		if reveal_queue_depleted: reveal_queue_depleted.post()
		if batch_revealed: batch_revealed.post()
		WorkerThreadPool.wait_for_task_completion(reveal_process_id)

func set_tile_pressed(index : Vector2i):
	if is_valid_tile_index(index):
		state_map_mutex.lock()
		if state_map[index.x][index.y] == TileState.OBSCURED:
			set_revealed_texture(index)
		state_map_mutex.unlock()

func set_tile_unpressed(index : Vector2i):
	if is_valid_tile_index(index):
		state_map_mutex.lock()
		if state_map[index.x][index.y] == TileState.OBSCURED:
			if index == hovered_tile:
				set_highlighted_texture(index)
			else:
				set_obscured_texture(index)
		state_map_mutex.unlock()

func linear_to_two_dimensional_index(index: int) -> Vector2i:
	var x : int = index / grid_area.size.y
	var y : int = (index - x * grid_area.size.y) % grid_area.size.x
	return Vector2i(x, y)

func two_dimensional_to_linear_index(index : Vector2i) -> int:
	return index.x * Global.get_columns() + index.y


func on_mine_exploded(index : Vector2i):
	game_over = true
	set_mine_texture(index)
	set_exploded_texture(index)
	lose.emit()

func set_obscured_texture(tile_index : Vector2i):
	set_cell(LAYERS.get("tiles"), tile_index, 0, TILES.get("obscured"))

func set_highlighted_texture(tile_index : Vector2i):
	set_cell(LAYERS.get("tiles"), tile_index, 0, TILES.get("highlighted"))

func set_revealed_texture(tile_index : Vector2i):
	set_cell(LAYERS.get("tiles"), tile_index, 0, TILES.get("revealed"))

func set_exploded_texture(tile_index : Vector2i):
	set_cell(LAYERS.get("tiles"), tile_index, 0, TILES.get("exploded"))

func set_mine_texture(tile_index : Vector2i):
	set_cell(LAYERS.get("mines"), tile_index, 0, TILES.get("mine"))

func set_number_texture(tile_index : Vector2i, number : int):
	set_cell(LAYERS.get("contents"), tile_index, 0, TILES.get(number))

func set_flag_texture(tile_index : Vector2i):
	set_cell(LAYERS.get("flags"), tile_index, 0, TILES.get("flag"))

func remove_flag_texture(tile_index : Vector2i):
	erase_cell(LAYERS.get("flags"), tile_index)

func toggle_flag(index : Vector2i):
	if not is_valid_tile_index(index): return
	state_map_mutex.lock()
	if state_map[index.x][index.y] == TileState.FLAGGED:
		state_map[index.x][index.y] = TileState.OBSCURED
		remove_flag_texture(index)
		decrement_flag_count()
	elif state_map[index.x][index.y] == TileState.OBSCURED:
		state_map[index.x][index.y] = TileState.FLAGGED
		set_flag_texture(index)
		increment_flag_count()
	state_map_mutex.unlock()

# Returns true if the tile was revealed safely. Otherwise false.
func reveal_tile(index : Vector2i) -> bool:
	if not is_valid_tile_index(index): return false
	
	var revealed : bool = false
	
	state_map_mutex.lock()
	var tile_state = state_map[index.x][index.y]
	if tile_state == TileState.FLAGGED:
		set_highlighted_texture(index)
	elif state_map[index.x][index.y] == TileState.OBSCURED:
		state_map[index.x][index.y] = TileState.REVEALED
		if mine_map[index.x][index.y]:
			on_mine_exploded(index) 
		elif tile_state == TileState.OBSCURED:
			on_tile_revealed_safely(index)
			revealed = true
	state_map_mutex.unlock()
	return revealed

func is_valid_tile_index(index : Vector2i) -> bool:
	return grid_area.has_point(index)

func on_tile_revealed_safely(tile_index : Vector2i):
	var neighbour_mines : int = num_neighbour_mines(tile_index)
	
	set_revealed(tile_index, neighbour_mines)
	
	if(neighbour_mines == 0):
		reveal_process_id = WorkerThreadPool.add_task(reveal_neighbour_cells.bind(tile_index), false, "Reveal neighbouring safe cells.")
		
	decrement_safe_tile_count()
	if num_safe_cells == 0:
		on_win()

func set_revealed(index, num_neighbour_mines):
	set_revealed_texture(index)
	set_number_texture(index, num_neighbour_mines)

func generate_mine_locations(num_cells : int):
	var coordinates : Array = range(num_cells)
	coordinates.shuffle()
	return coordinates.slice(0, num_mines)

func num_neighbour_mines(tile : Vector2i) -> int:
	var neighbour_mines : int = 0
	for column in range(max(tile.x - 1, 0), min(tile.x + 2, Global.get_columns())):
		for row in range(max(tile.y - 1, 0), min(tile.y + 2, Global.get_rows())):
			if mine_map[column][row]: neighbour_mines += 1
	return neighbour_mines

func show_all_mines():
	set_layer_enabled(LAYERS["mines"], false)
	for coordinate in mine_coordinate_list:
		set_mine_texture(coordinate)
	set_layer_enabled(LAYERS["mines"], true)

func hide_all_mines():
	set_layer_enabled(LAYERS["mines"], false)
	for coordinate in mine_coordinate_list:
		set_obscured_texture(coordinate)
	set_layer_enabled(LAYERS["mines"], true)

func reveal_neighbour_cells(tile : Vector2i):
	reveal_thread_active = true
	revealing = true
	
	call_deferred("emit_signal", "bulk_reveal_started")
	
	reveal_queue_depleted = Semaphore.new()
	batch_revealed = Semaphore.new()
	
	var batch_queue : Array[Array] = [get_neighbour_coordinates(tile)]
	call_deferred("set_physics_process", true)
	while (batch_queue.size() > 0) and revealing:
		var neighbours = batch_queue.pop_front()
		var to_reveal = []
		to_reveal.resize(8)
		var reveal_index = 0

		state_map_mutex.lock()
		for index in neighbours:
			if state_map[index.x][index.y] == TileState.OBSCURED:
				state_map[index.x][index.y] = TileState.REVEALED
				decrement_safe_tile_count()
				to_reveal[reveal_index] = index
				reveal_index += 1
		state_map_mutex.unlock()

		to_reveal = to_reveal.slice(0, reveal_index)

		for index in to_reveal:
			if reveal_queue.size() >= reveal_batch_size:
				waiting_on_batch_reveal = true
				batch_revealed.wait()
				waiting_on_batch_reveal = false
			
			var neighbour_mines = num_neighbour_mines(index)
			
			if neighbour_mines == 0:
				batch_queue.append(get_neighbour_coordinates(index))
			
			reveal_queue_mutex.lock()
			reveal_queue.append(index)
			reveal_queue_number_label.append(neighbour_mines)
			reveal_queue_mutex.unlock()

			#call_deferred("set_revealed", index, neighbour_mines)
			
	reveal_thread_active = false
	reveal_queue_depleted.wait()
	call_deferred("set_physics_process", false)
	revealing = false
	call_deferred("emit_signal", "bulk_reveal_ended")
	
	if num_safe_cells == 0:
		call_deferred("on_win")
	
	reveal_process_id = NO_ACTIVE_TASK


func get_neighbour_coordinates(coordinate : Vector2i) -> Array[Vector2i]:
	var neighbours : Array[Vector2i] = []
	neighbours.resize(8)
	var index : int = 0
		
	var neighbour_area = Rect2i((coordinate - Vector2i.ONE).clamp(grid_area.position, grid_area.size), (coordinate + Vector2i(2, 2)).clamp(grid_area.position, grid_area.size))
	for column in range(neighbour_area.position.x, neighbour_area.size.x):
		for row in range(neighbour_area.position.y, neighbour_area.size.y):
			if(column == coordinate.x and row == coordinate.y): continue
			neighbours[index] = Vector2i(column, row)
			index += 1
			
	return neighbours.slice(0, index)

func is_revealing() -> bool:
	return revealing

func on_flag_placed():
	increment_flag_count()

func on_flag_removed():
	decrement_flag_count()

func increment_flag_count():
	count_mutex.lock()
	update_flag_count(flags_placed + 1)
	count_mutex.unlock()

func decrement_flag_count():
	count_mutex.lock()
	update_flag_count(flags_placed - 1)
	count_mutex.unlock()

func update_flag_count(count : int):
	count_mutex.lock()
	flags_placed = count
	flag_count_changed.emit(flags_placed)
	count_mutex.unlock()

func get_flag_count() -> int:
	return flags_placed

func decrement_safe_tile_count():
	count_mutex.lock()
	num_safe_cells -= 1
	count_mutex.unlock()


func _on_click_timer_timeout() -> void:
	is_click = false
	set_tile_unpressed(pressed_tile)

func on_win():
	game_over = true
	call_deferred("emit_signal", "win")
	
	show_all_mines()
	var tween = create_tween()
	tween.tween_method(func(color:Color): set_layer_modulate(LAYERS["mines"], color), Color(Color.WHITE, 0), Color(Color.WHITE, 1), 1)
	tween.play()


func _on_first_tile_revealed():
	game_started.emit()
