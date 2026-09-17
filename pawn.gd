extends CharacterBody3D

const SPEED = 8.0
const GROUND_ACCEL = 1.5
const AIR_ACCEL = 0.01
const LEDGE_GRAB_ACCEL = 2.0
const JUMP_VELOCITY = 14.0
const QUARTER_TURN = TAU / 4
const SPEED_BOB_TIMESCALE = 1.5
const SPEED_BOB_SCALE = 0.003
const SPEED_BOB_MAX = 0.1
const WALLDET_MARGIN = 0.01
const LEDGE_MAX_DIST_SQ = 1.0
const LEDGE_MIN_DOT = 0.75

@onready var pitch_pivot: Marker3D = $BobPivot/PitchPivot
@onready var camera: Camera3D = $BobPivot/PitchPivot/Cam
@onready var look_cast: RayCast3D = $BobPivot/PitchPivot/Cam/Look
@onready var ledge_cast: RayCast3D = $Ledge
var look := Vector2()
var movement := Vector2()
var jump := false
var bob_timebase := 0.0
var ledge_point = null

var wall_normal := Vector3.ZERO

func update_look():
	look.y = clamp(look.y, -QUARTER_TURN, QUARTER_TURN)
	look.x = fmod(look.x, TAU)
	transform.basis = Basis().rotated(Vector3.UP, look.x)
	camera.transform.basis = Basis().rotated(Vector3.LEFT, look.y)
	
func _process(delta: float) -> void:
	var speed = velocity.length()
	if speed < 0.01 or not is_on_floor():
		bob_timebase = 0.0
	else:
		bob_timebase += delta * speed * SPEED_BOB_TIMESCALE
	var mod = clamp(speed * SPEED_BOB_SCALE, 0, SPEED_BOB_MAX)
	pitch_pivot.transform = Transform3D()\
		.rotated(Vector3.FORWARD, -mod * sin(bob_timebase))\
		.translated(Vector3(mod * sin(bob_timebase), mod * sin(2 * bob_timebase), 0))
		
func is_vertically_supported() -> bool:
	return is_on_floor() or ledge_point != null

func _physics_process(delta: float) -> void:
	wall_normal = Vector3.ZERO
	if is_on_wall():
		wall_normal = get_wall_normal()
	else:
		var ki := KinematicCollision3D.new()
		if test_move(transform, Vector3.ZERO, ki, safe_margin + WALLDET_MARGIN, true):
			wall_normal = ki.get_normal()
	
	if not wall_normal:
		ledge_point = null
	if ledge_point == null:
		if look_cast.is_colliding() and look_cast.get_collision_point().distance_squared_to(look_cast.global_position) < LEDGE_MAX_DIST_SQ:
			if ledge_cast.is_colliding() and ledge_cast.get_collision_normal().dot(Vector3.UP) >= LEDGE_MIN_DOT:
				ledge_point = to_local(ledge_cast.get_collision_point())
	
	# Add the gravity.
	if not is_vertically_supported():
		velocity += get_gravity() * delta
	if ledge_point != null:
		velocity.y = move_toward(velocity.y, 0, LEDGE_GRAB_ACCEL)

	# Handle jump.
	if jump:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif wall_normal:
			var vel = JUMP_VELOCITY * (Vector3.UP + wall_normal).normalized()
			velocity.y = vel.y
			velocity.x += vel.x
			velocity.z += vel.z

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := (transform.basis * Vector3(movement.x, 0, movement.y)).normalized()
	var accel = GROUND_ACCEL if is_vertically_supported() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, direction.x * SPEED, accel)
	velocity.z = move_toward(velocity.z, direction.z * SPEED, accel)
	if ledge_point != null:
		velocity.y = move_toward(velocity.y, -movement.y * SPEED, accel)

	move_and_slide()
