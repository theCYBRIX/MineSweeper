class_name LoadingScreen
extends Control

signal safe_to_load

@onready var bg_animator : AnimationPlayer = $Background/BackgroundAnimator
@onready var foreground_element_fader : AnimationPlayer = $Background/ForegroundElements/ElementsFader
@onready var symbol_timer : Timer = $Background/SymbolTimer

@onready var progress_bar = $Background/ForegroundElements/ProgressBar
@onready var loading_symbol = $Background/ForegroundElements/ProgressBar/LoadingAnchor/LoadingSymbol

@onready var cancel_label: Label = $Background/ForegroundElements/CancelLabel
@onready var cancel_label_timer: Timer = $Background/ForegroundElements/CancelLabel/FadeInTimer
@onready var cancel_label_animator: AnimationPlayer = $Background/ForegroundElements/CancelLabel/AnimationPlayer


var symbol_present : bool = false
var cancel_label_present : bool = false

func _ready():
	cancel_label.set_text("Press %s to cancel." % ("back" if GlobalSettings.os_is_mobile() else "escape"))
	
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
	if cancel_label_present:
		cancel_label_animator.play("fade_out")
	
	if loading_symbol.get_frame() > 0:
		await loading_symbol.animation_looped
		
	loading_symbol.play("Explosion")
	await loading_symbol.animation_finished
	foreground_element_fader.play_backwards("FADE_IN")
	await foreground_element_fader.animation_finished
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
	foreground_element_fader.play("FADE_IN")
	await foreground_element_fader.animation_finished
	cancel_label_timer.start()

func _on_fade_in_timer_timeout() -> void:
	cancel_label_present = true
	cancel_label_animator.play("fade_in")
