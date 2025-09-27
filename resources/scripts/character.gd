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

@export_category("ANIMATION")
@export var stepLength : float = 0.75

@export_category("INPUT")
@export var input : PlayerInput

@export_category("NODES")
@export var groundCast : ShapeCast3D
@export var characterRoot : Node3D
@export var cameraOrigin : Node3D
@export var camera : Camera3D

# -- NETWORKING VARIABLES --
@onready var rbSync : RollbackSynchronizer = $RollbackSynchronizer
@onready var tickInterp : TickInterpolator = $TickInterpolator
var peerId : int = 0

@export_group("Shaders")
@export var gunShader : ShaderMaterial
@export var handShader : ShaderMaterial

@onready var health : float = maxHealth

# Gameplay stuff
var wasHit : bool = true
var deathTick : int = -1
var hasRespawned : bool = false
var deaths : int = 0
var trueDeaths : int = 0


func takeDamage(damage : float, isNew : bool) -> void:
	if isNew:
		wasHit = true
	#print("DEALING DAMAGE (%s), HEALTH BEFORE DAMAGE (%s), ACTION IS NEW = %s" % [damage, health, isNew])
	health -= damage
	if health <= 0:
		deathTick = NetworkRollback.tick
		apply_impulse(Vector3(1,1,1))

func _ready() -> void:
	# Wait a frame so peer_id is set
	await get_tree().process_frame

	# Set owner
	set_multiplayer_authority(1)
	
	input.set_multiplayer_authority(peerId)
	
	if input.is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		cameraOrigin.get_node("Gun/WeaponGrip/Animator/Gun/Mesh").set("material_override",gunShader)
		cameraOrigin.get_node("Gun/WeaponGrip/Animator/LeftHand/Mesh").set("material_override",handShader)
		cameraOrigin.get_node("Gun/WeaponGrip/Animator/RightHand/Mesh").set("material_override",handShader)
		print(peerId)
		camera.make_current()
	
	rbSync.process_settings()
	NetworkTime.before_tick_loop.connect(beforeTickLoop)
	NetworkTime.after_tick_loop.connect(afterTickLoop)

var time : float = 0
@onready var lPos : Vector3 = $Root/Hips/LFoot.position

func updateHealthBar() -> void:
	$Nameplate/NameViewport/HealthBar.value = health
	$Nameplate/NameViewport/HealthBar.max_value = maxHealth

func _process(delta: float) -> void:
	if peerId == multiplayer.get_unique_id(): 
		$Debug.visible = true
		$Debug/PositionLabel.text = "POSITION : " + str(position)
		$Debug/RotationLabel.text = "ROTATION : " + str(characterRoot.rotation.y)
		$Debug/SpeedLabel.text = "SPEED : " + str(linear_velocity.length())
		if Input.is_action_just_pressed("pause"):
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var timeMulti : float = 1.5 if input.sprinting else 1.0
	var magnMulti : float = 2.0 if input.sprinting else 1.0
	
	var targetLOffset : Vector3 = lPos
	var targetROffset : Vector3 = lPos*Vector3(-1,1,1)
	
	var dirVector : Vector2 = Vector2(input.moveDirection.x,input.moveDirection.z)
	
	if dirVector.length() > 0:
		var maxSpeed : float = maxSprintSpeed if input.sprinting else (maxCrouchSpeed if input.crouching else maxWalkSpeed)
			
		time += delta*timeMulti*2
		var trueStepLength : float = stepLength * magnMulti
		var sinDirL : float = sin((time*maxSpeed*PI)/(trueStepLength*2))
		var sinDirR : float = sin(((time+0.5)*maxSpeed*PI)/(trueStepLength*2))
		var directionOffsetL : Vector3 = Vector3(sinDirL*dirVector.x,0,sinDirL*dirVector.y)*trueStepLength
		var directionOffsetR : Vector3 = Vector3(sinDirR*dirVector.x,0,sinDirR*dirVector.y)*trueStepLength
		targetLOffset += (directionOffsetL + Vector3(0,clamp(cos((time*maxSpeed*PI)/(trueStepLength*2))*0.25,0,0.25),0))
		targetROffset += (directionOffsetR + Vector3(0,clamp(cos(((time+0.5)*maxSpeed*PI)/(trueStepLength*2))*0.25,0,0.25),0))
	else:
		time = 0.0
	
	$Root/Hips/LFoot.position = $Root/Hips/LFoot.position.lerp(targetLOffset,1 - pow(0.01,delta))
	$Root/Hips/RFoot.position = $Root/Hips/RFoot.position.lerp(targetROffset,1 - pow(0.01,delta))
func beforeTickLoop() -> void:
	trueDeaths = deaths

func afterTickLoop() -> void:
	if trueDeaths != deaths:
		tickInterp.teleport()
		trueDeaths = deaths

	if wasHit:
		$HitSound.play()
		updateHealthBar()
		wasHit = false

func _physics_rollback_tick(delta : float, tick : int) -> void:

	if tick == deathTick:
		direct_state.transform = Transform3D(Basis.IDENTITY,Vector3.ZERO)
		hasRespawned = true
	else:
		hasRespawned = false
	
	if health > 0:
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
	else:
		deaths += 1
		direct_state.transform = Transform3D(Basis.IDENTITY,Vector3.ZERO)
		health = 100
		updateHealthBar()
