extends Node

const SENSITIVITY = Vector2(-0.01, 0.01)

const Pawn = preload("res://pawn.gd")
@onready var pawn: Pawn = get_parent()

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pawn.ready.connect(self.set_camera)
	
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pawn.ready.disconnect(self.set_camera)
	
func set_camera() -> void:
	pawn.camera.current = true
	
func _process(_delta: float) -> void:
	pawn.jump = Input.is_action_just_pressed("move_jump")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pawn.look += event.screen_relative * SENSITIVITY
		pawn.update_look()
	if event is InputEventMouseButton:
		# need this to recapture in the appropriate context on web
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	pawn.movement = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
