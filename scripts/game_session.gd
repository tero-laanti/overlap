extends Node

## Carries player choices across scene changes. Right now it holds the track
## picked on the main menu and the mute toggle applied to the Master bus.
## Kept intentionally small; avoid growing this into a catch-all singleton.

const MASTER_BUS_NAME := &"Master"

## Default lands on the chicane (index 1) because it surfaces drift and lap
## timing on the first play better than the flat rectangle at index 0.
var selected_track_index: int = 1

## Starts muted so a fresh launch never blares the placeholder audio at the
## player. The main menu's mute button flips this through `toggle_audio_muted`.
var is_audio_muted: bool = true


func _ready() -> void:
	_apply_audio_mute()


func toggle_audio_muted() -> bool:
	is_audio_muted = not is_audio_muted
	_apply_audio_mute()
	return is_audio_muted


func _apply_audio_mute() -> void:
	var master_bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_index < 0:
		return
	AudioServer.set_bus_mute(master_bus_index, is_audio_muted)
