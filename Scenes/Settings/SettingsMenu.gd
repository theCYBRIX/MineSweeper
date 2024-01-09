
extends Control

signal end_dialog

const GRAPHICS_SETTINGS_WHITELIST : Array[String] = ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]

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
@onready var apply_button: Button = $UserInterface/Buttons/ApplyButton
@onready var close_button: Button = $UserInterface/Buttons/CloseButton

var settings_buffer : GameSettings

#TODO: Make setting changes reflect properly, and set the apply button's state

func _ready():
	#Global.settings.changed.connect(on_settings_changed.bind())
	Global.settings_changed.connect(refresh_all.bind(), 0)
	
	set_hide_grid_settings(hide_grid_settings)
	set_hide_graphics_settings(hide_graphics_settings)
	set_hide_sound_settings(hide_sound_settings)
	set_hide_default_settings(hide_default_settings)
	
	if not (OS.get_name() in GRAPHICS_SETTINGS_WHITELIST):
		set_hide_graphics_settings(true)
	

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
			end_dialog.emit()
		else:
			return
		get_viewport().set_input_as_handled()

func _on_apply_button_pressed():
	game.apply_settings()
	graphics.apply_settings()
	sound.apply_settings()
	Global.save_settings()
	#apply_button.set_disabled(true)
	settings_buffer = Global.settings.duplicate(true)
	if end_when_applied: end_dialog.emit()

func _on_close_button_pressed():
	Global.reset_settings(settings_buffer)
	end_dialog.emit()

func _on_visibility_changed():
	if is_node_ready() and is_visible():
		refresh_all()
		settings_buffer = Global.settings.duplicate(true)

func refresh_all():
	game.refresh()
	graphics.refresh()
	sound.refresh()

func on_settings_changed():
	refresh_all()
	apply_button.set_disabled(false)
