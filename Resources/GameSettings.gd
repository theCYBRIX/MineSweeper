class_name GameSettings
extends Resource

@export var square_grid : bool = false :
	set = set_square_grid,
	get = get_square_grid
	
@export var grid_size : Vector2i = Vector2i(20, 20) :
	set = set_size,
	get = get_size

@export var mine_fraction : float = 0.1 :
	set = set_mine_fraction,
	get = get_mine_fraction

@export var processing_speed : float = 0.05 :
	set = set_processing_speed,
	get = get_processing_speed

@export var sound_enabled : bool = true :
	set = set_sound_enabled,
	get = get_sound_enabled

@export var sound_fx_enabled : bool = true :
	set = set_fx_enabled,
	get = get_fx_enabled

@export var ui_sound_enabled : bool = true :
	set = set_ui_sound_enabled,
	get = get_ui_sound_enabled

@export var master_volume : float = 1 :
	set = set_master_volume,
	get = get_master_volume

@export var sound_fx_volume : float = 1 :
	set = set_fx_volume,
	get = get_fx_volume

@export var window_mode : int = DisplayServer.WINDOW_MODE_WINDOWED :
	set = set_window_mode,
	get = get_window_mode

@export var first_tile_safe : bool = true :
	set = set_first_tile_safe,
	get = get_first_tile_safe

func equals(other : GameSettings) -> bool:
	return (square_grid == other.square_grid and \
			grid_size == other.grid_size and \
			mine_fraction == other.mine_fraction and \
			processing_speed == other.processing_speed and \
			sound_enabled == other.sound_enabled and \
			sound_fx_enabled == other.sound_fx_enabled and \
			ui_sound_enabled == other.ui_sound_enabled and \
			master_volume == other.master_volume and \
			sound_fx_volume == other.sound_fx_volume and \
			window_mode == other.window_mode and \
			first_tile_safe == other.first_tile_safe)

func get_square_grid() -> bool:
	return square_grid

func set_square_grid(square : bool) -> void:
	if square_grid == square: return
	square_grid = square
	emit_changed()

func get_grid_rect() -> Rect2i:
	return Rect2i(Vector2i.ZERO, grid_size)

func get_size() -> Vector2i:
	return grid_size

func set_size(size : Vector2i) -> void:
	if grid_size == size: return
	grid_size = Vector2i(size)
	emit_changed()

func get_rows() -> int:
	return grid_size.y

func set_rows(num_rows : int) -> void:
	if grid_size.y == num_rows: return
	grid_size.y = num_rows
	emit_changed()

func get_columns() -> int:
	return grid_size.x

func set_columns(num_columns : int) -> void:
	if grid_size.x == num_columns: return
	grid_size.x = num_columns
	emit_changed()

func get_mine_fraction() -> float:
	return mine_fraction

func set_mine_fraction(fraction : float) -> void:
	fraction = clampf(fraction, 0, 1)
	if mine_fraction == fraction: return
	mine_fraction = fraction
	emit_changed()

func get_processing_speed() -> float:
	return processing_speed

func set_processing_speed(fraction : float) -> void:
	fraction = clampf(fraction, 0, 1)
	if processing_speed == fraction: return
	processing_speed = fraction
	emit_changed()

func get_sound_enabled() -> bool:
	return sound_enabled

func set_sound_enabled(enabled : bool) -> void:
	if sound_enabled == enabled: return
	sound_enabled = enabled
	emit_changed()

func get_ui_sound_enabled() -> bool:
	return ui_sound_enabled

func set_ui_sound_enabled(enabled : bool) -> void:
	if ui_sound_enabled == enabled: return
	ui_sound_enabled = enabled
	emit_changed()

func set_fx_volume(volume : float) -> void:
	volume = clampf(volume, 0, 1)
	if volume == sound_fx_volume: return
	sound_fx_volume = volume
	emit_changed()

func get_fx_volume() -> float:
	return sound_fx_volume

func set_master_volume(volume : float) -> void:
	volume = clampf(volume, 0, 1)
	if volume == master_volume: return
	master_volume = volume
	emit_changed()

func get_master_volume() -> float:
	return master_volume

func set_fx_enabled(enabled : bool) -> void:
	if sound_fx_enabled == enabled: return
	sound_fx_enabled = enabled
	emit_changed()

func get_fx_enabled() -> bool:
	return sound_fx_enabled
	
func get_window_mode() -> DisplayServer.WindowMode:
	return window_mode as DisplayServer.WindowMode

func set_window_mode(mode : DisplayServer.WindowMode):
	if window_mode == mode: return
	window_mode = mode
	emit_changed()
	
func get_first_tile_safe() -> bool:
	return first_tile_safe

func set_first_tile_safe(enabled : bool = true):
	if first_tile_safe == enabled: return
	first_tile_safe = enabled
	emit_changed()
