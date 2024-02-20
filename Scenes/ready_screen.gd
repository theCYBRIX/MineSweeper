extends Control

signal start
signal quit

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var buttons: Control = $Buttons
@onready var ready_button: Button = $Buttons/Ready

func _on_ready_pressed() -> void:
	start.emit()

func _on_main_menu_pressed() -> void:
	quit.emit()

func fade_out():
	buttons.hide()
	animation_player.play("fade_out")
	return animation_player.animation_finished


func _on_visibility_changed() -> void:
	if visible:
		ready_button.grab_focus()
