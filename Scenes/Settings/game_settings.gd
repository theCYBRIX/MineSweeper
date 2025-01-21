extends Control

signal setting_changed

@onready var rows_input: SpinBox = $SettingsContainer/RowsInput/SpinBox
@onready var rows_label: Label = $SettingsContainer/RowsInput/Label
@onready var columns_input: SpinBox = $SettingsContainer/ColumnsInput/SpinBox
@onready var columns_setting: HBoxContainer = $SettingsContainer/ColumnsInput
@onready var mines_input: HSlider = $SettingsContainer/MineSetting/MinesSlider
@onready var mines_percent_label : Label = $SettingsContainer/MineSetting/MinesPercentLabel
@onready var square_grid_option: CheckButton = $SettingsContainer/SquareGridOption
@onready var first_safe_option: CheckButton = $SettingsContainer/FirstSafeOption

var square_grid_enabled : bool = false
var mine_slider_dragging : bool = false

var rows_is_one : bool = false
var columns_is_one : bool = false

func refresh():
	rows_input.set_value(GlobalSettings.settings.get_rows())
	columns_input.set_value(GlobalSettings.settings.get_columns())
	mines_input.set_value(GlobalSettings.settings.get_mine_fraction() * 100.0)
	square_grid_option.set_pressed(GlobalSettings.settings.get_square_grid())
	first_safe_option.set_pressed(GlobalSettings.settings.get_first_tile_safe())

func apply_settings():
	var square_grid: bool = square_grid_option.is_pressed()
	var rows : int = rows_input.get_value()
	var columns : int = rows if square_grid else columns_input.get_value()
	var mine_percentage : float = mines_input.get_value()
	var first_tile_safe : float = first_safe_option.is_pressed()
	
	GlobalSettings.settings.set_rows(rows)
	GlobalSettings.settings.set_columns(columns)
	GlobalSettings.settings.set_mine_fraction(mine_percentage / 100.0)
	GlobalSettings.settings.set_square_grid(square_grid)
	GlobalSettings.settings.set_first_tile_safe(first_tile_safe)


func get_as_dictionary() -> Dictionary:
	return {
		"square_grid" =  square_grid_option.is_pressed(),
		"rows" = rows_input.get_value(),
		"columns" = columns_input.get_value(),
		"mine_percentage" = mines_input.get_value(),
		"first_tile_safe" = first_safe_option.is_pressed()
	}


func _on_mines_slider_value_changed(value):
	mines_percent_label.set_text("%2.1f%%"%value)
	if not mine_slider_dragging: setting_changed.emit()


func _on_square_grid_option_toggled(toggled_on : bool):
	square_grid_enabled = toggled_on
	
	if toggled_on:
		columns_setting.hide()
		rows_label.set_text("Sides")
		rows_input.min_value = 2
		columns_input.min_value = 2
	else:
		columns_setting.show()
		rows_label.set_text("Rows")
		rows_input.min_value = 1
		columns_input.min_value = 1
		
	rows_is_one = false
	columns_is_one = false
	setting_changed.emit()


func _on_rows_input_value_changed(value):
	if value == 1:
		columns_input.min_value = 2
		rows_is_one = true
	elif rows_is_one:
		columns_input.min_value = 1
		rows_is_one = false
		
	if square_grid_enabled:
		columns_input.set_value(value)
		
	setting_changed.emit()

func _on_columns_input_value_changed(value: int) -> void:
	if value == 1:
		rows_input.min_value = 2
		columns_is_one = true
	elif columns_is_one:
		rows_input.min_value = 1
		columns_is_one = false
		
	setting_changed.emit()
	

func _on_mines_slider_drag_started() -> void:
	mine_slider_dragging = true
	setting_changed.emit()

func _on_mines_slider_drag_ended(value_changed: bool) -> void:
	mine_slider_dragging = false
	if value_changed: setting_changed.emit()



func _on_first_safe_option_toggled(_toggled_on: bool) -> void:
	setting_changed.emit()
