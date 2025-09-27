extends BaseNetInput
class_name PlayerInput

# -- WEAPON INPUT --
var fire : bool = false
var reload : bool = false

# -- CHARACTER CONTROLLER INPUT --
var moveDirection : Vector3 = Vector3.ZERO
var lookDirection : Vector3 = Vector3.ZERO
var sprinting : bool = false
var jumping : bool = false
var crouching : bool = false

var yaw : float = 0
var pitch : float = 0

var confidence: float = 1.0
@export var rbSync : RollbackSynchronizer

func _ready() -> void:
	super()

func _gather() -> void:
	fire = Input.is_action_pressed("weapon_fire")
	reload = Input.is_action_pressed("weapon_reload")
	
	var moveVector : Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")
	moveDirection = Vector3(moveVector.x,0,moveVector.y)
	lookDirection = Vector3(pitch,yaw,0)
	
	if Input.is_action_just_pressed("move_crouch"):
		crouching = true
		sprinting = false
	elif Input.is_action_just_pressed("move_sprint"):
		crouching = false
		sprinting = true
	
	# If a button is released, check what states are still being held down
	if not Input.is_action_pressed("move_crouch") and not Input.is_action_pressed("move_sprint"):
		# If neither button is held, default to walking
		crouching = false
		sprinting = false
	elif not Input.is_action_pressed("move_crouch") and Input.is_action_pressed("move_sprint"):
		# If crouch is held, but the other key isn't, go to crouch state
		crouching = false
		sprinting = true
	elif Input.is_action_pressed("move_crouch") and not Input.is_action_pressed("move_sprint"):
		# If sprint is held, but the other key isn't, go to sprint state
		crouching = true
		sprinting = false
	
	jumping = Input.is_action_pressed("move_jump")

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		yaw = wrapf(yaw - event.relative.x/1000,-PI,PI)
		pitch = clamp(pitch - event.relative.y/1000,-PI/2,PI/2)
