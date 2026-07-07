extends CanvasLayer
## System overlay on Esc. The world keeps running — like the GARAGE and
## route log this is a panel over an idle game, not a pause: paused
## ghosts would earn nothing while quitting accrues offline income, so a
## real pause would be strictly worse than closing the game. Owns the
## device settings file (user://settings.cfg) — display prefs live here,
## never in the profile save.

const SETTINGS_PATH := "user://settings.cfg"
const RESET_CONFIRM_MSEC := 3000

@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _reset: Button = %Reset

var _reset_armed_until := 0

@onready var _config := ConfigFile.new()


func _ready() -> void:
	visible = false
	_config.load(SETTINGS_PATH)  # missing file is fine — defaults apply
	if _config.get_value("display", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_fullscreen.button_pressed = _config.get_value("display", "fullscreen", false)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	%Resume.pressed.connect(func() -> void: visible = false)
	_reset.pressed.connect(_on_reset_pressed)
	%Quit.pressed.connect(func() -> void:
		Bank.save_profile()
		get_tree().quit())


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		visible = not visible
	if _reset_armed_until > 0 and Time.get_ticks_msec() > _reset_armed_until:
		_disarm_reset()


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on
			else DisplayServer.WINDOW_MODE_WINDOWED)
	_config.set_value("display", "fullscreen", on)
	_config.save(SETTINGS_PATH)


## Wiping a profile takes two clicks: the first arms, the second (within
## the window) resets and reloads the world from zero.
func _on_reset_pressed() -> void:
	if _reset_armed_until == 0:
		_reset_armed_until = Time.get_ticks_msec() + RESET_CONFIRM_MSEC
		_reset.text = "Really wipe? Click again"
		_reset.modulate = Color(1.0, 0.55, 0.5)
		return
	Bank.reset_profile()
	visible = false
	_disarm_reset()
	get_tree().reload_current_scene()


func _disarm_reset() -> void:
	_reset_armed_until = 0
	_reset.text = "Reset save"
	_reset.modulate = Color.WHITE
