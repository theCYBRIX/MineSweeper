
extends Control

signal end_dialog


@export var hide_grid_settings : bool = false : set = set_hide_grid_settings
@export var hide_graphics_settings : bool = false : set = set_hide_graphics_settings
@export var hide_sound_settings : bool = false : set = set_hide_sound_settings
@export var hide_default_settings : bool = false : set = set_hide_default_settings

@export var end_when_applied : bool = false

@onready var game: Control = $UserInterface/TabContainer/Game
@onready var graphics : Control = $UserInterface/TabContainer/Graphics
@onready var sound: Control = $UserInterface/TabContainer/Sound
@onready var defaults = $UserInterface/TabContainer/Defaults
@onready var tab_container: TabContainer = $UserInterface/TabContainer
@onready var apply_button: Button = $UserInterface/ApplyButton
@onready var close_button: Button = $UserInterface/CloseButton

var settings_buffer : GameSettings
var settings_dictionary : Dictionary

var settings_modified : bool = false

func _exit_tree() -> void:
	GlobalSettings.settings_changed.disconnect(refresh_all.bind())

func _enter_tree() -> void:
	GlobalSettings.settings_changed.connect(refresh_all.bind())

func _ready():
	set_hide_grid_settings(hide_grid_settings)
	set_hide_graphics_settings(hide_graphics_settings)
	set_hide_sound_settings(hide_sound_settings)
	set_hide_default_settings(hide_default_settings)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_visible(): _on_close_button_pressed()
	

func set_hide_grid_settings(enabled : bool):
	hide_grid_settings = enabled
	set_hide_control_tab(game, hide_grid_settings)

func set_hide_graphics_settings(enabled : bool):
	hide_graphics_settings = enabled
	set_hide_control_tab(graphics, hide_graphics_settings)

func set_hide_sound_settings(enabled : bool):
	hide_sound_settings = enabled
	set_hide_control_tab(sound, hide_sound_settings)

func set_hide_default_settings(enabled : bool):
	hide_default_settings = enabled
	set_hide_control_tab(defaults, hide_default_settings)

func set_hide_control_tab(control : Control, enabled : bool):
	if tab_container:
		var tab_index : int = tab_container.get_tab_idx_from_control(control)
		tab_container.set_tab_hidden(tab_index, enabled)
		if enabled:
			if tab_container.get_current_tab() == tab_index:
				select_next_visible_tab()

func get_visible_tab_count() -> int:
	var count : int = 0
	for i in range(tab_container.get_tab_count()):
		if not tab_container.is_tab_hidden(i):
			count += 1
	return count

func select_next_visible_tab():
	if tab_container.select_next_available() or tab_container.select_previous_available(): return
	tab_container.set_tabs_visible(false)

func _shortcut_input(event):
	if is_visible(): 
		if event.is_action_pressed("ui_focus_next"):
			close_button.grab_focus()
		elif event.is_action_pressed("ui_focus_prev"):
			apply_button.grab_focus()
		elif event.is_action_pressed("ui_cancel"):
			_on_close_button_pressed()
		else:
			return
		get_viewport().set_input_as_handled()

func _on_apply_button_pressed():
	game.apply_settings()
	graphics.apply_settings()
	sound.apply_settings()
	GlobalSettings.save_settings()
	cache_settings()
	if end_when_applied: end_dialog.emit()

func get_settings_as_dictionary() -> Dictionary:
	var settings := Dictionary()
	settings.merge(game.get_as_dictionary())
	settings.merge(graphics.get_as_dictionary())
	settings.merge(sound.get_as_dictionary())
	return settings

func _on_close_button_pressed():
	GlobalSettings.set_settings(settings_buffer)
	end_dialog.emit()

func _on_visibility_changed():
	if is_node_ready() and is_visible():
		refresh_all()
		cache_settings()

func refresh_all():
	if is_node_ready():
		game.refresh()
		graphics.refresh()
		sound.refresh()
		cache_settings()

func on_settings_changed():
	var modified : bool = (settings_dictionary != get_settings_as_dictionary())
	
	if modified == settings_modified:
		return
		
	settings_modified = modified
	if settings_modified:
		apply_button.set_disabled(false)
		close_button.set_text("Cancel")
	else:
		apply_button.set_disabled(true)
		close_button.set_text("Close")

func cache_settings():
	settings_buffer = GlobalSettings.settings.duplicate(true)
	settings_dictionary = get_settings_as_dictionary()
	apply_button.set_disabled(true)
	close_button.set_text("Close")
	settings_modified = false
