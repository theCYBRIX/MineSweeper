extends Control
@onready var window_mode_button = $SettingsContainer/HBoxContainer/WindowMode

var window_mode = {
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN : 0,
	DisplayServer.WINDOW_MODE_FULLSCREEN : 1,
	DisplayServer.WINDOW_MODE_WINDOWED : 2
}

func _ready():
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(0), DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(1), DisplayServer.WINDOW_MODE_FULLSCREEN)
	window_mode_button.set_item_metadata(window_mode_button.get_item_index(2), DisplayServer.WINDOW_MODE_WINDOWED)

func apply_settings():
	Global.set_window_mode(window_mode_button.get_selected_metadata())

func get_changes() -> Dictionary:
	var changes : Dictionary = {}
	var mode = window_mode[window_mode_button.get_item_text(window_mode_button.get_selected_id())]
	if mode != Global.get_window_mode(): changes.merge({"window_mode" : mode})
	return changes

func refresh():
	select_current_window_mode()

func generalize_window_mode(mode : DisplayServer.WindowMode = DisplayServer.window_get_mode()) -> DisplayServer.WindowMode:
	match mode:
		DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_MINIMIZED:
			return DisplayServer.WINDOW_MODE_WINDOWED
		_:
			return mode

func select_current_window_mode():
	window_mode_button.select(window_mode_button.get_item_index(window_mode[generalize_window_mode(Global.get_window_mode())]))
