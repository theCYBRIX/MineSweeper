extends TileMapLayer


@onready var animation_player: AnimationPlayer = $AnimationPlayer


func fade_in_mines():
	animation_player.play("fade_in_mines")
