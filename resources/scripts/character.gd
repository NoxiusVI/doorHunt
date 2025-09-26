extends NetworkRigidBody3D

@export_category("CONTROLLER")
@export_group("MAX SPEED")
@export var maxWalkSpeed : float = 3.0
@export var maxSprintSpeed : float = 5.0
@export var maxCrouchSpeed : float = 1.0
@export_group("MOVEMENT SPEED")
@export var acceleration : float = 40.0
@export var deceleration : float = 40.0
@export_group("VITALS")
@export var maxHealth : float = 100.0


@export_category("INPUT")
@export var input : PlayerInput

@export_category("NODES")
@export var characterRoot : Node3D
@export var cameraOrigin : Node3D
@export var camera : Camera3D
@export var groundCast : ShapeCast3D

# -- NETWORKING VARIABLES --
@onready var rbSync : RollbackSynchronizer = $RollbackSynchronizer
var peerId : int = 0

@export_group("Shaders")
@export var gunShader : ShaderMaterial
@export var handShader : ShaderMaterial

var health : float = maxHealth

func takeDamage(damage : float, isNew : bool) -> void:
	if not is_multiplayer_authority(): return
	print("DEALING DAMAGE (%s), HEALTH BEFORE DAMAGE (%s), ACTION IS NEW = %s" % [damage, health, isNew])
	health -= damage

func _ready() -> void:
	# Wait a frame so peer_id is set
	await get_tree().process_frame

	# Set owner
	set_multiplayer_authority(1)
	
	input.set_multiplayer_authority(peerId)
	
	if input.is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		$Head/Gun/WeaponGrip/Animator/Gun/Mesh.set("material_override",gunShader)
		$Head/Gun/WeaponGrip/Animator/LeftHand/Mesh.set("material_override",handShader)
		$Head/Gun/WeaponGrip/Animator/RightHand/Mesh.set("material_override",handShader)
		print(peerId)
		$Head/Camera.make_current()
	
	rbSync.process_settings()

var time : float = 0
@onready var lPos : Vector3 = $Root/Hips/LFoot.position

func _process(delta: float) -> void:
	if peerId != multiplayer.get_unique_id(): return
	
	$Debug.visible = true
	
	if Input.is_action_just_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var timeMulti : float = 1.5 if Input.is_action_pressed("move_sprint") else 1.0
	var magnMulti : float = 2.0 if Input.is_action_pressed("move_sprint") else 1.0
	
	var targetLOffset : Vector3 = lPos
	var targetROffset : Vector3 = lPos*Vector3(-1,1,1)
	var targetBodyRotation : Vector3 = Vector3.ZERO
	
	var dirVector : Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")
	
	if dirVector.length() > 0:
		time += delta*timeMulti*2
		var sinDir : float = sin(time*PI)
		var directionOffset : Vector3 = Vector3(sinDir*dirVector.x*0.25,0,sinDir*dirVector.y*0.25) * magnMulti
		targetLOffset += (directionOffset + Vector3(0,clamp(cos(time*PI)*0.25,0,0.25),0))
		targetROffset += (-directionOffset + Vector3(0,clamp(cos((time+1)*PI)*0.25,0,0.25),0))
		targetBodyRotation = Vector3(deg_to_rad(5)*magnMulti * dirVector.y,0,deg_to_rad(5)*magnMulti * -dirVector.x)
	else:
		time = 0.0
	
	$Root/Hips/LFoot.position = $Root/Hips/LFoot.position.lerp(targetLOffset,1 - pow(0.01,delta))
	$Root/Hips/RFoot.position = $Root/Hips/RFoot.position.lerp(targetROffset,1 - pow(0.01,delta))
	$Root/Meshes.rotation = $Root/Meshes.rotation.lerp(targetBodyRotation,1 - pow(0.01,delta))
	
	$Debug/PositionLabel.text = "POSITION : " + str(position)
	$Debug/RotationLabel.text = "ROTATION : " + str(characterRoot.rotation.y)
	$Debug/SpeedLabel.text = "SPEED : " + str(linear_velocity.length())

func _physics_rollback_tick(delta : float, _tick : int) -> void:
	if health <= 0: lock_rotation=false; physics_material_override.friction = 1; return
	groundCast.force_shapecast_update()
	var isGrounded : bool = groundCast.is_colliding() and linear_velocity.y <= 0.1
	
	characterRoot.global_rotation = input.lookDirection*Vector3(0,1,0)
	cameraOrigin.global_rotation = input.lookDirection
		
	if input.jumping and isGrounded:
		self.apply_central_impulse(Vector3(0,5,0)*mass)
	
	if input.moveDirection.length() > 0:
		var maxSpeed : float = maxSprintSpeed if input.sprinting else (maxCrouchSpeed if input.crouching else maxWalkSpeed)
		
		var wishSpeed : Vector3 = characterRoot.global_basis *  input.moveDirection*maxSpeed
		var currentSpeed : Vector3 = Plane(Vector3.UP).project(linear_velocity)
		var differntSpeed : Vector3 = wishSpeed - currentSpeed
		var additive : Vector3 = differntSpeed.normalized()*clampf(differntSpeed.length(),0,acceleration*delta)
		self.apply_central_impulse(additive*mass)
	elif isGrounded:
		var currentSpeed : Vector3 = Plane(Vector3.UP).project(linear_velocity)
		var additive : Vector3 = -currentSpeed.normalized()*deceleration*delta
		self.apply_central_impulse(additive.normalized() * clamp(additive.length(),0,currentSpeed.length()))
