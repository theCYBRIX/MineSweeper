class_name LoadingScreen
extends Control

signal safe_to_load

@onready var bg_animator : AnimationPlayer = $Background/BackgroundAnimator
@onready var symbol_animator : AnimationPlayer = $Background/MovingElements/ProgressBar/LoadingAnchor/LoadingSymbol/SymbolAnimator
@onready var moving_element_fader : AnimationPlayer = $Background/MovingElements/ElementsFader
@onready var symbol_timer : Timer = $Background/SymbolTimer

@onready var progress_bar = $Background/MovingElements/ProgressBar
@onready var loading_symbol = $Background/MovingElements/ProgressBar/LoadingAnchor/LoadingSymbol

var symbol_present : bool = false

func _ready():
	progress_bar.value = 0
	bg_animator.play("FADE_IN")

func fade_out_loading_screen():
	progress_bar.set_value(progress_bar.get_max())
	symbol_timer.stop()
	if symbol_present:
		call_deferred("fade_out_animated_elements")
	else:
		call_deferred("fade_out_and_free")

func fade_out_animated_elements():
	moving_element_fader.play_backwards("FADE_IN")
	await moving_element_fader.animation_finished
	fade_out_and_free()

func fade_out_and_free():
	bg_animator.play("FADE_OUT")
	return bg_animator.animation_finished


func update_progress(progress : float):
	progress_bar.set_value(progress)


func _on_safe_to_load():
	symbol_timer.start()

func _on_symbol_timer_timeout():
	symbol_present = true
	moving_element_fader.play("FADE_IN")
	symbol_animator.play("Spiral")
