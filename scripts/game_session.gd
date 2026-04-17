extends Node

## Carries player choices across scene changes. Right now it only holds the
## track picked on the main menu so the race scene can apply it on load.
## Kept intentionally small; avoid growing this into a catch-all singleton.

var selected_track_index: int = 1
