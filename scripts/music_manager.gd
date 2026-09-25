extends Node

const MENU_MUSIC: AudioStream = preload("res://songs/song.ogg")

var player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = AudioStreamPlayer.new()
	player.name = "GlobalMenuMusic"
	player.bus = "Master"
	player.volume_db = -4.0
	player.stream = MENU_MUSIC
	add_child(player)


func play_menu_music() -> void:
	if player == null:
		return

	if player.stream == null:
		player.stream = MENU_MUSIC

	if not player.playing:
		player.play()


func stop_menu_music() -> void:
	if player != null and player.playing:
		player.stop()


func restart_menu_music() -> void:
	if player == null:
		return

	player.stop()
	player.play()
	
