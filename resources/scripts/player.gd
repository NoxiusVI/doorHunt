extends RigidBody3D

@export_category("Values")
@export_group("Controller")
## How fast you can move while walking
@export var maxWalkSpeed : float = 4.0
## How fast you can move while running
@export var maxRunSpeed : float = 12.0
## How strong is the jump
@export var jumpPower : float = 6.0
## How strong of a force to add towards the inputted direction when jumping
@export var bHopForce : float = 3.0
@export_subgroup("Ground")
## How fast the character accelerates on the ground
@export var groundAcceleration : float = 40.0
## How fast the character decelerates on the ground
@export var groundDeceleration : float = 40.0
@export_subgroup("Air")
## How fast the character accelerates in air
@export var airAcceleration : float = 4.0
## How fast the character decelerates in air
@export var airDeceleration : float = 1.0
@export_group("Floor")
## How large a slope can be, before it's considered unwalkable
@export_range(0.0,90.0) var maxSlope : float = 60.0

@export_category("Nodes")
@export_group("Camera")
@export var camera : Camera3D
@export var cameraOrigin : Node3D
@export_group("Ground")
@export var groundCast : ShapeCast3D

# ------- || CHARACTER STATES || -------
var isGrounded : bool = false # The character is only ground when at least one foot is on the ground.

# ------- || CHARACTER TIMERS || -------
var timeJumped : float = 0.0 # How much time left before you can jump again.

# ------- || CAMERA VARIABLES || -------
var pitch : float = 0.0 #Camera pitch
var yaw : float = 0.0 #Camera yaw
# ------- || INPUT VARIABLES || -------
var inputDirection : Vector2 = Vector2.ZERO

var groundNormal : Vector3 = Vector3.UP
var groundPlane : Plane = Plane.PLANE_XZ
var groundBasis : Basis = Basis.IDENTITY

# ------- || MAIN FUNCTIONS || -------

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	rotation = Vector3(0,yaw,0)

func _process(dt: float) -> void:
	if Input.is_action_just_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cameraOrigin.rotation = Vector3(pitch,0,0)

func _physics_process(dt: float) -> void:
	updateGrounded()
	updateMovement(dt)
	
	$SpeedLabel.text = "SPEED : " + str(roundf(linear_velocity.length()*10.0)/10.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw = wrapf(yaw - event.relative.x/1000,-PI,PI)
		pitch = clamp(pitch - event.relative.y/1000,-PI/2,PI/2)

# ------- || MOVEMENT FUNCTIONS || -------

func updateMovement(dt : float) -> void:
	timeJumped += dt
	
	inputDirection = Input.get_vector("move_left","move_right","move_up","move_down")

	
	var acceleration : float = groundAcceleration if isGrounded else airAcceleration
	var deceleration : float = groundDeceleration if isGrounded else airDeceleration
	
	if inputDirection.length() > 0:
		var maxSpeed : float = maxWalkSpeed
	
		var wishSpeed : Vector3 = groundBasis * Vector3(inputDirection.x,0,inputDirection.y)*maxSpeed
		var currentSpeed : Vector3 = groundPlane.project(linear_velocity)
		var differntSpeed : Vector3 = wishSpeed - currentSpeed
		var additive : Vector3 = differntSpeed.normalized()*clampf(differntSpeed.length(),0,acceleration*dt)
		apply_central_impulse(additive*mass)
	else:
		if isGrounded:
			var additive : Vector3 = linear_velocity.move_toward(Vector3.ZERO,deceleration*dt) - linear_velocity
			apply_central_impulse(additive*mass)
	
	if Input.is_action_pressed("move_jump") and timeJumped > 0.5:
		if isGrounded:
			timeJumped = 0
			var additive : Vector3 = Vector3(0,jumpPower,0) #- Vector3(0,originBone.linear_velocity.y,0)
			apply_central_impulse(additive*mass)


#Simple enough, updates the isGrounded state + some ground related variables
func updateGrounded() -> void:
	#Updates ground detection for isGrounded
	groundCast.global_rotation = Vector3.ZERO
	groundCast.force_shapecast_update()
	
	gravity_scale = 0
	
	var onGround : bool = false
	
	if groundCast.is_colliding():
		var averageNormal : Vector3 = Vector3.ZERO
		
		for collisionId in groundCast.get_collision_count():
			averageNormal += groundCast.get_collision_normal(collisionId)
			
		averageNormal /= groundCast.get_collision_count()
		
		if averageNormal.length() == 0:
			averageNormal = Vector3.UP
		else:
			averageNormal = averageNormal.normalized()
			
		if acos(averageNormal.dot(Vector3.UP)) <= deg_to_rad(maxSlope):
			onGround = true
			groundNormal = averageNormal
	
	if not onGround:
		gravity_scale = 1
		groundNormal = Vector3.UP
	
	var globalForward = Vector3.BACK.rotated(Vector3.UP, yaw)
	var newForward = globalForward.slide(groundNormal).normalized()
	if newForward.length_squared() < 0.0001:
		newForward = globalForward.cross(groundNormal).cross(groundNormal).normalized()
	var newRight = groundNormal.cross(newForward).normalized()
	
	groundPlane.normal = groundNormal
	groundBasis = Basis(newRight, groundNormal, newForward).orthonormalized()
	
	isGrounded = onGround

# ------- || MISC FUNCTIONS || -------
