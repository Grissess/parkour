extends CharacterBody3D

const MOVE_SPEED_FULL = 8.0
const MOVE_SPEED_CROUCH = 3.0
const GROUND_ACCEL = 1.5
const CROUCH_ACCEL = 0.1
const AIR_ACCEL = 0.01
const LEDGE_GRAB_ACCEL = 2.0
const JUMP_VELOCITY = 14.0
const JUMP_LOOK_INFLUENCE = 0.3
const QUARTER_TURN = TAU / 4
const SPEED_BOB_TIMESCALE = 1.5
const SPEED_BOB_SCALE = 0.003
const SPEED_BOB_MAX = 0.1
const WALL_TILT = TAU / 24
const WALL_TILT_SPEED = 24.0
const WALLDET_MARGIN = 0.01
const LEDGE_MAX_DIST_SQ = 1.0
const LEDGE_MIN_DOT = 0.75
const HEIGHT_FULL = 2.0
const HEIGHT_CROUCH = 1.0
const CAM_HEIGHT_FULL = 0.5
const CAM_HEIGHT_CROUCH = 0.0
const CROUCH_MARGIN = -0.03
const CROUCH_SPEED = 8.0
const DAMAGE_MIN_IMP = 529
const DAMAGE_MAX_IMP = 1225
const DAMAGE_MIN_AMT = 0.1
const DAMAGE_MAX_AMT = 1.0
const HEAL_RATE = 0.1

signal died

@onready var cam_base: Marker3D = $BobPivot
@onready var pitch_pivot: Marker3D = $BobPivot/PitchPivot
@onready var camera: Camera3D = $BobPivot/PitchPivot/Cam
@onready var look_cast: RayCast3D = $BobPivot/PitchPivot/Cam/Look
@onready var ledge_cast: RayCast3D = $Ledge
@onready var collider: CollisionShape3D = $Collision
@onready var coll_shape: CapsuleShape3D = collider.shape
var look := Vector2()
var movement := Vector2()
var jump := false
var crouch := false
var bob_timebase := 0.0
var wall_tilt := Quaternion()
var ledge_point = null
var dead := false
var is_teleport := false
var health := 1.0:
	set(v):
		health = clamp(v, 0.0, 1.0)
		dead = health == 0.0
		if dead:
			died.emit()

var wall_normal := Vector3.ZERO

func update_look():
	look.y = clamp(look.y, -QUARTER_TURN, QUARTER_TURN)
	look.x = fmod(look.x, TAU)
	transform.basis = Basis().rotated(Vector3.UP, look.x)
	camera.transform.basis = Basis().rotated(Vector3.LEFT, look.y)
	
func _process(delta: float) -> void:
	var speed = velocity.length()
	if speed < 0.01 or not is_on_floor() or is_crouch_sliding():
		bob_timebase = 0.0
	else:
		bob_timebase += delta * speed * SPEED_BOB_TIMESCALE
	var mod = clamp(speed * SPEED_BOB_SCALE, 0, SPEED_BOB_MAX)
	pitch_pivot.transform = Transform3D()\
		.rotated(Vector3.FORWARD, -mod * sin(bob_timebase))\
		.translated(Vector3(mod * sin(bob_timebase), mod * sin(2 * bob_timebase), 0))
	var target_tilt := Quaternion()
	if not is_vertically_supported() and wall_normal:
		var norm = wall_normal * pitch_pivot.global_basis.inverse()
		var axis = Vector3.DOWN.cross(norm)
		print('view tilt on ', axis, ' per norm ', norm)
		if axis:
			target_tilt = Quaternion(axis.normalized(), WALL_TILT * axis.length())
	wall_tilt = wall_tilt.slerp(target_tilt, delta * WALL_TILT_SPEED)
	pitch_pivot.transform = pitch_pivot.transform.rotated(wall_tilt.get_axis(), wall_tilt.get_angle())
		
func is_vertically_supported() -> bool:
	return is_on_floor() or ledge_point != null
	
func is_crouching() -> bool:
	return coll_shape.height < HEIGHT_FULL
	
func is_crouch_sliding() -> bool:
	return is_crouching() and Vector2(velocity.x, velocity.z).length_squared() > MOVE_SPEED_CROUCH * MOVE_SPEED_CROUCH

func _physics_process(delta: float) -> void:
	if dead:
		if not is_on_floor():
			velocity += get_gravity() * delta
			
	else:
		var desired_height = HEIGHT_CROUCH if crouch else HEIGHT_FULL
		if coll_shape.height != desired_height:
			var old_height = coll_shape.height
			var new_height = move_toward(old_height, desired_height, delta * CROUCH_SPEED)
			var y_off = (new_height - old_height) / 2
			coll_shape.height = new_height
			if test_move(transform.translated(Vector3(0, y_off, 0)), Vector3.ZERO, null, safe_margin + CROUCH_MARGIN, true):
				coll_shape.height = old_height
			else:
				translate(Vector3(0, y_off, 0))
				cam_base.transform = Transform3D()\
					.translated(Vector3(0, remap(new_height, HEIGHT_CROUCH, HEIGHT_FULL, CAM_HEIGHT_CROUCH, CAM_HEIGHT_FULL), 0))
			
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
			# set is_teleport because jumps _set_ velocity.y, which can be very
			# jarring and interpreted as damaging otherwise
			# NB: set it only on success paths, otherwise skilled players could
			# buffer a "jump input" to cancel fall damage
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				is_teleport = true
			elif wall_normal:
				var vel = JUMP_VELOCITY * (Vector3.UP + wall_normal + camera.global_basis * -Vector3.BACK * JUMP_LOOK_INFLUENCE).normalized()
				velocity.y = vel.y
				velocity.x += vel.x
				velocity.z += vel.z
				is_teleport = true

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var direction := (transform.basis * Vector3(movement.x, 0, movement.y)).normalized()
		var accel = (CROUCH_ACCEL if is_crouch_sliding() else GROUND_ACCEL) if is_vertically_supported() else AIR_ACCEL
		var speed = MOVE_SPEED_CROUCH if is_crouching() else MOVE_SPEED_FULL
		velocity.x = move_toward(velocity.x, direction.x * speed, accel)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel)
		if ledge_point != null:
			velocity.y = move_toward(velocity.y, -movement.y * speed, accel)

	var prev_velocity = get_real_velocity()
	move_and_slide()
	var delta_v = (get_real_velocity() - prev_velocity)
	var dvl2 = delta_v.length_squared()
	if is_teleport:
		dvl2 = 0.0
		is_teleport = false
	if dvl2 > DAMAGE_MIN_IMP:
		var dmg = remap(clamp(dvl2, DAMAGE_MIN_IMP, DAMAGE_MAX_IMP), DAMAGE_MIN_IMP, DAMAGE_MAX_IMP, DAMAGE_MIN_AMT, DAMAGE_MAX_AMT)
		if dmg > 0:
			print('dmg ', dmg, ' due to dvl2 ', dvl2, ' (', delta_v, ')')
			health -= dmg
	if not dead:
		health += HEAL_RATE * delta
