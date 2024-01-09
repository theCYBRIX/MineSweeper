class_name GameSettings
extends Resource

@export var square_grid : bool = false
@export var grid_size : Vector2i = Vector2i(20, 20)
@export var mine_fraction : float = 0.1

@export var sound_fx_enabled : bool = true
@export var ui_sound_enabled : bool = true
@export var sound_fx_volume : float = 0

@export var window_mode : int = DisplayServer.WINDOW_MODE_WINDOWED
