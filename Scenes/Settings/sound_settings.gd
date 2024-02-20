extends Control

signal setting_changed

@onready var ui_sound_option : CheckButton = $SettingsContainer/SubBusses/UISoundOption
@onready var sfx_sound_option : CheckButton = $SettingsContainer/SubBusses/SFXSoundOption
@onready var master_volume_slider: HSlider = $SettingsContainer/MasterVolume/Setting/Slider
@onready var sound_enable_button: CheckButton = $SettingsContainer/MasterVolume/Setting/EnableButton
@onready var sub_busses: VBoxContainer = $SettingsContainer/SubBusses
@onready var fx_volume_slider: HSlider = $SettingsContainer/SubBusses/SFXSettings/SFXVolume/Slider
@onready var tile_revealed: TextureButton = $SettingsContainer/SubBusses/SFXSettings/TestButtons/TileRevealed
@onready var mine_exploded: TextureButton = $SettingsContainer/SubBusses/SFXSettings/TestButtons/MineExploded
@onready var flag_toggled: TextureButton = $SettingsContainer/SubBusses/SFXSettings/TestButtons/FlagToggled
@onready var sfx_settings: HBoxContainer = $SettingsContainer/SubBusses/SFXSettings

var fx_slider_dragging : bool = false
var master_slider_dragging : bool = false

func _ready() -> void:
	tile_revealed.pressed.disconnect(SoundManager.button_pressed)
	mine_exploded.pressed.disconnect(SoundManager.button_pressed)
	flag_toggled.pressed.disconnect(SoundManager.button_pressed)

func apply_settings():
	var sound_enabled : float = sound_enable_button.is_pressed()
	var master_volume : float = master_volume_slider.get_value()
	var sfx_sound_enabled: bool = sfx_sound_option.is_pressed()
	var ui_sound_enabled: bool = ui_sound_option.is_pressed()
	var fx_volume : float = fx_volume_slider.get_value()
	
	GlobalSettings.settings.set_sound_enabled(sound_enabled)
	GlobalSettings.settings.set_master_volume(master_volume)
	GlobalSettings.settings.set_ui_sound_enabled(ui_sound_enabled)
	GlobalSettings.settings.set_fx_enabled(sfx_sound_enabled)
	GlobalSettings.settings.set_fx_volume(fx_volume)

func get_as_dictionary() -> Dictionary:
	return {
		"sound_enabled" = sound_enable_button.is_pressed(),
		"master_volume" = master_volume_slider.get_value(),
		"sfx_sound_enabled" = sfx_sound_option.is_pressed(),
		"ui_sound_enabled" = ui_sound_option.is_pressed(),
		"fx_volume" = fx_volume_slider.get_value()
	}

func refresh():
	ui_sound_option.set_pressed(GlobalSettings.settings.get_ui_sound_enabled())
	sfx_sound_option.set_pressed(GlobalSettings.settings.get_fx_enabled())
	fx_volume_slider.set_value(GlobalSettings.settings.get_fx_volume())
	sound_enable_button.set_pressed(GlobalSettings.settings.get_sound_enabled())
	master_volume_slider.set_value(GlobalSettings.settings.get_master_volume())


func update_volume():
	GlobalSettings.settings.set_master_volume(master_volume_slider.get_value())
	GlobalSettings.settings.set_fx_volume(fx_volume_slider.get_value())
	SoundManager._on_settings_changed()

func _on_ui_sound_option_toggled(toggled_on):
	GlobalSettings.settings.set_ui_sound_enabled(toggled_on)
	update_volume()
	setting_changed.emit()

func _on_sfx_sound_option_toggled(toggled_on):
	GlobalSettings.settings.set_fx_enabled(toggled_on)
	if toggled_on:
		sfx_settings.show()
	else:
		sfx_settings.hide()
	setting_changed.emit()


func _on_tile_revealed_pressed() -> void:
	update_volume()
	SoundManager.tile_revealed()


func _on_mine_exploded_pressed() -> void:
	update_volume()
	SoundManager.mine_exploded()


func _on_flag_toggled_pressed() -> void:
	update_volume()
	SoundManager.flag_toggled()


func _on_fx_slider_value_changed(_value: float) -> void:
	if not fx_slider_dragging: setting_changed.emit()

func _on_fx_slider_drag_started() -> void:
	fx_slider_dragging = true
	setting_changed.emit()

func _on_fx_slider_drag_ended(value_changed: bool) -> void:
	fx_slider_dragging = false
	if value_changed: setting_changed.emit()


func _on_master_slider_value_changed(_value: float) -> void:
	if not master_slider_dragging: master_volume_changed()

func _on_master_slider_drag_started() -> void:
	master_slider_dragging = true
	master_volume_changed()

func _on_master_slider_drag_ended(value_changed: bool) -> void:
	master_slider_dragging = false
	if value_changed:
		master_volume_changed()

func _on_master_enable_button_toggled(toggled_on: bool) -> void:
	GlobalSettings.settings.set_sound_enabled(toggled_on)
	if toggled_on:
		sub_busses.show()
	else:
		sub_busses.hide()
	master_volume_changed()

func master_volume_changed() -> void:
	update_volume()
	setting_changed.emit()
