extends Node3D

@export var fire_cooldown: float = 0.25
@export var damage: int = 35

@onready var input : PlayerInput= $"../../Input"
@onready var sound : AudioStreamPlayer3D = $"WeaponAudio/Fire"
@onready var fire_action :RewindableAction = $"FireAction"
@export var rollback_synchronizer : RollbackSynchronizer

var last_fire: int = -1

func _ready() -> void:
	fire_action.mutate(self)		# Mutate self, so firing code can run
	fire_action.mutate($"../../")	# Mutate player
	# Set owner
	
	set_multiplayer_authority(1)
	
	NetworkTime.after_tick_loop.connect(_after_loop)

func _rollback_tick(_dt : float, _tick: int, _if : bool) -> void:
	if rollback_synchronizer.is_predicting():
		return

	fire_action.set_active(input.fire and _can_fire())
	match fire_action.get_status():
		RewindableAction.CONFIRMING, RewindableAction.ACTIVE:
			# Fire if action has just activated or is active
			_fire()
		RewindableAction.CANCELLING:
			# Whoops, turns out we couldn't have fired, undo
			_unfire()

func _after_loop() -> void:
	if fire_action.has_confirmed():
		sound.play()
		$WeaponGrip/MuzzleParticles.emitting = true

func _can_fire() -> bool:
	return NetworkTime.seconds_between(last_fire, NetworkRollback.tick) >= fire_cooldown

func _fire() -> void:
	last_fire = NetworkRollback.tick

	# See what we've hit
	var hit : Dictionary = _raycast()
	if hit.is_empty():
		# No hit, nothing to do
		return

	_on_hit(hit)

func _unfire() -> void:
	fire_action.erase_context()

func _raycast() -> Dictionary:
	# Detect hit
	var space : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin_xform : Transform3D = global_transform
	var query : PhysicsRayQueryParameters3D= PhysicsRayQueryParameters3D.create(
		origin_xform.origin,
		origin_xform.origin - origin_xform.basis.z * 1024.
	)

	return space.intersect_ray(query)

func _on_hit(result: Dictionary) -> void:
	var is_new_hit : bool = false
	if not fire_action.has_context():
		fire_action.set_context(true)
		is_new_hit = true
	
	if result.collider.has_method("takeDamage"):
		result.collider.takeDamage(damage, is_new_hit)
		NetworkRollback.mutate(result.collider)
