extends Node

@export var camera : Camera2D
@export var intensity : float

var __random : RandomNumberGenerator = RandomNumberGenerator.new()

var start_pos : Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)
	__random.randomize()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	__shake()


func shake(duration : float):
	var timer := get_tree().create_timer(duration)
	start()
	await timer.timeout
	stop()

func start():
	start_pos = camera.offset
	set_process(true)

func stop():
	camera.offset = start_pos
	set_process(false)

func __shake():
	camera.offset = start_pos + Vector2(__random_offset(), __random_offset())

func __random_offset() -> float:
	return __random.randf_range(-intensity, intensity)
