extends Node

signal settings_changed

const settings_path : String = "user://settings.tres"
const save_game_path : String = "user://game_state.tres" 

var settings : GameSettings
var game_state : GameState

var saved_game_state : GameState

var use_saved_state : bool = false

@export_category("Grid Positioning")
@export_subgroup("Offset")
@export var centered : bool = true
@export_subgroup("Allignment")
@export var h_alignment : HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
@export var v_alignment : VerticalAlignment = VERTICAL_ALIGNMENT_CENTER

@export_category("Audio")
@export_range(0, 20) var max_volume = 0
@export_range(-50, 0) var min_volume = -25

const DESKTOP_PLATFORMS : Array[String] = ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


func _notification(what: int) -> void:
	match(what):
		NOTIFICATION_WM_CLOSE_REQUEST:
			quick_save()
			get_tree().call_deferred("quit")
		NOTIFICATION_APPLICATION_PAUSED: #Application minimized on Android
			quick_save()

func quick_save():
	if game_state != null: ResourceSaver.save(game_state, save_game_path)

func _ready():
	set_settings(load_settings())
	saved_game_state = load_game_state()

func reset_settings() -> void:
	set_settings(GameSettings.new())

func set_settings(new_settings : GameSettings) -> void:
	if settings: settings.changed.disconnect(_on_settings_changed.bind())
	
	var prev_signals = settings.changed.get_connections() if settings else []
	settings = new_settings if new_settings != null else GameSettings.new()
	
	settings.changed.connect(_on_settings_changed.bind())
	
	for s in prev_signals:
		settings.connect(s["signal"].get_name(), s["callable"], s["flags"])
	
	_on_settings_changed()
	settings_changed.emit()

func os_is_mobile() -> float:
	return not (OS.get_name() in DESKTOP_PLATFORMS)

func get_mines() -> int:
	var num_cells = settings.get_grid_rect().get_area()
	var num_mines = floori(settings.mine_fraction * num_cells)
	return clamp(num_mines, 1, num_cells - 1)

func set_fx_gain_db(volume : float):
	settings.set_fx_volume(inverse_lerp(min_volume, max_volume, volume))

func get_fx_gain_db() -> float:
	return lerpf(min_volume, max_volume, settings.sound_fx_volume)

func set_master_gain_db(volume : float):
	settings.set_master_volume(inverse_lerp(min_volume, max_volume, volume))

func get_master_gain_db() -> float:
	return lerpf(min_volume, max_volume, settings.master_volume)

func save_settings():
	ResourceSaver.save(settings, settings_path, ResourceSaver.FLAG_NONE)

func save_game_state(state : GameState):
	ResourceSaver.save(state, save_game_path, ResourceSaver.FLAG_NONE)
	saved_game_state = state

func delete_saved_game_state():
	saved_game_state = null
	if FileAccess.file_exists(save_game_path):
		DirAccess.remove_absolute(save_game_path)

func load_settings() -> Resource:
	if FileAccess.file_exists(settings_path):
		return ResourceLoader.load(settings_path)
	else:
		return settings

func load_game_state() -> GameState:
	if FileAccess.file_exists(save_game_path):
		return ResourceLoader.load(save_game_path)
	else:
		return null

func save_is_present() -> bool:
	return FileAccess.file_exists(save_game_path)

func _on_settings_changed() -> void:
	update_window_mode()

func update_window_mode() -> void:
	var window_mode = DisplayServer.window_get_mode()
	if generalize_window_mode(window_mode) != settings.get_window_mode():
		DisplayServer.window_set_mode(settings.get_window_mode())

func generalize_window_mode(mode : DisplayServer.WindowMode) -> DisplayServer.WindowMode:
	match mode:
		DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_MINIMIZED:
			return DisplayServer.WINDOW_MODE_WINDOWED
		_:
			return mode

func get_initial_game_state() -> GameState:
	if use_saved_state and saved_game_state:
		return saved_game_state
	else:
		return GameState.new(true)
