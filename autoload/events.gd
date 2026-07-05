extends Node
## Global signal bus. Cross-scene facts only — carries no state.
## Past tense = something happened. Scenes emit; interested scenes connect.

signal lap_completed(lap_time: float, is_best: bool)
signal best_lap_recorded(recording: LapRecording)
signal currency_changed(amount: float)
signal ghost_hired(slot_index: int)
