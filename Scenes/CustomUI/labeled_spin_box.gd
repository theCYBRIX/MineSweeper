@tool

class_name LabeledSpinBox
extends Control

signal value_changed(value: int)

@export var text : String : set = set_text, get = get_text
@export var value : int : set = set_value, get = get_value

@onready var label: Label = $Label
@onready var spin_box : SpinBox = $SpinBox

func set_text(new_text : String):
	text = new_text
	if label: label.set_text(new_text)

func get_text() -> String:
	return label.get_text() if label else text

func set_value(new_value : int):
	value = new_value
	if spin_box and spin_box.value != new_value:
		spin_box.set_value(new_value)
	value_changed.emit(new_value)

func get_value() -> int:
	return int(spin_box.get_value()) if spin_box else value

func _on_spin_box_value_changed(new_value: float) -> void:
	set_value(int(new_value))
