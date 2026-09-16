extends CharacterBody3D

const SPEED = 8.0
const GROUND_ACCEL = 1.5
const AIR_ACCEL = 0.01
const JUMP_VELOCITY = 14.0
const QUARTER_TURN = TAU / 4

@onready var pivot: Marker3D = $CamPivot
@onready var camera: Camera3D = $CamPivot/Cam
var look := Vector2()
var movement := Vector2()
var jump := false

func update_look():
	look.y = clamp(look.y, -QUARTER_TURN, QUARTER_TURN)
	look.x = fmod(look.x, TAU)
	transform.basis = Basis().rotated(Vector3.UP, look.x)
	pivot.transform.basis = Basis().rotated(Vector3.LEFT, look.y)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if jump:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			velocity.y = JUMP_VELOCITY
			velocity += JUMP_VELOCITY * get_wall_normal()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := (transform.basis * Vector3(movement.x, 0, movement.y)).normalized()
	var accel = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, direction.x * SPEED, accel)
	velocity.z = move_toward(velocity.z, direction.z * SPEED, accel)

	move_and_slide()
