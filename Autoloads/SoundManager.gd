extends Node

@onready var button_press: AudioStreamPlayer = $ButtonPress
@onready var button_hover: AudioStreamPlayer = $ButtonHover
@onready var mine_explosion: AudioStreamPlayer = $MineExplosion
@onready var flag_sound: AudioStreamPlayer = $FlagSound
@onready var tile_reveal: AudioStreamPlayer = $TileReveal

var AUDIO_BUS_MASTER : int = AudioServer.get_bus_index("Master")
var AUDIO_BUS_FX : int = AudioServer.get_bus_index("FX")
var AUDIO_BUS_UI : int = AudioServer.get_bus_index("UI")

func _enter_tree() -> void:
	GlobalSettings.settings_changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	GlobalSettings.settings_changed.disconnect(_on_settings_changed)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ensure_button_sounds()
	get_tree().node_added.connect(attach_button_sounds)
	
	update_audio_buses()


func ensure_button_sounds() -> void:
	var nodes : Array[Node] = [get_tree().get_root()]
	while nodes.size() > 0:
		var selected : Node = nodes.pop_front()
		nodes.append_array(selected.get_children(true))
		attach_button_sounds(selected)


func attach_button_sounds(node : Node) -> void:
	if node is BaseButton:
		node.mouse_entered.connect(button_hovered)
		node.pressed.connect(button_pressed)
	elif node is TabBar:
		node.tab_hovered.connect(tab_hovered)
		node.tab_selected.connect(tab_selected)


func button_hovered() -> void:
	button_hover.play()

func button_pressed() -> void:
	button_press.play()

func tab_hovered(_idx : int) -> void:
	button_hovered()

func tab_selected(_idx : int) -> void:
	button_pressed()

func flag_toggled() -> void:
	flag_sound.play()

func tile_revealed() -> void:
	tile_reveal.play()

func mine_exploded() -> void:
	mine_explosion.play()

func update_fx_volume() -> void:
	AudioServer.set_bus_mute(AUDIO_BUS_FX, not fx_sound_enabled())
	AudioServer.set_bus_volume_db(AUDIO_BUS_FX, GlobalSettings.get_fx_gain_db())

func update_ui_volume() -> void:
	AudioServer.set_bus_mute(AUDIO_BUS_UI, not ui_sound_enabled())

func update_master_volume() -> void:
	AudioServer.set_bus_mute(AUDIO_BUS_MASTER, not sound_enabled())
	AudioServer.set_bus_volume_db(AUDIO_BUS_MASTER, GlobalSettings.get_master_gain_db())

func update_audio_buses() -> void:
	update_master_volume()
	update_fx_volume()
	update_ui_volume()

func sound_enabled() -> bool:
	return GlobalSettings.settings.get_sound_enabled()

func fx_sound_enabled() -> bool:
	return GlobalSettings.settings.get_fx_enabled()

func ui_sound_enabled() -> bool:
	return GlobalSettings.settings.get_ui_sound_enabled()

func _on_settings_changed() -> void:
	update_audio_buses()
