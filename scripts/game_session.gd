extends Node

## Carries player choices across scene changes. Right now it holds the track
## picked on the main menu and the mute toggle applied to the Master bus.
## Kept intentionally small; avoid growing this into a catch-all singleton.

const MASTER_BUS_NAME := &"Master"

## Default lands on the rectangle loop (index 0) — tile-based layout that the
## track mutator can splice detours into, so a fresh launch exercises the
## round-evolution path. Figure-eight (index 5) is procedural and the mutator
## skips it; pick it from the menu when you want to test the bridge crossing.
var selected_track_index: int = 0

## Index into `CarOptions.OPTIONS`. 0 is the authored sedan so a fresh launch
## keeps the current visuals. The main menu's car picker writes this.
var selected_car_index: int = 0

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
