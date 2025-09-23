class_name StatePayload

var tick : int = 0
var position : Vector3 = Vector3.ZERO
var rotation : Vector3 = Vector3.ZERO
var linear_velocity : Vector3 = Vector3.ZERO
var angular_velocity : Vector3 = Vector3.ZERO

func serialize() -> Dictionary:
	return {
	"tick" = tick,
	"position" = position,
	"rotation" = rotation,
	"linear_velocity" = linear_velocity,
	"angular_velocity" = angular_velocity,
	}

func deserialize(input : Dictionary) -> StatePayload:
	tick = input.tick
	position = input.position
	rotation = input.rotation
	angular_velocity = input.angular_velocity
	return self
