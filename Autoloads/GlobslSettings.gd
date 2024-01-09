extends Node

signal settings_changed
signal grid_size_changed
signal mine_fraction_changed
signal square_cells_changed
signal sound_settings_changed

const save_path : String = "user://settings.tres" 
var settings : GameSettings = GameSettings.new()

@export_category("Grid Positioning")
@export_subgroup("Offset")
@export var centered : bool = true
@export_subgroup("Allignment")
@export var h_alignment : HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
@export var v_alignment : VerticalAlignment = VERTICAL_ALIGNMENT_CENTER

@export_category("Audio")
@export_range(0, 20) var max_volume = 0
@export_range(-50, 0) var min_volume = -25

@onready var button_hover : AudioStreamPlayer = $ButtonHover
@onready var button_press : AudioStreamPlayer  = $ButtonPress
@onready var mine_explosion : AudioStreamPlayer  = $MineExplosion
@onready var flag_sound : AudioStreamPlayer  = $FlagSound
@onready var tile_reveal : AudioStreamPlayer  = $TileReveal

var default_tile_reveal_volume : float
var default_mine_explosion_volume : float
var default_flag_toggled_volume : float

# TODO: Restore size of windowed

func _ready():
	default_tile_reveal_volume = tile_reveal.get_volume_db()
	default_mine_explosion_volume = mine_explosion.get_volume_db()
	default_flag_toggled_volume = flag_sound.get_volume_db()
	
	reset_settings(load_settings())
	DisplayServer.window_set_mode(settings.window_mode)
	
	ensure_button_sounds()
	get_tree().node_added.connect(attach_button_sounds.bind())

func ensure_button_sounds():
	var nodes : Array[Node] = [get_tree().get_root()]
	while nodes.size() > 0:
		var selected : Node = nodes.pop_front()
		nodes.append_array(selected.get_children(true))
		attach_button_sounds(selected)

func attach_button_sounds(node : Node):
	if node is BaseButton:
		node.mouse_entered.connect(button_hovered.bind())
		node.pressed.connect(button_pressed.bind())
	elif node is TabBar:
		node.tab_hovered.connect(tab_hovered.bind())
		node.tab_selected.connect(tab_selected.bind())

func reset_settings(new_settings : GameSettings = GameSettings.new()):
	settings = new_settings
	settings_changed.emit()

func set_rows(num_rows : int):
	if settings.grid_size.y == num_rows: return
	settings.grid_size.y = num_rows
	grid_size_changed.emit()

func set_columns(num_columns : int):
	if settings.grid_size.x == num_columns: return
	settings.grid_size.x = num_columns
	grid_size_changed.emit()

func set_size(size : Vector2i):
	if settings.grid_size == size: return
	settings.grid_size = Vector2i(size)
	grid_size_changed.emit()

func set_mine_fraction(fraction : float):
	if settings.mine_fraction == fraction: return
	settings.mine_fraction = fraction
	mine_fraction_changed.emit()

func set_square_grid(square : bool):
	if settings.square_grid == square: return
	settings.square_grid = square
	square_cells_changed.emit()

func get_rows() -> int:
	return settings.grid_size.y

func get_columns() -> int:
	return settings.grid_size.x

func get_size() -> Vector2i:
	return settings.grid_size

func get_grid_rect() -> Rect2i:
	return Rect2i(Vector2i.ZERO, settings.grid_size)

func get_mine_fraction() -> float:
	return settings.mine_fraction

func get_mines() -> int:
	return settings.mine_fraction * get_grid_rect().get_area()

func get_square_grid() -> bool:
	return settings.square_grid

func get_fx_volume_db() -> float:
	return settings.sound_fx_volume

func set_fx_volume_db(volume : float):
	settings.sound_fx_volume = clamp(volume, min_volume, max_volume)
	updateFXVolume()
	sound_settings_changed.emit()

func set_fx_volume(volume : float):
	volume = clamp(volume, 0, 1)
	set_fx_volume_db(lerpf(min_volume, max_volume, volume))

func get_fx_volume():
	return inverse_lerp(min_volume, max_volume, settings.sound_fx_volume)

func set_fx_enabled(enabled : bool):
	if settings.sound_fx_enabled == enabled: return
	settings.sound_fx_enabled = enabled
	sound_settings_changed.emit()

func get_fx_enabled() -> bool:
	return settings.sound_fx_enabled

func set_ui_sound_enabled(enabled : bool):
	if settings.ui_sound_enabled == enabled: return
	settings.ui_sound_enabled = enabled
	sound_settings_changed.emit()

func get_ui_sound_enabled() -> bool:
	return settings.ui_sound_enabled
	
func get_window_mode() -> DisplayServer.WindowMode:
	return settings.window_mode as DisplayServer.WindowMode

func set_window_mode(mode : DisplayServer.WindowMode):
	settings.window_mode = mode
	DisplayServer.window_set_mode(mode)

func save_settings():
	ResourceSaver.save(settings, save_path, ResourceSaver.FLAG_NONE)

func load_settings() -> Resource:
	if FileAccess.file_exists(save_path):
		return ResourceLoader.load(save_path)
	else:
		return settings

func button_hovered():
	if settings.ui_sound_enabled: button_hover.play()

func button_pressed():
	if settings.ui_sound_enabled: button_press.play()

func flag_toggled():
	if settings.sound_fx_enabled: flag_sound.play()

func tile_revealed():
	if settings.sound_fx_enabled: tile_reveal.play()

func tab_hovered(_idx : int):
	button_hovered()

func tab_selected(_idx : int):
	button_pressed()

func mine_exploded():
	if settings.sound_fx_enabled:
		mine_explosion.play()


func _on_settings_changed() -> void:
	updateFXVolume()

func updateFXVolume() -> void:
	mine_explosion.set_volume_db(default_mine_explosion_volume + settings.sound_fx_volume)
	tile_reveal.set_volume_db(default_tile_reveal_volume + settings.sound_fx_volume)
	flag_sound.set_volume_db(default_flag_toggled_volume + settings.sound_fx_volume)
