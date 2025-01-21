extends TileMapLayer


@onready var animation_player: AnimationPlayer = $AnimationPlayer


func fade_out_numbers():
	animation_player.play("fade_out_numbers")


func fade_in_numbers():
	animation_player.play_backwards("fade_out_numbers")


func stop_animation(keep_state := false):
	animation_player.stop(keep_state)
