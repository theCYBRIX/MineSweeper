class_name SFXButton
extends Button

@onready var button_press = $ButtonPress
@onready var button_hover = $ButtonHover


func _on_mouse_entered():
	button_hover.play()


func _on_pressed():
	button_press.play()
