@icon("res://addons/plenticons/icons/16x/objects/gun-red.png")
extends Node3D
class_name GunBase3D

@export_group("STATS")
@export var damage : float = 75.0
@export var firerate : float = 0.75
@export var reloadTime : float = 0.75
@export var magSize : int = 1

@export_group("HUD")
@export var hudControl : Control
@export var reloadProgress : TextureProgressBar
@export var magLabel : Label

@onready var soundHolder : Node3D = $Sounds
@onready var muzzleFlash : GPUParticles3D = $"WeaponGrip/Animator/Gun/MuzzleParticles"
@onready var fireAction : RewindableAction = $"FireAction"
@onready var reloadAction : RewindableAction = $"ReloadAction"

@export_group("OUTSIDE NODES")
@export var player : NetworkRigidBody3D
@export var input : PlayerInput 
@export var rbSync : RollbackSynchronizer

var lastFired : int = -1
var lastReloaded : int = -1

@onready var curMag : int = magSize
var reloaded : bool = false

var linear : Vector3 = Vector3.ZERO
var torque : Vector3 = Vector3.ZERO

var linStiff : float = 500
var linDamp : float = 20
var torStiff : float = 500
var torDamp : float = 20

@onready var animator : Node3D = $"WeaponGrip/Animator"
@onready var grip : Node3D = $WeaponGrip
@onready var restTransform : Transform3D = animator.transform
@onready var lastParentRot : Basis = grip.basis

# -- BASE FUNCTIONS --

func _ready() -> void:
	await get_tree().process_frame
	
	fireAction.mutate(self)		# Mutate self, so firing code can run
	fireAction.mutate(player)	# Mutate player
	reloadAction.mutate(self)		# Mutate self, so reloading code can run
	reloadAction.mutate(player)	# Mutate player
	
	if player.peerId == multiplayer.get_unique_id(): hudControl.visible = true
	
	set_multiplayer_authority(1)
	fireAction.set_multiplayer_authority(1)
	reloadAction.set_multiplayer_authority(1)
	NetworkTime.after_tick_loop.connect(afterLoop)

func _process(delta: float) -> void:
	if player.peerId == multiplayer.get_unique_id():
		reloadProgress.value = (NetworkTime.seconds_between(lastReloaded, NetworkRollback.tick)/reloadTime)
		reloadProgress.visible = reloadProgress.value < 1.0
		magLabel.text = str(curMag) + "/" + str(magSize)
	
	var curParentRot : Basis = grip.global_basis * player.get_node("Root").global_basis
	torque += (lastParentRot * curParentRot.inverse()).get_euler(EULER_ORDER_YXZ) * player.get_node("Root").global_basis * 5
	lastParentRot = curParentRot
	
	linear += spring(restTransform.origin - animator.position, linear, linStiff, linDamp)*delta
	torque += spring((restTransform.basis * animator.basis.inverse()).get_euler(EULER_ORDER_XYZ), torque, torStiff, torDamp)*delta
	
	animator.position += linear*delta
	animator.rotation += torque*delta

func spring(displacement : Vector3, velocity : Vector3,stiffness : float, damping : float) -> Vector3:
	return (stiffness * displacement) - (damping * velocity)

# -- LOOP FUNCTIONS --

func _rollback_tick(_dt : float, _tick: int, _if : bool) -> void:
	if rbSync.is_predicting(): return
	
	if reloaded and NetworkTime.seconds_between(lastReloaded, NetworkRollback.tick) >= reloadTime:
		reloaded = false
		curMag = magSize
	
	reloadAction.set_active(input.reload and mayReload())
	match reloadAction.get_status():
		RewindableAction.CONFIRMING, RewindableAction.ACTIVE:
			# reload if action has just activated or is active
			reload()
		RewindableAction.CANCELLING:
			# Whoops, turns out we couldn't have reloaded, undo
			unreload()
	
	fireAction.set_active(input.fire and mayFire())
	match fireAction.get_status():
		RewindableAction.CONFIRMING, RewindableAction.ACTIVE:
			# Fire if action has just activated or is active
			fire()
		RewindableAction.CANCELLING:
			# Whoops, turns out we couldn't have fired, undo
			unfire()

func afterLoop() -> void:
	if fireAction.has_confirmed():
		fireEffects()
	if reloadAction.has_confirmed():
		reloadEffects()

# -- MAY FUNCTIONS --

func mayAct() -> bool:
	return (NetworkTime.seconds_between(lastFired, NetworkRollback.tick) >= firerate) and (NetworkTime.seconds_between(lastReloaded, NetworkRollback.tick) >= reloadTime)

func mayFire() -> bool:
	return mayAct() and curMag > 0
	
func mayReload() -> bool:
	return mayAct() and (curMag < magSize)

# -- DO FUNCTIONS --

func fire() -> void:
	lastFired = NetworkRollback.tick
	curMag -= 1

	# See what we've hit
	var hit : Dictionary = fireRay()
	if hit.is_empty():
		return

	onHit(hit)

func unfire() -> void:
	curMag += 1
	print("Whoops! Unfired!")
	fireAction.erase_context()

func reload() -> void:
	lastReloaded = NetworkRollback.tick
	reloaded = true
	if not reloadAction.has_context():
		reloadAction.set_context([curMag,reloaded])

func unreload() -> void:
	reloaded = false
	print("Whoops! Unreloaded!")
	reloadAction.erase_context()

# -- SHOOTING FUNCTIONS --

func fireRay() -> Dictionary:
	# Detect hit
	var space : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin_xform : Transform3D = global_transform
	var query : PhysicsRayQueryParameters3D= PhysicsRayQueryParameters3D.create(
		origin_xform.origin,
		origin_xform.origin - origin_xform.basis.z * 1024.
	)

	return space.intersect_ray(query)

func onHit(result : Dictionary) -> void:
	var isNew : bool = false
	if not fireAction.has_context():
		fireAction.set_context(true)
		isNew = true
	
	if result.collider.has_method("takeDamage"):
		result.collider.takeDamage(damage, isNew)
		NetworkRollback.mutate(result.collider)

# -- MISC FUNCTIONS --
func fireEffects() -> void:
	playSound("Fire")
	muzzleFlash.emitting = true
	linear += Vector3(randf(),randf()*-1,1)*4
	torque += Vector3(4,randf()*2 - 1,(randf()*2 - 1))*PI*4
	
func reloadEffects() -> void:
	playSound("Reload")
	animator.rotation = Vector3.ZERO
	torque = Vector3(-30,0,0)*PI
	linear += Vector3(0,-15,0)

func playSound(soundName : String) -> void:
	var sound : AudioStreamPlayer3D = soundHolder.get_node_or_null(soundName)
	if sound:
		sound.play()
