extends OverlayScreen

@onready var mine_texture: TextureRect = $MineTexture
@onready var mine_label: Label = $MineTexture/MineLabel
@onready var timer_label: Label = $FinalTime
@onready var grid_dimensions = $GridDimensions
@onready var foreground_animator = $ForegroundAnimator

@export_range(0, 5) var initial_summary_tween_time : float = 1.5
@export_range(0, 5) var quick_summary_tween_time : float = 0.5

@export_category("Animation Properties")
@export var mine_texture_target_rect : Rect2
@export var mine_label_target_font_size : int
@export var timer_label_target_rect : Rect2
@export var timer_target_font_size : int

var mine_texture_initial_rect : Rect2 : set = set_mine_texture_initial_rect
var mine_label_initial_font_size : int : set = set_mine_label_initial_font_size
var timer_label_initial_rect : Rect2 : set = set_timer_label_initial_rect
var timer_label_initial_font_size : int : set = set_timer_label_initial_font_size

#func _process(_delta: float) -> void:
	#if Input.is_key_label_pressed(KEY_SPACE):
		#_on_visibility_changed()
	#if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#var mouse_pos = get_local_mouse_position()
		#mine_texture_initial_rect = Rect2(mouse_pos, Vector2.ZERO)
		#timer_label_initial_rect = Rect2(mouse_pos, Vector2.ZERO)
		#prepare_animation()

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
	var grid_size = GlobalSettings.settings.get_size()
	grid_dimensions.set_text("{0}x{1}".format([grid_size.y, grid_size.x]))
	
	var maximize_animation : Animation = foreground_animator.get_animation("maximize")
	
	update_rect_track(maximize_animation, mine_texture.get_name(), mine_texture_initial_rect, mine_texture_target_rect)
	update_rect_track(maximize_animation, timer_label.get_name(), timer_label_initial_rect, timer_label_target_rect)
	update_text_size_track(maximize_animation, "%s/%s" % [mine_texture.get_name(), mine_label.get_name()], mine_label_initial_font_size, mine_label_target_font_size)
	update_text_size_track(maximize_animation, timer_label.get_name(), timer_label_initial_font_size, timer_target_font_size)


func update_rect_track(animation : Animation, node_path : String, start : Rect2, end : Rect2):
	var position_property = "%s:position" % node_path
	var size_property = "%s:size" % node_path
	update_property_track(animation, position_property, start.position, end.position)
	update_property_track(animation, size_property, start.size, end.size)

func update_text_size_track(animation : Animation, node_path : String, start : float, end : float):
	var text_size_property = "%s:theme_override_font_sizes/font_size" % node_path
	update_property_track(animation, text_size_property, start, end)

func update_property_track(animation : Animation, property_path : String, start, end):
	var track_idx = animation.find_track(NodePath(property_path), Animation.TYPE_VALUE)
	if track_idx == -1: print(property_path)
	animation.track_set_key_value(track_idx, 0, start)
	animation.track_set_key_value(track_idx, 1, end)

func maximize(duration : float = quick_summary_tween_time) -> void:
	foreground_animator.play("maximize", -1, get_relative_speed("maximize", duration), false)

func minimize(duration : float = quick_summary_tween_time) -> void:
	foreground_animator.play("maximize", -1, -get_relative_speed("maximize", duration), true)

func get_relative_speed(animation : String, duration : float) -> float:
	return foreground_animator.get_animation(animation).get_length() / duration

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
			maximize(initial_summary_tween_time)
