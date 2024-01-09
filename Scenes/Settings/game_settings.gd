extends Control

@onready var rows_input: LabeledSpinBox = $SettingsContainer/RowsInput
@onready var columns_input: LabeledSpinBox = $SettingsContainer/ColumnsInput
@onready var mines_input: HSlider = $SettingsContainer/VBoxContainer/MinesSlider
@onready var mines_percent_label : Label = $SettingsContainer/VBoxContainer/MinesPercentLabel
@onready var square_grid_option: CheckButton = $SettingsContainer/SquareGridOption

var square_grid_enabled : bool = false

func refresh():
	rows_input.set_value(Global.get_rows())
	columns_input.set_value(Global.get_columns())
	mines_input.set_value(Global.get_mine_fraction() * 100)
	square_grid_option.set_pressed(Global.get_square_grid())

func apply_settings():
	var square_grid: bool = square_grid_option.is_pressed()
	var rows : int = rows_input.get_value()
	var columns : int = rows if square_grid else columns_input.get_value()
	var mine_percentage : float = mines_input.get_value()
	
	Global.set_rows(rows)
	Global.set_columns(columns)
	Global.set_mine_fraction(mine_percentage / 100.0)
	Global.set_square_grid(square_grid)



func _on_mines_slider_value_changed(value):
	mines_percent_label.set_text("%2.1f%%"%value)


func _on_square_grid_option_toggled(toggled_on : bool):
	square_grid_enabled = toggled_on
	if toggled_on:
		columns_input.hide()
		rows_input.set_text("Sides")
	else:
		columns_input.show()
		rows_input.set_text("Rows")


func _on_rows_input_value_changed(value):
	if square_grid_enabled:
		columns_input.set_value(value)
