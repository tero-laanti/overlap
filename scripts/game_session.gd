extends Node

## Carries player choices across scene changes. Right now it only holds the
## track picked on the main menu so the race scene can apply it on load.
## Kept intentionally small; avoid growing this into a catch-all singleton.

## Default lands on the chicane (index 1) because it surfaces drift and lap
## timing on the first play better than the flat rectangle at index 0.
var selected_track_index: int = 1
