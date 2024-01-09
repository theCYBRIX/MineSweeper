extends OverlayScreen

@onready var mine_texture: TextureRect = $MineTexture
@onready var mine_label: Label = $MineTexture/MineLabel
@onready var timer_label: Label = $FinalTime
@onready var grid_dimensions = $GridDimensions
@onready var foreground_animator = $ForegroundAnimator

@export_range(0, 5) var initial_summary_tween_time : float = 1.5
@export_range(0, 5) var quick_summary_tween_time : float = 0.5

var mine_texture_target_rect : Rect2
var mine_label_target_font_size : int
var timer_label_target_rect : Rect2
var timer_target_font_size : int

var mine_texture_initial_rect : Rect2 : set = set_mine_texture_initial_rect
var mine_label_initial_font_size : int : set = set_mine_label_initial_font_size
var timer_label_initial_rect : Rect2 : set = set_timer_label_initial_rect
var timer_label_initial_font_size : int : set = set_timer_label_initial_font_size

var mine_label_font_size_tweener : Tween
var timer_label_font_size_tweener : Tween
#
#func _process(_delta: float) -> void:
	#if Input.is_key_label_pressed(KEY_SPACE):
		#_on_visibility_changed()

func _shortcut_input(event):
	super._shortcut_input(event)
	if(get_viewport().is_input_handled()):
		return
	elif is_visible(): 
		if event.is_action_pressed("ui_focus_next"):
			view_grid_button.grab_focus()
			get_viewport().set_input_as_handled()

func _ready() -> void:
	mine_texture_target_rect = mine_texture.get_rect()
	timer_label_target_rect = timer_label.get_rect()
	timer_target_font_size = timer_label.get_theme_font_size("font_size")
	mine_label_target_font_size = mine_label.get_theme_font_size("font_size")
	#prepare_animation()

func prepare_animation():
	grid_dimensions.set_text("{0}x{1}".format([Global.get_size().y, Global.get_size().x]))
	
	var maximize_animation : Animation = foreground_animator.get_animation("maximize")
	
	add_rect_track(maximize_animation, "MineTexture", mine_texture_initial_rect, 0, mine_texture_target_rect, quick_summary_tween_time)
	add_rect_track(maximize_animation, "FinalTime", timer_label_initial_rect, 0, timer_label_target_rect, quick_summary_tween_time)
	

func add_rect_track(animation : Animation, node_path : String, start : Rect2, start_time : float, end : Rect2, end_time : float):
	var position_property = "%s:position" % node_path
	var size_property = "%s:size" % node_path
	add_property_track(animation, position_property, start.position, start_time, end.position, end_time)
	add_property_track(animation, size_property, start.size, start_time, end.size, end_time)

func add_property_track(animation : Animation, property_path : String, start, start_time : float, end, end_time : float) -> int:
	var track : int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, property_path)
	animation.track_insert_key(track, start_time, start)
	animation.track_insert_key(track, end_time, end)
	return track

func maximize(duration : float = quick_summary_tween_time) -> void:
	foreground_animator.play("maximize", -1, 0.5 / duration)
	var time_remaining = duration - foreground_animator.current_animation_position
	tween_font_sizes(mine_label_target_font_size, timer_target_font_size, time_remaining)

func minimize(duration : float = quick_summary_tween_time) -> void:
	foreground_animator.play("maximize", -1, -(0.5 / duration), true)
	var time_remaining = foreground_animator.current_animation_position - (duration - foreground_animator.current_animation_position)
	tween_font_sizes(mine_label_initial_font_size, timer_label_initial_font_size, time_remaining)

func tween_font_sizes(mine_label_target : int, timer_label_target : int, duration : float, easing : Tween.EaseType = Tween.EASE_OUT):
	if timer_label_font_size_tweener and timer_label_font_size_tweener.is_running():
		timer_label_font_size_tweener.pause()
		timer_label_font_size_tweener.kill()
	if mine_label_font_size_tweener and mine_label_font_size_tweener.is_running():
		mine_label_font_size_tweener.pause()
		mine_label_font_size_tweener.kill()
	timer_label_font_size_tweener = tween_font_size(timer_label, timer_label.get_theme_font_size("font_size"), timer_label_target, duration, easing)
	mine_label_font_size_tweener = tween_font_size(mine_label, mine_label.get_theme_font_size("font_size"), mine_label_target, duration, easing)

func tween_font_size(label : Label, from : int, to : int, duration : float, easing : Tween.EaseType = Tween.EASE_OUT) -> Tween:
	var tween = create_tween()
	tween.tween_method(override_font_size.bind(label), from, to, duration).set_ease(easing)
	tween.play()
	return tween

func override_font_size(new_size : int, label: Label):
	label.add_theme_font_size_override("font_size", new_size)

func set_mine_texture_initial_rect(rect : Rect2):
	mine_texture_initial_rect = rect

func set_timer_label_initial_rect(rect : Rect2):
	timer_label_initial_rect = rect

func set_timer_label_initial_font_size(new_size : int):
	timer_label_initial_font_size = new_size

func set_mine_label_initial_font_size(new_size : int):
	mine_label_initial_font_size = new_size

func set_timer_label(text : String):
	timer_label.set_text(text)

func set_mine_label(text : String):
	mine_label.set_text(text)


func _on_grid_view_toggled(state: bool) -> void:
	if state:
		minimize(quick_summary_tween_time)
	else:
		maximize(quick_summary_tween_time)


func _on_visibility_changed() -> void:
	if is_visible():
		if is_node_ready():
			animation_player.play("slow_reveal")
			timer_label.add_theme_font_size_override("font_size", timer_label_initial_font_size)
			mine_label.add_theme_font_size_override("font_size", mine_label_initial_font_size)
			maximize(initial_summary_tween_time)
