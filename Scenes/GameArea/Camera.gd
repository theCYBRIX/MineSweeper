extends Camera2D

# Distance (in pixels) the mouse needs to be dragged in order start the drag gesture and cancel a click event.
@export_range(0, 100) var click_cancel_thresh : int = 10
@export_group("Zoom multipliers", "multiplier_")
@export var multiplier_zoom_in : float = 1.1
@export var multiplier_zoom_out : float = 0.9

@onready var tile_map: TileMap = $"../TileMap"

var min_zoom = Vector2(0.5, 0.5)
var max_zoom = Vector2(1000, 1000)

var mouse_pressed : bool = false
var mouse_motion_buffer : InputEventMouseMotion

var tile_size : Vector2
var grid_size : Vector2

func _ready() -> void:
	tile_size = Vector2(tile_map.get_tileset().get_tile_size())
	grid_size = Vector2(Global.get_grid_rect().size)

func _input(event):
	if event is InputEventPanGesture:
		var gesture = event as InputEventPanGesture
		position += (gesture.get_delta() / zoom) * 2
		event_handled()
			
	elif event is InputEventMagnifyGesture:
		var gesture = event as InputEventMagnifyGesture
		update_zoom(zoom * gesture.get_factor())
		event_handled()
		
	elif event is InputEventMouse:
		if event is InputEventMouseButton:
			if event.is_action("zoom_out"):
				change_zoom(false)
			elif event.is_action("zoom_in"):
				change_zoom(true)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				mouse_pressed = event.is_pressed()
				if not mouse_pressed:
					mouse_motion_buffer = null
				return
			else:
				return
			event_handled()
		elif event is InputEventMouseMotion:
			if mouse_pressed:
				get_viewport().set_input_as_handled()
				var mouse_motion : InputEventMouseMotion = event
				if mouse_motion_buffer:
					mouse_motion.accumulate(mouse_motion_buffer)
					mouse_motion_buffer = null
					
				if tile_map.is_click:
					if mouse_motion.relative.length() > click_cancel_thresh:
						tile_map.cancel_click()
					else:
						mouse_motion_buffer = mouse_motion
						return
				position -= mouse_motion.relative / zoom

func event_handled():
	tile_map.cancel_click()
	get_viewport().set_input_as_handled()

#TODO
func update_position_limits(requested_position : Vector2) -> Vector2:
	var tile_screen_size = tile_size * tile_map.scale * zoom
	var visible_area = get_viewport_rect()
	return clamp(requested_position, visible_area.size.x - tile_screen_size * (grid_size - Vector2.ONE), tile_screen_size)

func change_zoom(zoom_in : bool):
	if zoom_in: 
		zoom_in()
	else:
		zoom_out()

func reset():
	set_position(Vector2.ZERO)
	set_zoom(Vector2.ONE)

func zoom_in():
	update_zoom(zoom * multiplier_zoom_in)

func zoom_out():
	update_zoom(zoom * multiplier_zoom_out)

func update_zoom(new_zoom):
	set_zoom(clamp(new_zoom, min_zoom, max_zoom))


func _on_zoom_in_pressed() -> void:
	zoom_in()

func _on_zoom_out_pressed() -> void:
	zoom_out()
