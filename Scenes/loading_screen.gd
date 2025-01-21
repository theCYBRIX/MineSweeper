extends CanvasLayer

signal safe_to_load
signal cancel_requested

@onready var bg_animator : AnimationPlayer = $Background/BackgroundAnimator
@onready var foreground_element_fader : AnimationPlayer = $Background/ForegroundElements/ElementsFader
@onready var symbol_timer : Timer = $Background/SymbolTimer

@onready var progress_bar : ProgressBar = $Background/ForegroundElements/ProgressBar
@onready var loading_symbol : AnimatedSprite2D = $Background/ForegroundElements/ProgressBar/LoadingAnchor/LoadingSymbol

@onready var cancel_label: Label = $Background/ForegroundElements/CancelLabel
@onready var cancel_label_timer: Timer = $Background/ForegroundElements/CancelLabel/FadeInTimer
@onready var cancel_label_animator: AnimationPlayer = $Background/ForegroundElements/CancelLabel/AnimationPlayer


var symbol_present : bool = false
var cancel_label_present : bool = false

var in_foreground : bool = false :
	set = set_in_foreground,
	get = is_in_foreground

func _ready() -> void:
	cancel_label.set_text("Press %s to cancel." % ("back/escape" if GlobalSettings.os_is_web() else ("back" if GlobalSettings.os_is_mobile() else "escape")))


func _shortcut_input(event: InputEvent) -> void:
	if not is_inside_tree() or not in_foreground: return
	if event.is_action_pressed("ui_cancel"):
		cancel_requested.emit()
		get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_BACKSPACE:
				cancel_requested.emit()
				get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_inside_tree() or not in_foreground: return
	match(what):
		NOTIFICATION_WM_CLOSE_REQUEST | NOTIFICATION_WM_GO_BACK_REQUEST: #Back button pressed on Android or Escape pressed on desktop
			cancel_requested.emit()
			get_viewport().set_input_as_handled()


func fade_in() -> Signal:
	animation_wait_finish()
	bg_animator.play("fade_in")
	return safe_to_load

func fade_out() -> Signal:
	stop_timers()
	progress_bar.set_value(progress_bar.get_max())
	if symbol_present:
		await fade_out_animated_elements()
	animation_wait_finish()
	bg_animator.play("fade_out")
	return bg_animator.animation_finished

func fade_out_animated_elements() -> Signal:
	if cancel_label_present:
		cancel_label_animator.play("fade_out")
	
	if loading_symbol.get_frame() > 0:
		await loading_symbol.animation_looped
		
	loading_symbol.play("Explosion")
	await loading_symbol.animation_finished
	return hide_foreground_elements()

func update_progress(progress : float) -> void:
	progress_bar.set_value(progress)

func _on_safe_to_load() -> void:
	symbol_timer.start()

func _on_symbol_timer_timeout() -> void:
	await show_foreground_elements()
	cancel_label_timer.start()

func _on_fade_in_timer_timeout() -> void:
	cancel_label_present = true
	cancel_label_animator.play("fade_in")


func _on_visibility_changed() -> void:
	if visible:
		progress_bar.value = 0

func show_foreground_elements() -> Signal:
	symbol_present = true
	loading_symbol.play("Digging")
	foreground_element_fader.play("fade_in")
	return foreground_element_fader.animation_finished

func hide_foreground_elements() -> Signal:
	symbol_present = false
	foreground_element_fader.play_backwards("fade_in")
	return foreground_element_fader.animation_finished

func stop_timers():
	symbol_timer.stop()
	cancel_label_timer.stop()

func animation_wait_finish():
	if bg_animator and bg_animator.is_playing():
		await bg_animator.animation_finished

func set_in_foreground(value : bool):
	in_foreground = value
	
func is_in_foreground() -> bool:
	animation_wait_finish()
	return in_foreground
