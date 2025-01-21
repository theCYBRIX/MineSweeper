class_name GameState
extends Resource

signal flag_count_changed(num_flags : int)
signal safe_tile_count_changed(safe_tiles : int)

enum TileState{
	OBSCURED,
	FLAGGED,
	REVEALED
}

@export var num_safe_tiles : int :
	set = set_num_safe_tiles,
	get = get_num_safe_tiles

@export var num_flags : int :
	set = set_num_flags,
	get = get_num_flags

@export var grid_area : Rect2i
var num_mines : int

@export var state_map : Array[Array]
var mine_map : Array[Array]
@export var alternative_mine : Vector2i
@export var mine_coordinate_list : Array[Vector2i]

@export var first_tile_revealed : bool = false

@export var time_elapsed : float = 0

@export var reveal_queue : Array[Vector2i] = [] :
	set = set_reveal_queue

var initialized = false

func _init(initialize : bool = false) -> void:
	if initialize: reset()

func reset(grid_rect : Rect2i = GlobalSettings.settings.get_grid_rect(), mine_count : int = GlobalSettings.get_mines()):
	grid_area = grid_rect
	num_mines = mine_count
	
	var num_columns = grid_area.size.x
	var num_rows = grid_area.size.y
	var num_cells = grid_area.size.x * grid_area.size.y
	if num_mines >= num_cells:
		push_error("Cannot place %i mines in %i cells.\nPlacing %i mines instead." % [num_mines, num_cells, num_cells - 1])
		num_mines = num_cells - 1
	
	num_safe_tiles = num_cells - num_mines
	
	var mine_locations = generate_mine_locations(num_cells, num_mines + 1)
	alternative_mine = linear_to_two_dimensional_index(mine_locations.pop_back())
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
			linear_index += 1
			var is_mine : bool = (linear_index == next_mine)
			mine_map[column][row] = is_mine
			state_map[column][row] = TileState.OBSCURED
			
			if is_mine:
				mine_coordinate_list[mine_index] = Vector2i(column, row)
				mine_index += 1
				if mine_index < mine_locations.size():
					next_mine = mine_locations[mine_index]
	initialized = true

func is_tile_obscured(index : Vector2i) -> bool:
	return tile_has_state(index, TileState.OBSCURED)

func is_tile_flagged(index : Vector2i) -> bool:
	return tile_has_state(index, TileState.FLAGGED)

func is_tile_revealed(index : Vector2i) -> bool:
	return tile_has_state(index, TileState.REVEALED)

func is_tile_mined(index : Vector2i) -> bool:
	return mine_map[index.x][index.y]

func set_tile_obscured(index : Vector2i) -> bool:
	return tile_set_state(index, TileState.OBSCURED)

func set_tile_flagged(index : Vector2i) -> bool:
	return tile_set_state(index, TileState.FLAGGED)

func set_tile_revealed(index : Vector2i) -> bool:
	return tile_set_state(index, TileState.REVEALED)

func tile_has_state(tile : Vector2i, state : TileState) -> bool:
	return (state_map[tile.x][tile.y] == state)

func tile_get_state(tile : Vector2i) -> TileState:
	return state_map[tile.x][tile.y]

func tile_get_state_indexed(x : int, y : int) -> TileState:
	return state_map[x][y]

func tile_set_state(tile : Vector2i, state : TileState) -> bool:
	if state_map[tile.x][tile.y] != state:
		state_map[tile.x][tile.y] = state
		return true
	return false

func num_neighbour_mines(tile : Vector2i) -> int:
	var neighbour_mines : int = 0
	for column in range(maxi(tile.x - 1, grid_area.position.x), mini(tile.x + 2, grid_area.size.x)):
		for row in range(maxi(tile.y - 1, grid_area.position.y), mini(tile.y + 2, grid_area.size.y)):
			if mine_map[column][row]: neighbour_mines += 1
	return neighbour_mines

func generate_mine_locations(num_cells : int, num_mines : int):
	var coordinates : Array = range(num_cells)
	coordinates.shuffle()
	return coordinates.slice(0, num_mines)

func change_mine_position(mine_position : Vector2i, new_position : Vector2i) -> bool:
	var array_index : int = mine_coordinate_list.find(mine_position)
	if array_index < 0: return false
	
	mine_coordinate_list[array_index] = new_position
	mine_map[mine_position.x][mine_position.y] = false
	mine_map[new_position.x][new_position.y] = true
	
	return true

func linear_to_two_dimensional_index(index: int) -> Vector2i:
	var x : int = index / grid_area.size.y
	var y : int = (index - x * grid_area.size.y) % grid_area.size.x
	return Vector2i(x, y)

func is_valid_tile(index : Vector2i) -> bool:
	return grid_area.has_point(index)

func set_num_flags(flags : int) -> void:
	num_flags = flags
	flag_count_changed.emit(num_flags)

func get_num_flags() -> int:
	return num_flags

func get_num_safe_tiles() -> int:
	return num_safe_tiles

func set_num_safe_tiles(safe : int) -> void:
	num_safe_tiles = safe
	safe_tile_count_changed.emit(safe)

func get_num_columns() -> int:
	return grid_area.size.x

func get_num_rows() -> int:
	return grid_area.size.y

func set_reveal_queue(queue : Array[Vector2i]) -> void:
	reveal_queue = queue if queue else [] 

func prepare():
	if initialized:
		return
	if (not grid_area) or (not mine_coordinate_list):
		reset()
		return
		
	var grid_size = grid_area.size
	mine_map = []
	mine_map.resize(grid_size.x)
	for column : int in range(grid_size.x):
		mine_map[column] = []
		mine_map[column].resize(grid_size.y)
		for row : int in range(grid_size.y):
			mine_map[column][row] = false
			
	num_mines = mine_coordinate_list.size()
	for mine in mine_coordinate_list:
		mine_map[mine.x][mine.y] = true
	initialized = true
