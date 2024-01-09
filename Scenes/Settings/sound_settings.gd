extends Control

@onready var ui_sound_option : CheckButton = $SettingsContainer/UISoundOption
@onready var sfx_sound_option : CheckButton = $SettingsContainer/SFXSoundOption
@onready var volume_slider: HSlider = $SettingsContainer/SFXSettings/SFXVolume/Slider
@onready var tile_revealed: TextureButton = $SettingsContainer/SFXSettings/TestButtons/TileRevealed
@onready var mine_exploded: TextureButton = $SettingsContainer/SFXSettings/TestButtons/MineExploded
@onready var flag_toggled: TextureButton = $SettingsContainer/SFXSettings/TestButtons/FlagToggled

func _ready() -> void:
	tile_revealed.pressed.disconnect(Global.button_pressed)
	mine_exploded.pressed.disconnect(Global.button_pressed)
	flag_toggled.pressed.disconnect(Global.button_pressed)

func apply_settings():
	var sfx_sound_enabled: bool = sfx_sound_option.is_pressed()
	var ui_sound_enabled: bool = ui_sound_option.is_pressed()
	var fx_volume : float = volume_slider.get_value()
	
	Global.set_ui_sound_enabled(ui_sound_enabled)
	Global.set_fx_enabled(sfx_sound_enabled)
	Global.set_fx_volume(fx_volume)

func refresh():
	ui_sound_option.set_pressed_no_signal(Global.get_ui_sound_enabled())
	sfx_sound_option.set_pressed_no_signal(Global.get_fx_enabled())
	volume_slider.set_value_no_signal(Global.get_fx_volume())


func update_volume():
	Global.set_fx_volume(volume_slider.get_value())

func _on_ui_sound_option_toggled(toggled_on):
	Global.set_ui_sound_enabled(toggled_on)

func _on_sfx_sound_option_toggled(toggled_on):
	Global.set_fx_enabled(toggled_on)
	tile_revealed.set_disabled(not toggled_on)
	mine_exploded.set_disabled(not toggled_on)


func _on_tile_revealed_pressed() -> void:
	update_volume()
	Global.tile_revealed()


func _on_mine_exploded_pressed() -> void:
	update_volume()
	Global.mine_exploded()


func _on_flag_toggled_pressed() -> void:
	update_volume()
	Global.flag_toggled()
