class_name InputPayload

var tick : int = 0
var inputDirection : Vector2 = Vector2.ZERO
var jumping : bool = false

func serialize() -> Dictionary:
	return {
	"tick" = tick,
	"inputDirection" = inputDirection,
	"jumping" = jumping,
	}

func deserialize(input : Dictionary) -> InputPayload:
	tick = input.tick
	inputDirection = input.inputDirection
	jumping = input.jumping
	return self
