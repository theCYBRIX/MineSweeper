extends Camera2D

# Distance (in pixels) the mouse needs to be dragged in order start the drag gesture and cancel a click event.
@export_range(0, 100) var click_cancel_thresh : int = 10
@export_group("Zoom multipliers", "multiplier_")
@export var mouse_zoom_delta : float = 0.1

@onready var tile_map: TileMap = $"../TileMap"

var min_zoom = Vector2(0.5, 0.5)
var max_zoom = Vector2(1000, 1000)

var mouse_pressed : bool = false
var mouse_motion_buffer : InputEventMouseMotion

var tile_size : Vector2
var grid_size : Vector2

func _ready() -> void:
	tile_size = Vector2(tile_map.get_tileset().get_tile_size())
	grid_size = Vector2(GlobalSettings.settings.get_size())

func _input(event):
	if event is InputEventGesture:
		_input_gesture(event)
		
	elif event is InputEventMouse:
		_input_mouse(event)

func _input_gesture(event : InputEventGesture):
	if event is InputEventPanGesture:
		var gesture = event as InputEventPanGesture
		position += (gesture.get_delta() / zoom) * 2
			
	elif event is InputEventMagnifyGesture:
		var gesture = event as InputEventMagnifyGesture
		update_zoom(zoom * gesture.get_factor())
		
	else:
		return
		
	ensure_grid_on_screen()
	event_handled()

func _input_mouse(event : InputEventMouse):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_pressed = event.is_pressed()
			if not mouse_pressed:
				mouse_motion_buffer = null
		else:
			var zoom_action = Input.get_axis("zoom_out", "zoom_in")
			if zoom_action != 0:
				mouse_zoom(zoom_action > 0)
				event_handled()
		
	elif event is InputEventMouseMotion:
		if mouse_pressed:
			get_viewport().set_input_as_handled()
			var mouse_motion : InputEventMouseMotion = event
			if mouse_motion_buffer:
				mouse_motion.accumulate(mouse_motion_buffer)
				mouse_motion_buffer = null
				
			if tile_map.input_is_click:
				if mouse_motion.relative.length() > click_cancel_thresh:
					tile_map.cancel_click()
				else:
					mouse_motion_buffer = mouse_motion
					return
			position -= mouse_motion.relative / zoom
			ensure_grid_on_screen()


func event_handled():
	tile_map.cancel_click()
	get_viewport().set_input_as_handled()

func ensure_grid_on_screen():
	var grid_size = tile_map.get_size()
	var tile_map_center = tile_map.position + (grid_size / 2)
	var adjusted_grid_size = (grid_size / 2)
	
	var camera_limits : Rect2 = Rect2(tile_map_center - adjusted_grid_size, tile_map_center + adjusted_grid_size)
	position.x = clamp(position.x, camera_limits.position.x, camera_limits.size.x)
	position.y = clamp(position.y, camera_limits.position.y, camera_limits.size.y)

func mouse_zoom(zoom_in : bool):
	var initial_size : Vector2 = get_viewport_rect().size * zoom
	
	var zoom_multiplier =  (1 + mouse_zoom_delta) if zoom_in else (1 - mouse_zoom_delta)
	update_zoom(zoom * zoom_multiplier)
		
	var new_size : Vector2 = get_viewport_rect().size * zoom
	var delta_size = new_size - initial_size
	var mouse_pos = get_local_mouse_position()
	position.x += delta_size.x * inverse_lerp(0, initial_size.x, mouse_pos.x)
	position.y += delta_size.y * inverse_lerp(0, initial_size.y, mouse_pos.y)
	
	ensure_grid_on_screen()

func reset():
	set_position(Vector2.ZERO)
	set_zoom(Vector2.ONE)

func update_zoom(new_zoom):
	set_zoom(clamp(new_zoom, min_zoom, max_zoom))
