extends Camera2D

# Distance (in pixels) the mouse needs to be dragged in order start the drag gesture and cancel a click event.
@export_range(0, 100) var click_cancel_thresh : int = 10
@export_group("Zoom multipliers", "multiplier_")
@export var mouse_zoom_delta : float = 0.1

@onready var tile_map: TileMap = $"../TileMap"

var min_zoom : Vector2
var max_zoom: Vector2

var mouse_pressed : bool = false
var mouse_initial_pos : Vector2 = Vector2.ZERO
var camera_initial_pos : Vector2 = Vector2.ZERO

var gesture_processed : bool = false
var grid_size : Vector2

func _ready() -> void:
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
	
	gesture_processed = true
	ensure_grid_on_screen()
	event_handled()

func _input_mouse(event : InputEventMouse):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_pressed = event.is_pressed()
			if mouse_pressed:
				mouse_initial_pos = get_local_mouse_position()
				camera_initial_pos = Vector2(position)
		else:
			var zoom_action = Input.get_axis("zoom_out", "zoom_in")
			if zoom_action != 0:
				mouse_zoom(zoom_action > 0)
				event_handled()
		
	elif event is InputEventMouseMotion:
		if mouse_pressed:
			get_viewport().set_input_as_handled()

			var mouse_position = get_local_mouse_position()
				
			if tile_map.input_is_click:
				if (mouse_position - mouse_initial_pos).length() > click_cancel_thresh:
					tile_map.cancel_click()
				else:
					return
			
			if gesture_processed:
				mouse_initial_pos = mouse_position
				camera_initial_pos = position
				gesture_processed = false
				return
			
			position = camera_initial_pos + (mouse_initial_pos - mouse_position)
			ensure_grid_on_screen()


func event_handled():
	tile_map.cancel_click()
	get_viewport().set_input_as_handled()

func ensure_grid_on_screen():
	var tile_map_size = tile_map.get_size()
	var half_map_size = (tile_map_size / 2)
	var tile_map_center = tile_map.position + half_map_size
	
	position = position.clamp(tile_map_center - half_map_size, tile_map_center + half_map_size)

func mouse_zoom(zoom_in : bool):
	var initial_size : Vector2 = get_viewport_rect().size * zoom
	
	var zoom_multiplier =  (1 + mouse_zoom_delta) if zoom_in else (1 - mouse_zoom_delta)
	update_zoom(zoom * zoom_multiplier)
		
	var new_size : Vector2 = get_viewport_rect().size * zoom
	var delta_size = new_size - initial_size
	var mouse_pos = get_local_mouse_position()
	position += delta_size * (mouse_pos / initial_size)
	
	ensure_grid_on_screen()

func reset():
	set_position(Vector2.ZERO)
	set_zoom(Vector2.ONE)

func update_zoom(new_zoom):
	var tile_map_size : Vector2 = tile_map.get_size()
	var viewport_size = get_viewport_rect().size
	var relative_grid_size : Vector2 = viewport_size / tile_map_size
	var relative_tile_size : Vector2 = viewport_size / (tile_map_size / Vector2(tile_map.game_state.grid_area.size))
	max_zoom = Vector2.ONE * minf(relative_tile_size.x, relative_tile_size.y)
	min_zoom = Vector2.ONE * minf(relative_grid_size.x, relative_grid_size.y) * 0.5
	set_zoom(clamp(new_zoom, min_zoom, max_zoom))

func center_on_area(area: Rect2):
	position = area.position + (area.size / 2) 
	var visible_rect := get_viewport_rect()
	var zoom_to_fill = visible_rect.size / area.size
	zoom = Vector2.ONE * minf(zoom_to_fill.x, zoom_to_fill.y)
