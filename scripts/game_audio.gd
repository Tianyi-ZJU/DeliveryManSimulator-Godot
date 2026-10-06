extends Node

## Non-spatial music and event cues from the original Unity project.
signal cue_started(cue: StringName)

const DAY_MUSIC := [
	"res://assets/audio/music/I.mp3",
	"res://assets/audio/music/II.mp3",
	"res://assets/audio/music/III.mp3",
	"res://assets/audio/music/IV.mp3",
	"res://assets/audio/music/V.mp3",
]
const CUE_PATHS := {
	&"accept": "res://assets/audio/sfx/accept.mp3",
	&"delivery": "res://assets/audio/sfx/delivery.mp3",
	&"late": "res://assets/audio/sfx/late.mp3",
	&"boost": "res://assets/audio/sfx/boost.mp3",
	&"button": "res://assets/audio/sfx/button.mp3",
}

var music_player: AudioStreamPlayer
var effect_players: Dictionary[StringName, AudioStreamPlayer] = {}
var current_day := 0
var boost_active := false
var muted := false

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = &"Music"
	add_child(music_player)
	for cue: StringName in CUE_PATHS:
		var player := AudioStreamPlayer.new()
		player.name = String(cue).capitalize() + "Player"
		player.bus = &"SFX"
		player.max_polyphony = 4
		player.stream = load(CUE_PATHS[cue]) as AudioStreamMP3
		add_child(player)
		effect_players[cue] = player

func _exit_tree() -> void:
	stop()
	music_player.stream = null
	for player: AudioStreamPlayer in effect_players.values():
		player.stream = null

func play_day(day_number: int) -> void:
	stop()
	current_day = clampi(day_number, 1, DAY_MUSIC.size())
	var source := load(DAY_MUSIC[current_day - 1]) as AudioStreamMP3
	if source == null:
		push_error("Missing day music: " + DAY_MUSIC[current_day - 1])
		return
	var music := source.duplicate() as AudioStreamMP3
	music.loop = true
	music_player.stream = music
	music_player.pitch_scale = 1.0
	music_player.play()

func play_cue(cue: StringName) -> void:
	if not effect_players.has(cue):
		push_error("Unknown audio cue: " + String(cue))
		return
	var player := effect_players[cue]
	player.play()
	cue_started.emit(cue)

func set_boost_active(active: bool) -> void:
	if active and not boost_active:
		play_cue(&"boost")
	boost_active = active

func update_music_pitch(slowing: bool, delta: float) -> void:
	music_player.pitch_scale = move_toward(music_player.pitch_scale, 0.5 if slowing else 1.0, maxf(0.0, delta) * 1.5)

func stop() -> void:
	music_player.stop()
	music_player.pitch_scale = 1.0
	boost_active = false
	for player: AudioStreamPlayer in effect_players.values():
		player.stop()

func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), muted)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"), muted)
	return muted

func get_playback_state() -> Dictionary:
	# Mixer peaks expose real output for runtime diagnostics and regression checks.
	return {
		"day": current_day,
		"music_playing": music_player.playing,
		"pitch": music_player.pitch_scale,
		"muted": muted,
		"music_peak_db": AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(&"Music"), 0),
		"sfx_peak_db": AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(&"SFX"), 0),
	}
